---
name: reminders-setup
description: >-
  Set up or troubleshoot the reminders plugin: verify the `reminders` CLI is installed, Reminders
  access is granted, the config exists, and the dedicated `Claude` list exists and is allowlisted.
  Use when first setting up, or when creating/listing reminders fails.
allowed-tools:
  - "Bash(reminders:*)"
  - "Bash(command -v reminders)"
  - "Read"
  - "Edit"
---

# Reminders setup / doctor

Run these checks in order. Report each result. Stop to ask the user only when an action needs them
(installing software, granting an OS permission, or editing their config).

## 1. CLI installed
```bash
command -v reminders
```
If missing, tell the user to install it (do **not** auto-install):
```
brew install muhqu/tap/reminders-cli
```

## 2. Reminders access (macOS TCC)
```bash
reminders show-lists --all --format json
```
`show-lists --all` works without any config (it enumerates every list for discovery). If it errors
with an access/permission error, the binary lacks Reminders access: the first run from a terminal
triggers the macOS permission prompt — have the user grant it; otherwise enable it under
**System Settings ▸ Privacy & Security ▸ Reminders** for their terminal app, then re-run.

## 3. Config file
Check for `~/.config/reminders-cli.yml` (honor `REMINDERS_CLI_CONFIG` / `XDG_CONFIG_HOME` if set).
If absent, create a starter:
```bash
reminders init-config
```

## 4. Dedicated `Claude` list (on iCloud)
- If `Claude` is **not** present in `reminders show-lists --all`, create it:
  ```bash
  reminders new-list "Claude" --source iCloud
  ```
  If the source name `iCloud` isn't found, omit `--source` to use the default source — but prefer
  iCloud so reminders sync to the user's other devices.
- Then confirm it is **allowlisted**: `reminders show-lists` (without `--all`) must list `Claude`.
  If it doesn't, the config isn't granting it. Open `~/.config/reminders-cli.yml` and add `Claude`
  to `allowed_lists`:
  ```yaml
  allowed_lists:
    - "Claude"
  ```
  Show the user the change and confirm before writing it.

## Done
When all four checks pass, tell the user they're ready — they can say things like
*"remind me tomorrow at 9am to ..."* and Claude will file it on the `Claude` list.
