import ArgumentParser
import Foundation

public struct MetadataCriterion: Equatable, ExpressibleByArgument {
    public let key: String
    public let value: String

    public init?(argument: String) {
        guard let separator = argument.firstIndex(of: "=") else {
            return nil
        }

        let key = argument[..<separator].trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else {
            return nil
        }

        self.key = key.lowercased()
        self.value = String(argument[argument.index(after: separator)...])
    }
}

public struct ReminderMetadata: Equatable {
    private static let markers = ["[agent-meta]", "[claude-meta]"]

    public let values: [String: String]

    public init(notes: String?) {
        guard let notes else {
            self.values = [:]
            return
        }

        let lines = notes.components(separatedBy: .newlines)
        guard let markerIndex = lines.lastIndex(where: {
            Self.markers.contains($0.trimmingCharacters(in: .whitespaces))
        }) else {
            self.values = [:]
            return
        }

        var values: [String: String] = [:]
        for line in lines.suffix(from: lines.index(after: markerIndex)) {
            guard let separator = line.firstIndex(of: "=") else {
                continue
            }

            let key = line[..<separator].trimmingCharacters(in: .whitespaces).lowercased()
            guard !key.isEmpty else {
                continue
            }

            values[key] = String(line[line.index(after: separator)...])
        }
        self.values = values
    }

    public func matches(any criteria: [MetadataCriterion]) -> Bool {
        return criteria.isEmpty || criteria.contains { values[$0.key] == $0.value }
    }
}
