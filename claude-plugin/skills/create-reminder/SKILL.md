---
name: create-reminder
description: >-
  Create an Apple/iCloud Reminder when the user asks to be reminded of something — e.g.
  "remind me next monday to run this script again", "set a reminder to follow up tomorrow at
  9am". Captures the current workspace (directory and git repository) and, when the user refers
  to a command or script to re-run, stores it so the reminder is actionable later.
argument-hint: "[what to be reminded of] [when]"
---

# Create a reminder

File an Apple/iCloud Reminder via the `reminders` CLI on the dedicated **`Claude`** list.

## 1. Work out the title and due date
- **Title** — the action to be reminded of, phrased imperatively (e.g. `Run ./sync.sh and verify output`).
- **Due date** — pass the user's natural-language time **straight through** to `--due-date`. The CLI
  understands `today`, `tomorrow 9am`, `next monday`, `friday 17:00`, `2026-06-09`, etc. Do **not**
  pre-convert it to a fixed date. If the user gave no time at all, ask for one (or omit `--due-date`).

## 2. Gather workspace metadata
Collect what you can, quietly — skip any key you can't determine:
- `workspace` — the physical current working directory (`pwd -P`)
- `repo` — `git remote get-url origin` (only if inside a git repo)
- `repo-id` — a stable form of an SSH/HTTPS origin: lowercase host plus path, with any user,
  scheme, trailing slash, and `.git` suffix removed (e.g. `github.com/acme/api`)
- `branch` — `git rev-parse --abbrev-ref HEAD` (only if inside a git repo)
- `command` — the exact command/script the user wants to re-run, if they referred to one
  (e.g. "run this script **again**" → the script just run or named in the conversation)
- `session` — a session identifier only when the client exposes one reliably; do not require it
- `created` — the current time in ISO-8601

## 3. Build the notes
Notes = one short human line, a blank line, then an `[agent-meta]` block of `key=value` lines (one
per line). The full format is documented in this plugin's `reference/metadata-format.md`. Example:

```
Re-run the data sync and check the output.

[agent-meta]
workspace=/Users/me/repos/acme/api
repo=git@github.com:acme/api.git
repo-id=github.com/acme/api
branch=main
command=./scripts/sync.sh --full
created=2026-06-02T14:30:00Z
```

Always write `[agent-meta]`. When reading an existing reminder, accept both `[agent-meta]` and the
legacy `[claude-meta]` marker.

## 4. Create it
```bash
reminders add "Claude" "<title>" --due-date "<when>" --notes "<notes>" --format json
```
Always use the dedicated `Claude` list. Parse the JSON result and confirm to the user with the
human-readable due time. Keep the returned `externalId` in mind for any immediate follow-up.

## 5. If it fails
If the command errors because the `Claude` list isn't allowed / doesn't exist, or Reminders access
isn't granted, follow the **reminders-setup** skill, then retry. Don't silently give up.
