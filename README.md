# reminders-cli

A simple CLI for interacting with OS X reminders.

## Access control

To limit the blast radius, this CLI can access **no** reminder lists by default.
You grant access in a config file at `~/.config/reminders-cli.yml` (override the
path with `REMINDERS_CLI_CONFIG`, or it honors `XDG_CONFIG_HOME`).

```yaml
# ~/.config/reminders-cli.yml
full_access: false        # set true to allow every list (disables the allowlist)
allowed_lists:            # exact names or case-insensitive glob patterns
  - "Work"
  - "Personal*"
```

Run `reminders init-config` to write a starter file pre-filled with your existing
list names as commented examples. Until a config grants a list, every read and
write to it is refused. Use `reminders show-lists --all` to see all lists (with an
`[allowed]` marker) when deciding what to add.

Note: macOS reminders permission is all-or-nothing at the OS level, so this
allowlist is a guardrail on what *this tool* will touch — not an OS sandbox.

## Usage:

#### Show all lists

```
$ reminders show-lists
Work
Personal
```

#### Show reminders on a specific list

```
$ reminders show Work
0 Write README
1 Ship reminders-cli
```

#### Complete an item on a list

```
$ reminders complete Work 0
Completed 'Write README'
$ reminders show Work
0 Ship reminders-cli
```

#### Undo a completed item

```
$ reminders show Work --only-completed
0 Write README
$ reminders uncomplete Work 0
Uncompleted 'Write README'
$ reminders show Work
0 Write README
```

#### Edit an item on a list

```
$ reminders edit Work 0 Some edited text
Updated reminder 'Some edited text'
$ reminders show Work
0 Ship reminders-cli
1 Some edited text
```

#### Delete an item on a list

```
$ reminders delete Work 0
Completed 'Write README'
$ reminders show Work
0 Ship reminders-cli
```

#### Add a reminder to a list

```
$ reminders add Work Contribute to open source
$ reminders add Work Go to the grocery store --due-date "tomorrow 9am"
$ reminders add Work Something really important --priority high
$ reminders show Work
0: Ship reminders-cli
1: Contribute to open source
2: Go to the grocery store (in 10 hours)
3: Something really important (priority: high)
```

#### Show reminders due on or by a date

```
$ reminders show-all --due-date today
1: Contribute to open source (in 3 hours)
$ reminders show-all --due-date today --include-overdue
0: Ship reminders-cli (2 days ago)
1: Contribute to open source (in 3 hours)
$ reminders show-all --due-date 2025-02-16
1: Contribute to open source (in 3 hours)
$ reminders show Work --due-date today --include-overdue
0: Ship reminders-cli (2 days ago)
1: Contribute to open source (in 3 hours)
```

#### Filter reminders by notes metadata

Agent-created reminders can include an `[agent-meta]` block in their notes. Use
repeatable `--metadata KEY=VALUE` options for exact OR matching, and
`--hide-notes` for concise plain output:

```
$ reminders show Claude --metadata "workspace=/Users/me/repos/acme/api" \
    --metadata "repo-id=github.com/acme/api" --hide-notes
0: Review the release checklist (in 2 hours)
```

Legacy `[claude-meta]` blocks are also supported.

#### See help for more examples

```
$ reminders --help
$ reminders show -h
```

## Installation:

#### With [Homebrew](http://brew.sh/)

```
$ brew install muhqu/tap/reminders-cli
```

#### From GitHub releases

Download the latest release from
[here](https://github.com/muhqu/reminders-cli/releases)

```
$ tar -zxvf reminders.tar.gz
$ mv reminders /usr/local/bin
$ rm reminders.tar.gz
```

#### Building manually

This requires a full Xcode installation (the release build is a universal
arm64 + x86_64 binary, which needs `xcodebuild`).

```
$ cd reminders-cli
$ make build
$ cp .build/apple/Products/Release/reminders /usr/local/bin/reminders
```

## Agent plugin for Claude Code and GitHub Copilot CLI

This repo also ships a cross-client agent plugin in [`claude-plugin/`](claude-plugin/) that lets
Claude Code and GitHub Copilot CLI create and manage Apple/iCloud Reminders. For example,
*"remind me next Monday to run this script again"* files a reminder on the dedicated `Claude` list,
capturing the workspace and command to re-run. New reminders use `[agent-meta]`; existing
`[claude-meta]` reminders remain readable.

The integration is for local macOS sessions because the CLI uses EventKit. Remote/cloud Linux
agents gracefully skip the session-start lookup and cannot access Apple Reminders.

### Claude Code

```
/plugin marketplace add muhqu/reminders-cli
/plugin install reminders@reminders-cli
```

### GitHub Copilot CLI

```
copilot plugin install muhqu/reminders-cli:claude-plugin
```

At the start or resumption of a local session, the plugin shows incomplete reminders from the
`Claude` list that are due today or overdue and whose metadata matches the exact workspace or
repository. It stays silent when there are no matches and never filters by branch.

See [`claude-plugin/README.md`](claude-plugin/README.md) for prerequisites, setup, and usage.
