# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A macOS command-line tool for reading and mutating Apple Reminders, built on EventKit. Single Swift Package, one executable (`reminders`).

## Commands

- **Build (debug):** `swift build` — **Release:** `make build` (alias for `swift build -c release`)
- **Run during dev:** `swift run reminders <args>` or `.build/release/reminders <args>`
- **Test:** `swift test`
- **Single test:** `swift test --filter NaturalLanguageTests/testTomorrow` (class/method) or `--filter testTomorrow`
- **Install / uninstall:** `make install` / `make uninstall` (installs to `$PREFIX/bin`, `PREFIX` defaults to `~/.local`)
- **Release artifact:** `make package` (builds tarball + zsh completion script, prints sha256)

**CI builds and tests with `-Xswiftc -warnings-as-errors`** (`.github/workflows/swift.yml`, Xcode 16.2 / macOS 14). Any compiler warning fails CI, so keep the build warning-clean.

## Platform & runtime requirements

- **macOS 14+** (`Package.swift`). Uses `requestFullAccessToReminders` (the macOS 14 EventKit API); there are no fallbacks for older OSes.
- The binary requires the user to have granted **Reminders access** (TCC). `main.swift` requests access up front and exits before any command runs if denied. The test suite only exercises `NaturalLanguage` (no EventKit), so tests pass without Reminders permission — but anything touching `Reminders.swift` will hang or fail in a sandbox without it.

## Architecture

Three layers, sharing the `RemindersLibrary` module:

1. **`Sources/reminders/main.swift`** — tiny entry point. Gates on `Reminders.requestAccess()`, then hands off to `CLI.main()`.
2. **`Sources/RemindersLibrary/CLI.swift`** — one `ParsableCommand` struct per subcommand (`Add`, `Show`, `Edit`, `Delete`, `DeleteList`, `RenameList`, `Complete`, etc.) using swift-argument-parser. Each `run()` calls the shared `reminders` singleton to get **data**, then handles **output formatting** (plain vs `--format json`). Subcommands are registered in the `CLI.configuration.subcommands` array.
3. **`Sources/RemindersLibrary/Reminders.swift`** — the EventKit wrapper. All `get*` and mutation methods live here and return model objects (`EKReminder` / `EKCalendar` / tuples), never printing list/JSON output themselves.

**The retrieval-vs-formatting split is a deliberate convention.** When adding or changing a command: the library method returns data; the CLI struct decides how to print it. Do not move `print`/JSON logic into `Reminders.swift`.

### Patterns you must follow

- **EventKit callback → sync bridging:** EventKit APIs (`fetchReminders`, `requestFullAccessToReminders`, etc.) are async/callback-based. Every method bridges to synchronous using a `DispatchSemaphore` (signal in the completion handler, `wait()` after). New methods that query the store must use this same pattern.
- **Index *or* ID resolution:** `getReminder(from:at:)` treats the `index` argument as a positional list index if it parses as `Int`, otherwise matches it against `calendarItemExternalIdentifier` (the reminder's UUID). Commands that target a reminder accept either form.
- **List lookup:** `calendar(withName:)` matches list titles **case-insensitively** and `exit(1)`s if not found. `getCalendars()` filters to lists where `allowsContentModifications` is true.
- **Error handling:** library methods print an error and `exit(1)` on failure (list not found, save failed, etc.) rather than throwing to the caller. Argument-level validation uses ArgumentParser's `validate()` throwing `ValidationError`.

### Access control (allowlist)

By default the CLI can access **no** lists; users grant access via `~/.config/reminders-cli.yml` (`Config.swift` — parsed with Yams; `REMINDERS_CLI_CONFIG` / `XDG_CONFIG_HOME` aware). Enforcement is centralized: `getCalendars()` filters to allowlisted lists via `requireAccessPolicy()`, so **every** read/write path is gated automatically (they all route through `getCalendars()` / `calendar(withName:)`). The exceptions, which guard themselves explicitly, are `newList()` (uses its own `EKEventStore`, so it can't rely on the `getCalendars()` filter) and `renameList()` (the new name must also be allowed). Discovery that must work *without* a config (`enumerateAllListNames()`, `listAccessReport()` for `show-lists --all`, the `init-config` command) uses `allCalendars()` (unfiltered) and must **not** call `requireAccessPolicy()`. Glob matching (`AccessPolicy.glob`) is `fnmatch` with `FNM_CASEFOLD`. Add allowlist/parsing tests to `AccessPolicyTests`/`ConfigTests` (pure logic, no EventKit).

### Natural-language dates

`DateComponents` conforms to `ExpressibleByArgument` in `NaturalLanguage.swift` (via `NSDataDetector`), so every date option (`--due-date`, `--repeat-end`, absolute `--alarm` specs) accepts strings like `today`, `tomorrow 9am`, `next monday`, `2025-02-16`. It detects time-significance and strips time components when the input has no time — which determines whether a due-date alarm is added. This is the most heavily tested code (`Tests/RemindersTests/NaturalLanguageTests.swift`); changes here need matching tests.

### JSON output

JSON comes from `@retroactive Encodable` conformances on EventKit types in `EKReminder+Encodable.swift` and `EKCalendar+Encodable.swift`, serialized by `encodeToJson` (pretty-printed, sorted keys). **To add or change a field in JSON output, edit these extension files** — the CLI just calls `encodeToJson(data:)`.

## Note

The README's "Building manually" section is stale — it references the old `make build-release` target and `.build/apple/Products/Release/` path. The current Makefile uses `make build` and `.build/release/`.
