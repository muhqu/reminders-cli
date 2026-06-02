# Reminder notes metadata format

Claude-created reminders store machine-readable context at the **end of the reminder's notes**
field, after the human-readable text. This lets `list-reminders` (and you, in a later session)
recover which workspace a reminder belongs to and any command to re-run.

## Format

```
<free-text note for the human>

[claude-meta]
key=value
key=value
```

- A blank line separates the human text from the metadata block.
- The block starts with a literal `[claude-meta]` line.
- Each following line is a single `key=value` pair. The value is the rest of the line; it may
  contain spaces and is **not** quoted.
- Keys are lowercase. Unknown keys are allowed and should be preserved on read-back.

## Conventional keys

| key         | meaning                                                                 |
|-------------|-------------------------------------------------------------------------|
| `workspace` | absolute path of the working directory when the reminder was created    |
| `repo`      | git remote URL (`git remote get-url origin`), if in a repo              |
| `branch`    | git branch at creation time                                             |
| `command`   | the exact command/script to re-run when the reminder fires, if any      |
| `session`   | the Claude Code session id (`${CLAUDE_SESSION_ID}`)                     |
| `created`   | ISO-8601 timestamp of creation                                          |

All keys are optional — include only what is known.

## Example

```
Re-run the nightly data sync and verify the row counts.

[claude-meta]
workspace=/Users/leppich/repos/acme/api
repo=git@github.com:acme/api.git
branch=main
command=./scripts/sync.sh --full
session=0c3f9e21
created=2026-06-02T14:30:00Z
```
