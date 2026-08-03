#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
generator="$repo_dir/scripts/theme/generate_matugen_colors.sh"
test_dir=$(mktemp -d /tmp/clavis-matugen-test.XXXXXX)
test_runtime_dir="$test_dir/runtime"
mkdir -p "$test_runtime_dir"
unset CLAVIS_BIN_HOME CLAVIS_INSTALL_PREFIX CLAVIS_CONFIG_HOME \
    CLAVIS_DATA_HOME CLAVIS_STATE_HOME CLAVIS_CACHE_HOME \
    CLAVIS_PROFILE_HOME CLAVIS_PROFILE_CONFIG_HOME CLAVIS_GENERATED_HOME \
    CLAVIS_QML_IMPORT_HOME
export XDG_RUNTIME_DIR="$test_runtime_dir"
export CLAVIS_RUNTIME_HOME="$test_runtime_dir/clavis"

cleanup() { rm -rf -- "$test_dir"; }
trap cleanup EXIT HUP INT TERM
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

command -v matugen >/dev/null 2>&1 || fail "matugen is required"
command -v python3 >/dev/null 2>&1 || fail "python3 is required"

test_home="$test_dir/home"
mkdir -p "$test_home"
if HOME="$test_home" "$generator" >/dev/null 2>&1; then
    fail "generator accepted a missing source"
fi
if HOME="$test_home" "$generator" --color '#6750a4' --image x >/dev/null 2>&1; then
    fail "generator accepted image and color together"
fi
if HOME="$test_home" "$generator" --color '#6750a4' --mode sepia >/dev/null 2>&1; then
    fail "generator accepted an invalid mode"
fi
if HOME="$test_home" "$generator" --color '#6750a4' --templates unknown >/dev/null 2>&1; then
    fail "generator accepted an unknown template"
fi

HOME="$test_home" "$generator" --color '#6750a4' --dry-run >/dev/null
[[ ! -e "$test_home/.config" ]] || fail "dry-run modified ~/.config"
[[ ! -e "$test_home/.local" ]] || fail "dry-run modified ~/.local"

filtered_home="$test_dir/filtered"
HOME="$filtered_home" "$generator" \
    --color '#6750a4' --mode dark --templates yazi >/dev/null
generated="$filtered_home/.local/share/clavis/profiles/default/generated"
[[ -s "$generated/clavis/colors.json" ]] || fail "missing Quickshell colors"
[[ -s "$filtered_home/.config/yazi/theme.toml" ]] || fail "missing Yazi theme"
[[ ! -e "$filtered_home/.config/kitty" ]] || fail "disabled Kitty was modified"
[[ ! -e "$filtered_home/.config/btop" ]] || fail "disabled btop was modified"
[[ ! -e "$filtered_home/.config/niri/clavis/colors.kdl" ]] \
    || fail "disabled Niri was generated"
[[ ! -e "$filtered_home/.config/clavis/profiles/default/matugen/config.toml" ]] \
    || fail "an editable per-user Matugen config was recreated"

kitty_home="$test_dir/kitty"
HOME="$kitty_home" "$generator" --color '#6750a4' --templates kitty >/dev/null
[[ -s "$kitty_home/.config/kitty/themes/Matugen.conf" ]] \
    || fail "Kitty theme was not written to the user's normal config"
[[ -s "$kitty_home/.config/kitty/current-theme.conf" ]] \
    || fail "Kitty current-theme hook did not run"

quickshell_home="$test_dir/quickshell"
HOME="$quickshell_home" "$generator" --color '#6750a4' --templates '' >/dev/null
[[ -s "$quickshell_home/.local/share/clavis/profiles/default/generated/clavis/colors.json" ]] \
    || fail "Quickshell colors are not always generated"
[[ ! -e "$quickshell_home/.config" ]] \
    || fail "Quickshell-only generation modified external app config"

provider_home="$test_dir/provider"
provider_log="$test_dir/provider.log"
HOME="$provider_home" CLAVIS_FCITX5_THEME_COMMAND="$repo_dir/tests/fixtures/fcitx5-theme-provider.sh" \
    CLAVIS_FCITX5_TEST_LOG="$provider_log" "$generator" \
    --color '#6750a4' --mode light --scheme scheme-vibrant --templates fcitx5 >/dev/null
grep -Fq 'apply --mode light --scheme scheme-vibrant --color #6750a4' "$provider_log" \
    || fail "Fcitx5 provider did not receive the source and Matugen options"

for render_mode in dark light; do
    output_dir="$test_dir/render-$render_mode"
    render_config="$output_dir/config.toml"
    mkdir -p "$output_dir/yazi"
    sed \
        -e "s|input_path = \"templates/|input_path = \"$repo_dir/matugen/templates/|" \
        -e "s|@CLAVIS_GENERATED_HOME@/clavis/colors.json|$output_dir/colors.json|" \
        -e "s|@CLAVIS_NIRI_HOME@/clavis/colors.kdl|$output_dir/niri-colors.kdl|" \
        -e "s|~/.config/btop/themes/matugen.theme|$output_dir/btop.theme|" \
        -e "s|~/.config/cava/themes/matugen|$output_dir/cava|" \
        -e "s|~/.config/kitty/themes/Matugen.conf|$output_dir/kitty.conf|" \
        -e "s|~/.config/yazi/theme.toml|$output_dir/yazi/theme.toml|" \
        -e '/^post_hook = /d' \
        "$repo_dir/matugen/config.toml" > "$render_config"
    matugen color hex '#6750a4' --mode "$render_mode" \
        --type scheme-tonal-spot --config "$render_config" --quiet
    outputs=(
        "$output_dir/colors.json" "$output_dir/btop.theme" "$output_dir/cava"
        "$output_dir/kitty.conf"
        "$output_dir/niri-colors.kdl" "$output_dir/yazi/theme.toml"
    )
    for output in "${outputs[@]}"; do
        [[ -s "$output" ]] || fail "missing rendered output: $output"
        ! grep -Fq '{{' "$output" || fail "unrendered expression: $output"
    done
    python3 -m json.tool "$output_dir/colors.json" >/dev/null
    python3 -c 'import pathlib,sys,tomllib; tomllib.loads(pathlib.Path(sys.argv[1]).read_text())' \
        "$output_dir/yazi/theme.toml"
    grep -Fq 'active-gradient' "$output_dir/niri-colors.kdl" \
        || fail "Niri focus gradient is missing"
done

printf '%s\n' "matugen template tests passed"
