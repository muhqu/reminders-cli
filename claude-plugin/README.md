# reminders — Claude Code plugin

Create and manage Apple/iCloud Reminders from Claude Code, backed by the
[`reminders`](https://github.com/muhqu/reminders-cli) CLI. Say *"remind me next Monday to run this
script again"* and Claude files a reminder on a dedicated **`Claude`** list, capturing the workspace
and the command to re-run so it's actionable when it fires.

## Prerequisites

1. **Install the CLI:** `brew install muhqu/tap/reminders-cli`
2. **Grant Reminders access:** run `reminders show-lists --all` once and approve the macOS prompt
   (or enable it under System Settings ▸ Privacy & Security ▸ Reminders).
3. **Run setup:** invoke `/reminders:reminders-setup` — it creates the dedicated `Claude` list on
   iCloud and allowlists it in `~/.config/reminders-cli.yml`. (The CLI can touch **no** list until
   the config grants it.)

## Install

```
/plugin marketplace add muhqu/reminders-cli
/plugin install reminders@reminders-cli
```

For local development from a checkout of the repo:

```
claude --plugin-dir ./claude-plugin
```

## Skills

- **create-reminder** — files a reminder from natural language ("remind me tomorrow 9am to …").
  Invoked automatically when you ask to be reminded, or explicitly via `/reminders:create-reminder`.
- **list-reminders** — shows your reminders, filterable to the current project, and can complete,
  snooze, or re-run them. `/reminders:list-reminders`.
- **reminders-setup** — verifies/repairs the prerequisites above. `/reminders:reminders-setup`.

## How metadata is stored

Each reminder's notes hold a short human line plus a `[claude-meta]` block (workspace, repo, branch,
command, session, created). This is what lets `list-reminders` scope to the current project and
re-run a stored command. See [`reference/metadata-format.md`](reference/metadata-format.md).
