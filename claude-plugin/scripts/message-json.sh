#!/bin/sh

set -u

[ "${REMINDERS_HOOK_OS:-$(uname -s 2>/dev/null)}" = "Darwin" ] || exit 1

protocol=${1-}
message=${2-}
temp_file=$(mktemp "${TMPDIR:-/tmp}/reminders-hook-json.XXXXXX") || exit 1
trap 'rm -f "$temp_file"' EXIT HUP INT TERM

/usr/bin/plutil -create xml1 "$temp_file" || exit 1
case "$protocol" in
    claude)
        /usr/bin/plutil -insert systemMessage -string "$message" "$temp_file" || exit 1
        ;;
    copilot)
        /usr/bin/plutil -insert type -string progress "$temp_file" || exit 1
        /usr/bin/plutil -insert message -string "$message" "$temp_file" || exit 1
        ;;
    *)
        exit 1
        ;;
esac

/usr/bin/plutil -convert json -o - "$temp_file"
