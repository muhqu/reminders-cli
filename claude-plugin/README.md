# reminders agent plugin

Create and manage Apple/iCloud Reminders from Claude Code or GitHub Copilot CLI, backed by the
`reminders` CLI. Say *"remind me next Monday to run this script again"* and the agent files a
reminder on the dedicated **`Claude`** list, capturing the workspace and command to re-run.

https://github.com/muhqu/reminders-cli

## Prerequisites

This plugin is for local macOS sessions. The CLI uses EventKit, so remote/cloud Linux agents
gracefully skip startup lookup and cannot access Apple Reminders.

1. **Install Homebrew:** the plugin automatically installs or upgrades
   `muhqu/tap/reminders-cli` when its skills or startup hook need a newer compatible CLI.
2. **Grant Reminders access:** run `reminders show-lists --all` once and approve the macOS prompt
   (or enable it under System Settings ▸ Privacy & Security ▸ Reminders).
3. **Run the `reminders-setup` skill:** it creates the dedicated `Claude` list on iCloud and
   allowlists it in `~/.config/reminders-cli.yml`. The CLI can touch **no** list until the config
   grants it.

## Install for Claude Code

```
/plugin marketplace add muhqu/reminders-cli
/plugin install reminders@reminders-cli
```

For local development from a checkout of the repo:

```
claude --plugin-dir ./claude-plugin
```

## Install for GitHub Copilot CLI

```
copilot plugin install muhqu/reminders-cli:claude-plugin
```

For local development:

```
copilot --plugin-dir ./claude-plugin
```

## Skills

- **create-reminder** — files a reminder from natural language ("remind me tomorrow 9am to …").
  Agents invoke it automatically when you ask to be reminded.
- **list-reminders** — shows your reminders, filterable to the current project, and can complete,
  snooze, or re-run them.
- **reminders-setup** — verifies or repairs the prerequisites above.

## Session-start reminders

On every new or resumed local session, a hook queries only incomplete reminders in the `Claude`
list that are due today or overdue. It asks the CLI to match the exact current workspace **or** the
raw/normalized repository origin through repeatable `--metadata` criteria; branch metadata is
ignored. Matching items appear as a concise persistent startup message. No matches are silent.
The hook automatically installs or upgrades an incompatible CLI through Homebrew. Missing
Homebrew, config, list access, or macOS Reminders permission produces a concise setup hint.

## How metadata is stored

Each new reminder's notes hold a short human line plus an `[agent-meta]` block (`workspace`, raw
`repo`, normalized `repo-id`, `branch`, `command`, optional `session`, and `created`). Readers also
accept the legacy `[claude-meta]` marker. See
[`reference/metadata-format.md`](reference/metadata-format.md).

## Hook tests

The deterministic test harness uses a mock `reminders` executable and does not touch EventKit:

```
./tests/test-cli-management.sh
./tests/test-session-start.sh
```
