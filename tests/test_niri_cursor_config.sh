#!/bin/sh

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
writer="$repo_dir/scripts/theme/write_niri_cursor_config.sh"
mock_niri="$repo_dir/tests/fixtures/mock-niri"
theme_service="$repo_dir/Services/ThemeService.qml"
personalization="$repo_dir/Services/PersonalizationConfig.qml"
theme_page="$repo_dir/Modules/ControlCenter/ThemePage.qml"
test_dir=$(mktemp -d /tmp/clavis-niri-cursor-test.XXXXXX)

cleanup() {
    rm -rf -- "$test_dir"
}
trap cleanup EXIT HUP INT TERM

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_contains() {
    grep -Fq -- "$2" "$1" || fail "$1 does not contain: $2"
}

assert_not_contains() {
    if grep -Fq -- "$2" "$1"; then
        fail "$1 unexpectedly contains: $2"
    fi
}

main_config="$test_dir/config.kdl"
cursor_config="$test_dir/clavis/cursor.kdl"
printf '%s\n' 'input {}' > "$main_config"

theme='Fancy "Cursor\Theme'
"$writer" "$cursor_config" "$main_config" "$theme" 32 true 1200 "$mock_niri" >/dev/null
assert_contains "$cursor_config" 'Managed by Clavis. Manual edits will be replaced.'
assert_contains "$cursor_config" 'xcursor-theme "Fancy \"Cursor\\Theme"'
assert_contains "$cursor_config" 'xcursor-size 32'
assert_contains "$cursor_config" 'hide-when-typing'
assert_contains "$cursor_config" 'hide-after-inactive-ms 1200'
assert_contains "$main_config" 'include optional=true "clavis/cursor.kdl"'
[ -f "$main_config.clavis-backup" ] || fail "main config backup was not created"

"$writer" "$cursor_config" "$main_config" "" 24 false 0 "$mock_niri" >/dev/null
[ "$(grep -Fc 'include optional=true "clavis/cursor.kdl"' "$main_config")" -eq 1 ] \
    || fail "cursor include was duplicated"
assert_not_contains "$cursor_config" 'xcursor-theme'
assert_not_contains "$cursor_config" 'hide-when-typing'
assert_not_contains "$cursor_config" 'hide-after-inactive-ms'

printf '%s\n' 'known-good' > "$cursor_config"
if MOCK_NIRI_FAIL=1 "$writer" "$cursor_config" "$main_config" \
    "Broken" 30 false 0 "$mock_niri" >/dev/null 2>&1; then
    fail "invalid generated cursor config unexpectedly succeeded"
fi
assert_contains "$cursor_config" 'known-good'

invalid_main="$test_dir/invalid-config.kdl"
invalid_cursor="$test_dir/invalid/clavis/cursor.kdl"
printf '%s\n' 'INVALID' > "$invalid_main"
mkdir -p "$(dirname -- "$invalid_cursor")"
printf '%s\n' 'known-good' > "$invalid_cursor"
if "$writer" "$invalid_cursor" "$invalid_main" \
    "Valid" 30 false 0 "$mock_niri" >/dev/null 2>&1; then
    fail "invalid main config unexpectedly succeeded"
fi
[ "$(cat "$invalid_main")" = "INVALID" ] \
    || fail "invalid main config was overwritten"
[ "$(cat "$invalid_cursor")" = "known-good" ] \
    || fail "cursor fragment changed for invalid main config"
[ ! -e "$invalid_main.clavis-backup" ] \
    || fail "backup was created for invalid main config"

assert_contains "$personalization" 'property bool loaded: false'
assert_contains "$personalization" 'signal settingsLoaded()'
assert_contains "$personalization" 'function normalizedCursorTheme(value)'
assert_contains "$theme_service" 'PersonalizationConfig.ready'
assert_contains "$theme_service" 'function onSettingsLoaded()'
assert_contains "$theme_service" 'root.cursorConfigScript'
assert_contains "$theme_service" 'root.niriConfigPath'
assert_contains "$theme_page" 'title: qsTr("Niri 光标配置")'
assert_contains "$theme_page" 'ThemeService.cursorLastError'
assert_not_contains "$theme_service" 'escapeKdlString'
assert_not_contains "$theme_service" 'writeNiriCursorProcess.running = false'

echo "niri cursor config tests passed"
