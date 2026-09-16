#!/bin/sh

set -u

has_pair() {
    expected_key=$1
    expected_value=$2
    shift 2

    while [ "$#" -gt 1 ]; do
        if [ "$1" = "$expected_key" ] && [ "$2" = "$expected_value" ]; then
            return 0
        fi
        shift
    done
    return 1
}

has_flag() {
    expected=$1
    shift
    for argument in "$@"; do
        [ "$argument" = "$expected" ] && return 0
    done
    return 1
}

[ "${1-}" = "show" ] || exit 10
[ "${2-}" = "Claude" ] || exit 11
has_pair "--due-date" "today" "$@" || exit 20
has_flag "--include-overdue" "$@" || exit 24
has_flag "--hide-notes" "$@" || exit 25
has_flag "--include-completed" "$@" && exit 26
has_flag "--only-completed" "$@" && exit 27
has_pair "--metadata" "workspace=$MOCK_WORKSPACE" "$@" || exit 21

for argument in "$@"; do
    case "$argument" in
        branch=*)
            exit 28
            ;;
    esac
done

case "${MOCK_SCENARIO:-}" in
    workspace)
        cat "$MOCK_FIXTURES/workspace-output.txt"
        ;;
    repo)
        has_pair "--metadata" "repo=$MOCK_REPO" "$@" || exit 22
        has_pair "--metadata" "repo-id=github.com/example/project" "$@" || exit 29
        cat "$MOCK_FIXTURES/repo-output.txt"
        ;;
    no-matches)
        cat "$MOCK_FIXTURES/no-matches-output.txt"
        ;;
    failure)
        cat "$MOCK_FIXTURES/failure-error.txt" >&2
        exit 1
        ;;
    *)
        exit 23
        ;;
esac
