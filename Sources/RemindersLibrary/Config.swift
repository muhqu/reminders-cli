import Foundation
import Yams

#if canImport(Darwin)
import Darwin
#endif

/// User access-control configuration, loaded from `~/.config/reminders-cli.yml`.
///
/// By default the CLI can access no reminder lists. Lists are granted by exact
/// name or glob pattern in `allowed_lists`, or globally via `full_access`.
public struct Config: Codable {
    public var fullAccess: Bool
    public var allowedLists: [String]

    enum CodingKeys: String, CodingKey {
        case fullAccess = "full_access"
        case allowedLists = "allowed_lists"
    }

    public init(fullAccess: Bool = false, allowedLists: [String] = []) {
        self.fullAccess = fullAccess
        self.allowedLists = allowedLists
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.fullAccess = try container.decodeIfPresent(Bool.self, forKey: .fullAccess) ?? false
        self.allowedLists = try container.decodeIfPresent([String].self, forKey: .allowedLists) ?? []
    }

    /// Parse a YAML document. An empty or comment-only document yields defaults.
    /// Kept separate from disk IO so it can be unit tested.
    public static func parse(_ yaml: String) throws -> Config {
        if try Yams.load(yaml: yaml) == nil {
            return Config()
        }
        return try YAMLDecoder().decode(Config.self, from: yaml)
    }
}

/// Decides whether the CLI may touch a given list, based on the loaded config.
public struct AccessPolicy {
    public let fullAccess: Bool
    public let patterns: [String]

    public init(_ config: Config) {
        self.fullAccess = config.fullAccess
        self.patterns = config.allowedLists
    }

    public func allows(_ title: String) -> Bool {
        if fullAccess { return true }
        return patterns.contains { AccessPolicy.glob($0, matches: title) }
    }

    /// Case-insensitive shell-style glob match (`*`, `?`, `[...]`) via fnmatch(3).
    static func glob(_ pattern: String, matches string: String) -> Bool {
        return pattern.withCString { p in
            string.withCString { s in
                fnmatch(p, s, Int32(FNM_CASEFOLD)) == 0
            }
        }
    }
}

public enum ConfigState {
    case loaded(Config)
    case missing(URL)
    case invalid(URL, Error)
}

/// Resolve the config file path: `REMINDERS_CLI_CONFIG` (full path) wins, else
/// `${XDG_CONFIG_HOME:-~/.config}/reminders-cli.yml`.
func configURL() -> URL {
    let env = ProcessInfo.processInfo.environment
    if let override = env["REMINDERS_CLI_CONFIG"], !override.isEmpty {
        return URL(fileURLWithPath: (override as NSString).expandingTildeInPath)
    }
    let configHome: URL
    if let xdg = env["XDG_CONFIG_HOME"], !xdg.isEmpty {
        configHome = URL(fileURLWithPath: xdg, isDirectory: true)
    } else {
        configHome = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
    }
    return configHome.appendingPathComponent("reminders-cli.yml", isDirectory: false)
}

func loadConfigState() -> ConfigState {
    let url = configURL()
    if !FileManager.default.fileExists(atPath: url.path) {
        return .missing(url)
    }
    do {
        let text = try String(contentsOf: url, encoding: .utf8)
        return .loaded(try Config.parse(text))
    } catch {
        return .invalid(url, error)
    }
}

private func yamlQuoted(_ s: String) -> String {
    let escaped = s
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
    return "\"\(escaped)\""
}

/// Starter config written by `init-config`, with the user's lists as commented examples.
func configTemplate(listNames: [String]) -> String {
    var lines = [
        "# reminders-cli access configuration",
        "#",
        "# By default this CLI can access NO reminder lists. Grant access by listing exact",
        "# names or glob patterns (e.g. \"Work\", \"Personal*\"); matching is case-insensitive.",
        "# Note: macOS reminders access is all-or-nothing at the OS level, so this allowlist",
        "# only limits what THIS tool will read or write.",
        "",
        "# Set to true to allow access to every list (disables the allowlist below).",
        "full_access: false",
        "",
        "# Lists this CLI may read and write. Uncomment the ones you want to allow:",
        "allowed_lists:",
    ]
    let examples = listNames.isEmpty ? ["Work", "Personal*"] : listNames
    for name in examples {
        lines.append("#  - \(yamlQuoted(name))")
    }
    return lines.joined(separator: "\n") + "\n"
}

/// Help shown when no config exists yet. Deliberately does not enumerate the user's
/// lists — list names should not be revealed until a config grants access.
func missingConfigMessage(path: URL) -> String {
    return """
    error: no access-control config found at \(path.path)

    By default reminders-cli can access NO reminder lists.
    Create a starter config you can edit:

      reminders init-config

    Or write \(path.path) yourself, for example:

        full_access: false
        allowed_lists:
          - "Work"
          - "Personal*"

    Note: macOS reminders access is all-or-nothing; this allowlist only limits
    what reminders-cli itself will read or write.
    """
}
