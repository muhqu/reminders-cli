---
name: list-reminders
description: >-
  Show or read back the user's Apple/iCloud Reminders created via Claude — e.g. "what reminders
  do I have", "show my reminders for this project", "what's due today". Can filter to the current
  workspace/repo and complete, snooze, or re-run them.
argument-hint: "[optional filter, e.g. 'this repo' or 'today']"
allowed-tools:
  - "Bash(reminders:*)"
  - "Bash(git remote:*)"
  - "Bash(pwd)"
---

# List reminders

Read reminders via the `reminders` CLI and present them.

## Fetch
```bash
reminders show "Claude" --format json
```
Use `reminders show-all --format json` if the user wants reminders across all (allowlisted) lists.
Add `--include-completed` only if they ask to see completed ones.

## Parse & filter
Each JSON item has `title`, `dueDate` (ISO-8601), `isCompleted`, `externalId`, and `notes`. The
notes may contain a `[claude-meta]` block (spec: `${CLAUDE_PLUGIN_ROOT}/reference/metadata-format.md`)
with `workspace`, `repo`, `branch`, `command`, etc.

- If the user scopes to **"this project / repo"**, keep only items whose `[claude-meta]`
  `workspace` equals the current directory (`pwd`), or whose `repo` matches
  `git remote get-url origin`.
- If they scope by time ("today", "overdue", "this week"), filter on `dueDate`.

## Present
List each matching reminder with its title, a human-friendly due date, and the useful metadata —
especially `command` when present.

## Act (on request, target by `externalId`)
- **Complete:** `reminders complete "Claude" <externalId>`
- **Snooze / reschedule:** `reminders edit "Claude" <externalId> --due-date "<new when>"`
- **Re-run:** if a reminder carries a `command`, offer to run it — confirm with the user first,
  and prefer running it from the reminder's `workspace` directory.
