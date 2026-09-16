---
name: list-reminders
description: >-
  Show or read back the user's Apple/iCloud Reminders created by a coding agent — e.g. "what reminders
  do I have", "show my reminders for this project", "what's due today". Can filter to the current
  workspace/repo and complete, snooze, or re-run them.
argument-hint: "[optional filter, e.g. 'this repo' or 'today']"
---

# List reminders

Read reminders via the `reminders` CLI and present them.

## Ensure a compatible CLI

Before the first CLI call, run `../../scripts/ensure-compatible-cli.sh`, resolved from this skill's
base directory. It automatically installs or upgrades `muhqu/tap/reminders-cli` with Homebrew when
the CLI is missing or incompatible. On success, use the absolute binary path from the second output
line for every command below. On `error`, report the message and stop; never silently fall back to
behavior unsupported by the installed CLI.

## Fetch
```bash
"<reminders-binary>" show "Claude" --format json
```
Use `"<reminders-binary>" show-all --format json` if the user wants reminders across all
(allowlisted) lists.
Add `--include-completed` only if they ask to see completed ones.

For **this project/repository**, gather the physical current directory with `pwd -P` and the origin
URL with `git remote get-url origin` when available. Also derive `repo-id` by converting an
SSH/HTTPS origin to lowercase host plus path and removing any user, scheme, trailing slash, and
`.git` suffix. Delegate filtering to the CLI using repeatable `--metadata` options, which have OR
semantics:

```bash
"<reminders-binary>" show "Claude" --metadata "workspace=<exact-directory>" \
  --metadata "repo=<origin-url>" --metadata "repo-id=<normalized-origin>" --format json
```

Omit repository criteria outside a repository. Legacy reminders generally match the raw `repo`;
new reminders also match `repo-id` if the checkout's remote changes between SSH and HTTPS. Never
filter by branch. For date scopes, use the CLI's existing date options rather than filtering JSON
in the model. For example:

```bash
"<reminders-binary>" show "Claude" --due-date today --include-overdue --format json
```

## Parse
Each JSON item has `title`, `dueDate` (ISO-8601), `isCompleted`, `externalId`, and `notes`. The
notes may contain an `[agent-meta]` block or a legacy `[claude-meta]` block, as documented in this
plugin's `reference/metadata-format.md`. Both markers carry the same keys. Branch metadata is
historical context only and must not affect project filtering.

## Present
List each matching reminder with its title, a human-friendly due date, and the useful metadata —
especially `command` when present.

## Act (on request, target by `externalId`)
- **Complete:** `"<reminders-binary>" complete "Claude" <externalId>`
- **Snooze / reschedule:** `"<reminders-binary>" edit "Claude" <externalId> --due-date "<new when>"`
- **Re-run:** if a reminder carries a `command`, offer to run it — confirm with the user first,
  and prefer running it from the reminder's `workspace` directory.
