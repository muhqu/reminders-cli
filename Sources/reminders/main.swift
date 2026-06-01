import Darwin
import RemindersLibrary

// Informational invocations (`--version`, `--help`/`-h`,
// `--generate-completion-script`) are handled by ArgumentParser before any
// subcommand runs, so they need no Reminders access. Skipping the up-front TCC
// request for them lets `reminders --version`/`--help` work without granted
// access, and lets `make package` generate the completion script in CI.
let informationalFlags: Set<String> = ["--version", "--help", "-h", "--generate-completion-script"]
let isInformational = CommandLine.arguments.dropFirst().contains { informationalFlags.contains($0) }

if isInformational {
    CLI.main()
} else {
    switch Reminders.requestAccess() {
    case (true, _):
        CLI.main()
    case (false, let error):
        print("error: you need to grant reminders access")
        if let error {
            print("error: \(error.localizedDescription)")
        }
        exit(1)
    }
}
