# Reminder notes metadata format

Agent-created reminders store machine-readable context at the **end of the reminder's notes** field,
after the human-readable text. This lets compatible clients recover which workspace a reminder
belongs to and any command to re-run.

## Format

```
<free-text note for the human>

[agent-meta]
key=value
key=value
```

- A blank line separates the human text from the metadata block.
- New reminders use a literal `[agent-meta]` line.
- Readers must also accept the legacy `[claude-meta]` marker with identical semantics.
- Each following line is a single `key=value` pair. The value is the rest of the line; it may
  contain spaces and is **not** quoted.
- Keys are lowercase. Unknown keys are allowed and should be preserved on read-back.

## Conventional keys

| key         | meaning                                                                 |
|-------------|-------------------------------------------------------------------------|
| `workspace` | absolute path of the working directory when the reminder was created    |
| `repo`      | git remote URL (`git remote get-url origin`), if in a repo              |
| `repo-id`   | normalized lowercase host/path identity without a `.git` suffix         |
| `branch`    | git branch at creation time; context only, never a filtering criterion  |
| `command`   | the exact command/script to re-run when the reminder fires, if any      |
| `session`   | client session identifier, when one is available                        |
| `created`   | ISO-8601 timestamp of creation                                          |

All keys are optional — include only what is known.

## Example

```
Re-run the nightly data sync and verify the row counts.

[agent-meta]
workspace=/Users/leppich/repos/acme/api
repo=git@github.com:acme/api.git
repo-id=github.com/acme/api
branch=main
command=./scripts/sync.sh --full
created=2026-06-02T14:30:00Z
```

## Project matching

Project-scoped reads match the exact physical `workspace`, raw `repo`, **or** normalized `repo-id`.
Pass the available values as repeatable `--metadata` criteria so the CLI performs the OR match:

```bash
reminders show "Claude" --metadata "workspace=/Users/me/repos/acme/api" \
  --metadata "repo=git@github.com:acme/api.git" \
  --metadata "repo-id=github.com/acme/api" --format json
```

Normalize SSH/HTTPS origins to lowercase host plus repository path, removing any user, scheme,
trailing slash, and `.git` suffix. This lets the same repository match after switching between
SSH and HTTPS. Legacy reminders without `repo-id` continue to match their raw `repo`. Do not use
`branch` to filter reminders.
