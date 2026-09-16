#!/bin/sh

set -u

printf '%s\n' "$*" >> "$MOCK_BREW_LOG"

case "${1-}" in
    update)
        exit 0
        ;;
    list)
        [ -f "$MOCK_VERSION_FILE" ] || exit 1
        printf 'reminders-cli %s\n' "$(cat "$MOCK_VERSION_FILE")"
        ;;
    install|upgrade)
        if [ "${MOCK_BREW_FAIL:-0}" != "0" ]; then
            printf 'mock Homebrew failure\n' >&2
            exit 1
        fi
        printf '%s\n' "$MOCK_TARGET_VERSION" > "$MOCK_VERSION_FILE"
        ;;
    --prefix)
        printf '%s\n' "$MOCK_FORMULA_PREFIX"
        ;;
    *)
        exit 12
        ;;
esac
