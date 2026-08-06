#!/bin/sh

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
launcher="$repo_dir/scripts/system/power-menu.sh"
test_dir=$(mktemp -d /tmp/clavis-power-menu-test.XXXXXX)

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

legacy_qs_action=qs
legacy_qs_action="$legacy_qs_action ipc call lock open"
legacy_key_action=key
legacy_key_action="$legacy_key_action ipc call lock open"
legacy_template='$'
legacy_template="${legacy_template}{"
legacy_template="${legacy_template}key"
legacy_template="${legacy_template}Command}"
legacy_env_name=CLAVIS
legacy_env_name="${legacy_env_name}_KEY"

mkdir -p "$test_dir/bin"

cat > "$test_dir/bin/niri" <<'EOF'
#!/bin/sh
cat <<'OUTPUT'
Output "Test" (TEST-1)
  Logical size: 1920x1080
OUTPUT
EOF

cat > "$test_dir/bin/wlogout" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" > "$MOCK_WLOGOUT_ARGS"
while [ "$#" -gt 0 ]; do
    if [ "$1" = "--layout" ]; then
        shift
        printf '%s\n' "$1" > "$MOCK_WLOGOUT_LAYOUT_ARG"
        cp -- "$1" "$MOCK_WLOGOUT_LAYOUT"
        shift
        continue
    fi
    if [ "$1" = "--css" ]; then
        shift
        cp -- "$1" "$MOCK_WLOGOUT_CSS"
        exit 0
    fi
    shift
done
exit 1
EOF

chmod +x "$test_dir/bin/niri" "$test_dir/bin/wlogout"
mkdir -p "$test_dir/config/clavis" "$test_dir/runtime"
printf '%s\n' \
    '{"effects":{"shellBackgroundOpacity":0.42}}' \
    > "$test_dir/config/clavis/config.json"

run_style() {
    style=$1
    expected_layout=$2
    expected_columns=$3
    args="$test_dir/$style.args"
    css="$test_dir/$style.css"
    layout="$test_dir/$style.layout"
    layout_arg="$test_dir/$style.layout-arg"

    MOCK_WLOGOUT_ARGS="$args" \
    MOCK_WLOGOUT_CSS="$css" \
    MOCK_WLOGOUT_LAYOUT="$layout" \
    MOCK_WLOGOUT_LAYOUT_ARG="$layout_arg" \
    HOME="$test_dir/home" \
    XDG_CONFIG_HOME="$test_dir/config" \
    XDG_DATA_HOME="$test_dir/data" \
    XDG_STATE_HOME="$test_dir/state" \
    XDG_CACHE_HOME="$test_dir/cache" \
    XDG_RUNTIME_DIR="$test_dir/runtime" \
    PATH="$test_dir/bin:$PATH" \
        "$launcher" "$style"

    assert_contains "$args" "--buttons-per-row"
    assert_contains "$args" "$expected_columns"
    assert_contains "$args" "--layout"
    assert_contains "$args" "--protocol"
    assert_contains "$args" "layer-shell"
    assert_contains "$css" 'font-family: "LXGW WenKai GB Screen"'
    assert_contains "$css" "$repo_dir/assets/wlogout/icons/lock_white.png"
    assert_contains "$css" "cubic-bezier(.55, 0, .28, 1.682)"
    assert_contains "$css" "background-color: alpha(#2a4a5f, 0.42)"
    if [ "$(cat "$layout_arg")" != "$repo_dir/assets/wlogout/$expected_layout" ]; then
        fail "$style did not pass the source layout directly to wlogout"
    fi
    assert_contains "$layout" '"action": "qs -c clavis ipc call lock open"'
    assert_not_contains "$layout" "$legacy_qs_action"
    assert_not_contains "$layout" "$legacy_key_action"
    assert_not_contains "$layout" "$legacy_template"
    assert_not_contains "$layout" "$legacy_env_name"

    if [ "$style" = row ]; then
        assert_contains "$layout" '"action": "qs -c clavis ipc call lock open && systemctl suspend"'
        assert_contains "$layout" '"action": "qs -c clavis ipc call lock open && systemctl hibernate"'
    fi

    if grep -Fq '${' "$css"; then
        fail "$style CSS contains an unresolved template variable"
    fi
}

run_style grid layout_2 2
run_style row layout_1 6

echo "power menu launcher tests passed"
