#!/bin/sh

set -u

plugin_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
fixtures="$plugin_root/tests/fixtures"
ensure_cli="$plugin_root/scripts/ensure-compatible-cli.sh"
temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/reminders-cli-management-tests.XXXXXX")
bin_dir="$temp_dir/bin"
empty_bin_dir="$temp_dir/empty-bin"
prefix_dir="$temp_dir/prefix"
version_file="$temp_dir/version"
brew_log="$temp_dir/brew.log"

cleanup() {
    rm -f "$bin_dir/reminders" "$prefix_dir/bin/reminders" "$version_file" "$brew_log"
    rmdir "$bin_dir" "$empty_bin_dir" "$prefix_dir/bin" "$prefix_dir" "$temp_dir" 2>/dev/null || true
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$bin_dir" "$empty_bin_dir" "$prefix_dir/bin"
ln -s "$fixtures/managed-reminders.sh" "$bin_dir/reminders"
ln -s "$fixtures/managed-reminders.sh" "$prefix_dir/bin/reminders"

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

run_ensure() {
    PATH="$1:/usr/bin:/bin" \
    BREW_BIN="$fixtures/mock-brew.sh" \
    MOCK_VERSION_FILE="$version_file" \
    MOCK_TARGET_VERSION="${MOCK_TARGET_VERSION:-3.1.0}" \
    MOCK_FORMULA_PREFIX="$prefix_dir" \
    MOCK_BREW_LOG="$brew_log" \
        "$ensure_cli"
}

printf '3.1.0\n' > "$version_file"
compatible_result=$(run_ensure "$bin_dir")
assert_equal "compatible CLI" "ok
$bin_dir/reminders
ready
3.1.0" "$compatible_result"
[ ! -f "$brew_log" ] || fail "compatible CLI unexpectedly invoked Homebrew"

printf '3.0.0\n' > "$version_file"
upgrade_result=$(MOCK_TARGET_VERSION=3.1.1 run_ensure "$bin_dir")
assert_equal "automatic upgrade" "ok
$prefix_dir/bin/reminders
upgraded
3.1.1" "$upgrade_result"
grep -q '^update$' "$brew_log" || fail "upgrade did not refresh Homebrew"
grep -q '^upgrade muhqu/tap/reminders-cli$' "$brew_log" ||
    fail "upgrade did not target the reminders formula"

rm -f "$version_file" "$brew_log"
install_result=$(MOCK_TARGET_VERSION=3.2.0 run_ensure "$empty_bin_dir")
assert_equal "automatic install" "ok
$prefix_dir/bin/reminders
installed
3.2.0" "$install_result"
grep -q '^install muhqu/tap/reminders-cli$' "$brew_log" ||
    fail "install did not target the reminders formula"

printf '3.0.0\n' > "$version_file"
if MOCK_TARGET_VERSION=3.0.0 run_ensure "$bin_dir" > "$temp_dir/failure-output"; then
    fail "incompatible Homebrew release unexpectedly succeeded"
fi
failure_result=$(cat "$temp_dir/failure-output")
rm -f "$temp_dir/failure-output"
assert_equal "unavailable compatible update" "error
reminders CLI 3.0.0 is incompatible; metadata filtering support is required, and Homebrew did not provide a compatible update." "$failure_result"

printf '3.0.0\n' > "$version_file"
if MOCK_BREW_FAIL=1 run_ensure "$bin_dir" > "$temp_dir/failure-output"; then
    fail "Homebrew failure unexpectedly succeeded"
fi
failure_result=$(cat "$temp_dir/failure-output")
rm -f "$temp_dir/failure-output"
assert_equal "Homebrew failure details" "error
Homebrew could not upgrade muhqu/tap/reminders-cli:
mock Homebrew failure" "$failure_result"

printf 'All CLI management tests passed.\n'
