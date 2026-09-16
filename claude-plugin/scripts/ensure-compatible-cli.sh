#!/bin/sh

set -u

formula=${REMINDERS_FORMULA:-muhqu/tap/reminders-cli}

emit_success() {
    printf 'ok\n%s\n%s\n%s\n' "$1" "$2" "$3"
}

emit_error() {
    printf 'error\n%s\n' "$1"
    exit 1
}

check_candidate() {
    candidate=$1
    [ -x "$candidate" ] || return 1
    detected_version=$("$candidate" --version 2>/dev/null | sed -n '1p')
    [ -n "$detected_version" ] || detected_version=unknown
    help_output=$("$candidate" show --help 2>/dev/null) || return 1
    printf '%s\n' "$help_output" | grep -q -- '--metadata' || return 1
    printf '%s\n' "$help_output" | grep -q -- '--hide-notes'
}

if [ -n "${REMINDERS_BIN:-}" ]; then
    check_candidate "$REMINDERS_BIN" ||
        emit_error "Configured reminders CLI '$REMINDERS_BIN' is missing or lacks required metadata filtering support."
    emit_success "$REMINDERS_BIN" "ready" "$detected_version"
    exit 0
fi

reminders_bin=$(command -v reminders 2>/dev/null || true)
if [ -n "$reminders_bin" ] && check_candidate "$reminders_bin"; then
    emit_success "$reminders_bin" "ready" "$detected_version"
    exit 0
fi

previous_version=${detected_version:-not installed}
brew_bin=${BREW_BIN:-brew}
case "$brew_bin" in
    */*)
        [ -x "$brew_bin" ] ||
            emit_error "A reminders CLI with metadata filtering support is required, but Homebrew is unavailable."
        ;;
    *)
        brew_bin=$(command -v "$brew_bin" 2>/dev/null || true)
        [ -n "$brew_bin" ] ||
            emit_error "A reminders CLI with metadata filtering support is required, but Homebrew is unavailable."
        ;;
esac

"$brew_bin" update >/dev/null 2>&1 || true
if "$brew_bin" list --versions "$formula" >/dev/null 2>&1; then
    action=upgraded
    brew_operation=upgrade
else
    action=installed
    brew_operation=install
fi
brew_output=$("$brew_bin" "$brew_operation" "$formula" 2>&1)
brew_status=$?

prefix=$("$brew_bin" --prefix "$formula" 2>/dev/null || true)
managed_bin=
if [ -n "$prefix" ]; then
    managed_bin=$prefix/bin/reminders
fi

if [ -n "$managed_bin" ] && check_candidate "$managed_bin"; then
    emit_success "$managed_bin" "$action" "$detected_version"
    exit 0
fi

hash -r 2>/dev/null || true
reminders_bin=$(command -v reminders 2>/dev/null || true)
if [ -n "$reminders_bin" ] && check_candidate "$reminders_bin"; then
    emit_success "$reminders_bin" "$action" "$detected_version"
    exit 0
fi

if [ "$brew_status" -ne 0 ]; then
    emit_error "Homebrew could not $brew_operation $formula:
$brew_output"
fi

emit_error "reminders CLI $previous_version is incompatible; metadata filtering support is required, and Homebrew did not provide a compatible update."
