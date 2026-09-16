#!/bin/sh

set -u

[ "${REMINDERS_HOOK_OS:-$(uname -s 2>/dev/null)}" = "Darwin" ] || exit 0

plugin_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
workspace=$(/usr/bin/plutil -extract cwd raw -o - - 2>/dev/null || true)
[ -n "$workspace" ] || workspace=$PWD

result=$("$plugin_root/scripts/startup-reminders.sh" "$workspace")
status=$(printf '%s\n' "$result" | sed -n '1p')
[ "$status" = "ok" ] || [ "$status" = "hint" ] || exit 0

message=$(printf '%s\n' "$result" | sed '1d')
"$plugin_root/scripts/message-json.sh" claude "$message" || exit 0
