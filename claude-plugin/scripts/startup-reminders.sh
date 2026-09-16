#!/bin/sh

set -u

emit() {
    printf '%s\n' "$1"
    if [ "$#" -gt 1 ] && [ -n "$2" ]; then
        printf '%s\n' "$2"
    fi
}

[ "${REMINDERS_HOOK_OS:-$(uname -s 2>/dev/null)}" = "Darwin" ] || {
    emit "none"
    exit 0
}

workspace=${1:-$PWD}
plugin_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

normalize_repo() {
    remote=$1
    case "$remote" in
        *://*)
            remote=${remote#*://}
            remote=${remote#*@}
            ;;
        *@*:*)
            remote=${remote#*@}
            host=${remote%%:*}
            path=${remote#*:}
            remote=$host/$path
            ;;
        *)
            return
            ;;
    esac

    host=${remote%%/*}
    [ "$host" != "$remote" ] || return
    path=${remote#*/}
    path=${path%/}
    path=${path%.git}
    [ -n "$host" ] && [ -n "$path" ] || return
    printf '%s/%s\n' "$host" "$path" | tr '[:upper:]' '[:lower:]'
}

cli_result=$("$plugin_root/scripts/ensure-compatible-cli.sh")
cli_status=$(printf '%s\n' "$cli_result" | sed -n '1p')
if [ "$cli_status" != "ok" ]; then
    emit "hint" "$(printf '%s\n' "$cli_result" | sed '1d')"
    exit 0
fi
reminders_bin=$(printf '%s\n' "$cli_result" | sed -n '2p')

physical_workspace=$(CDPATH= cd -- "$workspace" 2>/dev/null && pwd -P)
[ -n "$physical_workspace" ] || physical_workspace=$workspace

set -- show "Claude" --due-date today --include-overdue --hide-notes \
    --metadata "workspace=$physical_workspace"
if [ "$workspace" != "$physical_workspace" ]; then
    set -- "$@" --metadata "workspace=$workspace"
fi

git_bin=${GIT_BIN:-git}
if command -v "$git_bin" >/dev/null 2>&1; then
    repo=$("$git_bin" -C "$physical_workspace" remote get-url origin 2>/dev/null || true)
    if [ -n "$repo" ]; then
        set -- "$@" --metadata "repo=$repo"
        repo_id=$(normalize_repo "$repo")
        if [ -n "$repo_id" ]; then
            set -- "$@" --metadata "repo-id=$repo_id"
        fi
    fi
fi

output=$("$reminders_bin" "$@" 2>/dev/null)
status=$?
if [ "$status" -ne 0 ]; then
    emit "hint" "Reminders startup check skipped: run the reminders setup skill to verify the Claude list, config, and macOS Reminders access."
    exit 0
fi

if [ -z "$output" ]; then
    emit "none"
    exit 0
fi

emit "ok" "Project reminders due today or overdue:
$output"
