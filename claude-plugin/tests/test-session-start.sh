#!/bin/sh

set -u

plugin_root=${PLUGIN_ROOT_OVERRIDE:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}
fixtures="$plugin_root/tests/fixtures"
mock="$fixtures/mock-reminders.sh"
mock_git="$fixtures/mock-git.sh"
temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/reminders-plugin-tests.XXXXXX")
trap 'rmdir "$temp_dir/workspace" "$temp_dir/repository" "$temp_dir" 2>/dev/null || true' EXIT HUP INT TERM

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_equal() {
    label=$1
    expected=$2
    actual=$3
    [ "$actual" = "$expected" ] || {
        printf 'FAIL: %s\nexpected:\n%s\nactual:\n%s\n' "$label" "$expected" "$actual" >&2
        exit 1
    }
}

run_lookup() {
    scenario=$1
    workspace=$2
    MOCK_SCENARIO=$scenario \
    MOCK_WORKSPACE=$workspace \
    MOCK_REPO=${MOCK_REPO:-} \
    MOCK_FIXTURES=$fixtures \
    REMINDERS_BIN=$mock \
    GIT_BIN=${MOCK_GIT_BIN:-git} \
    REMINDERS_HOOK_OS=Darwin \
        "$plugin_root/scripts/startup-reminders.sh" "$workspace"
}

workspace_dir="$temp_dir/workspace"
mkdir -p "$workspace_dir"

workspace_result=$(run_lookup workspace "$workspace_dir")
assert_equal "workspace match" "ok
Project reminders due today or overdue:
0: Review \"workspace\" path C:\\tmp (today)" "$workspace_result"

repo_dir="$temp_dir/repository"
mkdir -p "$repo_dir"
MOCK_REPO=git@github.com:example/project.git
MOCK_GIT_BIN=$mock_git
repo_result=$(MOCK_REPO="$MOCK_REPO" MOCK_GIT_BIN="$MOCK_GIT_BIN" run_lookup repo "$repo_dir")
assert_equal "repository fallback" "ok
Project reminders due today or overdue:
0: Re-run the repository release check (2 hours ago)" "$repo_result"

no_matches_result=$(run_lookup no-matches "$workspace_dir")
assert_equal "no matches" "none" "$no_matches_result"

failure_result=$(run_lookup failure "$workspace_dir")
assert_equal "query failure" "hint
Reminders startup check skipped: run the reminders setup skill to verify the Claude list, config, and macOS Reminders access." "$failure_result"

missing_result=$(REMINDERS_BIN="$temp_dir/missing-reminders" REMINDERS_HOOK_OS=Darwin \
    "$plugin_root/scripts/startup-reminders.sh" "$workspace_dir")
assert_equal "missing CLI" "hint
Reminders startup check skipped: install reminders-cli, then run the reminders setup skill." "$missing_result"

hook_input=$(printf '{"cwd":"%s","source":"resume"}' "$workspace_dir")
claude_output=$(printf '%s' "$hook_input" | \
    MOCK_SCENARIO=workspace MOCK_WORKSPACE="$workspace_dir" MOCK_FIXTURES="$fixtures" \
    REMINDERS_BIN="$mock" REMINDERS_HOOK_OS=Darwin \
    "$plugin_root/hooks/session-start.sh")
claude_message=$(printf '%s' "$claude_output" | \
    /usr/bin/plutil -extract systemMessage raw -o - - 2>/dev/null) ||
    fail "Claude adapter did not emit systemMessage JSON"
assert_equal "Claude adapter message" "Project reminders due today or overdue:
0: Review \"workspace\" path C:\\tmp (today)" "$claude_message"

copilot_output=$(printf '%s' "$hook_input" | \
    MOCK_SCENARIO=workspace MOCK_WORKSPACE="$workspace_dir" MOCK_FIXTURES="$fixtures" \
    REMINDERS_BIN="$mock" REMINDERS_HOOK_OS=Darwin \
    "$plugin_root/com.github.copilot/hooks/session-start.sh")
copilot_type=$(printf '%s' "$copilot_output" | \
    /usr/bin/plutil -extract type raw -o - - 2>/dev/null) ||
    fail "Copilot adapter did not emit progress JSON"
copilot_message=$(printf '%s' "$copilot_output" | \
    /usr/bin/plutil -extract message raw -o - - 2>/dev/null) ||
    fail "Copilot adapter progress message is invalid"
assert_equal "Copilot adapter type" "progress" "$copilot_type"
assert_equal "Copilot adapter message" "Project reminders due today or overdue:
0: Review \"workspace\" path C:\\tmp (today)" "$copilot_message"

silent_output=$(printf '%s' "$hook_input" | \
    MOCK_SCENARIO=no-matches MOCK_WORKSPACE="$workspace_dir" MOCK_FIXTURES="$fixtures" \
    REMINDERS_BIN="$mock" REMINDERS_HOOK_OS=Darwin \
    "$plugin_root/hooks/session-start.sh")
assert_equal "silent no-match adapter" "" "$silent_output"

failure_output=$(printf '%s' "$hook_input" | \
    MOCK_SCENARIO=failure MOCK_WORKSPACE="$workspace_dir" MOCK_FIXTURES="$fixtures" \
    REMINDERS_BIN="$mock" REMINDERS_HOOK_OS=Darwin \
    "$plugin_root/com.github.copilot/hooks/session-start.sh")
failure_message=$(printf '%s' "$failure_output" | \
    /usr/bin/plutil -extract message raw -o - - 2>/dev/null) ||
    fail "failure adapter did not emit non-blocking progress JSON"
assert_equal "failure adapter message" \
    "Reminders startup check skipped: run the reminders setup skill to verify the Claude list, config, and macOS Reminders access." \
    "$failure_message"

linux_output=$(printf '%s' "$hook_input" | \
    MOCK_SCENARIO=workspace MOCK_WORKSPACE="$workspace_dir" MOCK_FIXTURES="$fixtures" \
    REMINDERS_BIN="$mock" REMINDERS_HOOK_OS=Linux \
    "$plugin_root/com.github.copilot/hooks/session-start.sh")
assert_equal "Linux no-op" "" "$linux_output"

printf 'All session-start hook tests passed.\n'
