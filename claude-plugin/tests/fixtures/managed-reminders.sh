#!/bin/sh

set -u

[ -f "$MOCK_VERSION_FILE" ] || exit 11

if [ "${1-}" = "--version" ]; then
    cat "$MOCK_VERSION_FILE"
    exit 0
fi

if [ "${1-}" = "show" ] && [ "${2-}" = "--help" ]; then
    case "$(cat "$MOCK_VERSION_FILE")" in
        3.0.*)
            printf '%s\n' 'USAGE: reminders show'
            ;;
        *)
            printf '%s\n' 'USAGE: reminders show [--metadata <metadata>] [--hide-notes]'
            ;;
    esac
    exit 0
fi

exit 10
