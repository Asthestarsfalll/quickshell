#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
generator="$repo_dir/scripts/theme/generate_matugen_colors.sh"
test_dir="$(mktemp -d /tmp/clavis-matugen-test.XXXXXX)"
export CLAVIS_RUNTIME_HOME="$test_dir/runtime"

cleanup() {
    rm -rf -- "$test_dir"
}
trap cleanup EXIT HUP INT TERM

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

command -v matugen >/dev/null 2>&1 || fail "matugen is required"
command -v python3 >/dev/null 2>&1 || fail "python3 is required"
command -v yazi >/dev/null 2>&1 || fail "yazi is required"
command -v zsh >/dev/null 2>&1 || fail "zsh is required"

grep -Fq 'source[id] === undefined ? false' \
    "$repo_dir/Services/PersonalizationConfig.qml" \
    || fail "legacy settings implicitly enable profile templates"
grep -Fq 'root.matugenTemplates[id] === true' \
    "$repo_dir/Services/PersonalizationConfig.qml" \
    || fail "missing profile template flags do not fail closed"

test_home="$test_dir/home"
mkdir -p "$test_home"

if HOME="$test_home" "$generator" >/dev/null 2>&1; then
    fail "generator unexpectedly accepted a missing source"
fi
if HOME="$test_home" "$generator" \
    --color "#6750a4" \
    --image "$repo_dir/assets/images/dino.png" \
    >/dev/null 2>&1; then
    fail "generator unexpectedly accepted image and color together"
fi
if HOME="$test_home" "$generator" \
    --color "#6750a4" \
    --mode sepia \
    >/dev/null 2>&1; then
    fail "generator unexpectedly accepted an invalid mode"
fi
if HOME="$test_home" "$generator" \
    --color "#6750a4" \
    --templates "kitty,unknown" \
    >/dev/null 2>&1; then
    fail "generator unexpectedly accepted an unknown template"
fi

# Dry-run must not create generated or external application files.
HOME="$test_home" "$generator" \
    --color "#6750a4" \
    --mode dark \
    --scheme scheme-tonal-spot \
    --dry-run
[[ ! -e "$test_home/.config" ]] \
    || fail "dry-run created a user configuration directory"
[[ ! -e "$test_home/.local/share/clavis/profiles/default/generated" ]] \
    || fail "dry-run created generated profile files"

filtered_home="$test_dir/filtered-home"
HOME="$filtered_home" "$generator" \
    --color "#6750a4" \
    --mode dark \
    --scheme scheme-tonal-spot \
    --templates "yazi,zsh_prompt"

filtered_outputs=(
    "$filtered_home/.local/share/clavis/profiles/default/generated/clavis/colors.json"
    "$filtered_home/.local/share/clavis/profiles/default/generated/zsh/prompt-colors.zsh"
    "$filtered_home/.local/share/clavis/profiles/default/generated/yazi/theme.toml"
)
[[ -s "$filtered_home/.config/clavis/profiles/default/matugen/config.toml" ]] \
    || fail "persistent Matugen config was not initialized"
for output in "${filtered_outputs[@]}"; do
    [[ -s "$output" ]] || fail "missing filtered output: $output"
done

disabled_outputs=(
    "$filtered_home/.local/share/clavis/profiles/default/generated/btop/themes/clavis.theme"
    "$filtered_home/.local/share/clavis/profiles/default/generated/cava/colors.ini"
    "$filtered_home/.local/share/clavis/profiles/default/generated/kitty/colors.conf"
    "$filtered_home/.local/share/clavis/profiles/default/data/fcitx5/themes/Clavis/theme.conf"
    "$filtered_home/.local/share/clavis/profiles/default/generated/niri/colors.kdl"
)
for output in "${disabled_outputs[@]}"; do
    [[ ! -e "$output" ]] || fail "disabled template generated output: $output"
done

kitty_home="$test_dir/kitty-home"
HOME="$kitty_home" "$generator" \
    --color "#6750a4" \
    --mode dark \
    --scheme scheme-tonal-spot \
    --templates "kitty"
[[ -s "$kitty_home/.local/share/clavis/profiles/default/generated/kitty/colors.conf" ]] \
    || fail "Kitty profile colors were not generated"
[[ ! -e "$kitty_home/.config/kitty" ]] \
    || fail "profile generation modified the user's Kitty configuration"

quickshell_only_home="$test_dir/quickshell-only-home"
HOME="$quickshell_only_home" "$generator" \
    --color "#6750a4" \
    --mode dark \
    --scheme scheme-tonal-spot \
    --templates ""
[[ -s "$quickshell_only_home/.local/share/clavis/profiles/default/generated/clavis/colors.json" ]] \
    || fail "Quickshell output is missing when all external templates are disabled"
[[ -s "$quickshell_only_home/.config/clavis/profiles/default/matugen/config.toml" ]] \
    || fail "default generation did not create the editable Matugen config"
[[ ! -e "$quickshell_only_home/.config/kitty" ]] \
    || fail "default generation modified the user's Kitty configuration"
[[ ! -e "$quickshell_only_home/.local/share/clavis/profiles/default/generated/zsh/prompt-colors.zsh" ]] \
    || fail "Zsh prompt output was generated for an empty selection"

custom_home="$test_dir/custom-home"
HOME="$custom_home" "$generator" \
    --color "#6750a4" --templates "kitty"
custom_config="$custom_home/.config/clavis/profiles/default/matugen/config.toml"
custom_kitty="$custom_home/custom/kitty-colors.conf"
sed -i \
    "s|$custom_home/.local/share/clavis/profiles/default/generated/kitty/colors.conf|$custom_kitty|" \
    "$custom_config"
HOME="$custom_home" "$generator" \
    --color "#6750a4" --templates "kitty"
[[ -s "$custom_kitty" ]] \
    || fail "custom Matugen output_path was not honored"

invalid_home="$test_dir/invalid-home"
HOME="$invalid_home" "$generator" --color "#6750a4" >/dev/null
invalid_config="$invalid_home/.config/clavis/profiles/default/matugen/config.toml"
printf '%s\n' '[templates.quickshell' > "$invalid_config"
if HOME="$invalid_home" "$generator" --color "#6750a4" >/dev/null 2>&1; then
    fail "generator unexpectedly accepted invalid Matugen TOML"
fi
HOME="$invalid_home" "$repo_dir/scripts/theme/ensure_matugen_config.sh" \
    >/dev/null || fail "invalid Matugen config cannot be opened for repair"
grep -Fxq '[templates.quickshell' "$invalid_config" \
    || fail "opening an invalid Matugen config unexpectedly replaced it"

relative_home="$test_dir/relative-home"
HOME="$relative_home" "$generator" --color "#6750a4" >/dev/null
relative_config="$relative_home/.config/clavis/profiles/default/matugen/config.toml"
sed -i '0,/output_path = ".*"/s//output_path = "relative\/colors.json"/' \
    "$relative_config"
if HOME="$relative_home" "$generator" --color "#6750a4" >/dev/null 2>&1; then
    fail "generator unexpectedly accepted a relative Matugen output path"
fi

unwritable_home="$test_dir/unwritable-home"
HOME="$unwritable_home" "$generator" --color "#6750a4" >/dev/null
unwritable_config="$unwritable_home/.config/clavis/profiles/default/matugen/config.toml"
sed -i '0,/output_path = ".*"/s||output_path = "/proc/clavis/colors.json"|' \
    "$unwritable_config"
if HOME="$unwritable_home" "$generator" --color "#6750a4" >/dev/null 2>&1; then
    fail "generator unexpectedly accepted an unwritable output path"
fi

mock_bin="$test_dir/bin"
mkdir -p "$mock_bin"
cat > "$mock_bin/matugen" <<'EOF'
#!/usr/bin/env sh
exit 42
EOF
chmod +x "$mock_bin/matugen"
if HOME="$test_home" PATH="$mock_bin:$PATH" "$generator" \
    --color "#6750a4" \
    --dry-run \
    >/dev/null 2>&1; then
    fail "generator swallowed a matugen failure"
fi

for render_mode in dark light; do
    output_dir="$test_dir/$render_mode"
    render_config="$output_dir/render.toml"
    mkdir -p "$output_dir/yazi"

    cat > "$render_config" <<EOF
[config]
version_check = false

[templates.quickshell]
input_path = "$repo_dir/matugen/templates/quickshell-colors.json"
output_path = "$output_dir/colors.json"

[templates.btop]
input_path = "$repo_dir/matugen/templates/btop.theme"
output_path = "$output_dir/btop.theme"

[templates.cava]
input_path = "$repo_dir/matugen/templates/cava-colors.ini"
output_path = "$output_dir/cava"

[templates.kitty]
input_path = "$repo_dir/matugen/templates/kitty-colors.conf"
output_path = "$output_dir/kitty.conf"

[templates.fcitx5]
input_path = "$repo_dir/matugen/templates/fcitx5-theme.conf"
output_path = "$output_dir/fcitx5.conf"

[templates.niri]
input_path = "$repo_dir/matugen/templates/niri-colors.kdl"
output_path = "$output_dir/niri-colors.kdl"

[templates.yazi]
input_path = "$repo_dir/matugen/templates/yazi-theme.toml"
output_path = "$output_dir/yazi/theme.toml"

[templates.zsh_prompt]
input_path = "$repo_dir/matugen/templates/zsh-prompt-colors.zsh"
output_path = "$output_dir/zsh-prompt-colors.zsh"
EOF

    matugen color hex "#6750a4" \
        --mode "$render_mode" \
        --type scheme-tonal-spot \
        --config "$render_config" \
        --quiet

    outputs=(
        "$output_dir/colors.json"
        "$output_dir/btop.theme"
        "$output_dir/cava"
        "$output_dir/kitty.conf"
        "$output_dir/fcitx5.conf"
        "$output_dir/niri-colors.kdl"
        "$output_dir/yazi/theme.toml"
        "$output_dir/zsh-prompt-colors.zsh"
    )
    for output in "${outputs[@]}"; do
        [[ -s "$output" ]] || fail "missing rendered output: $output"
        if grep -Fq '{{' "$output" || grep -Fq '<*' "$output"; then
            fail "unrendered template expression in $output"
        fi
    done

    python3 -m json.tool "$output_dir/colors.json" >/dev/null
    python3 -c 'import pathlib, sys, tomllib; tomllib.loads(pathlib.Path(sys.argv[1]).read_text())' \
        "$output_dir/yazi/theme.toml"

    grep -Fq '"primary": "#' "$output_dir/colors.json" \
        || fail "Quickshell primary color is missing"
    grep -Fq 'theme[main_bg]=""' "$output_dir/btop.theme" \
        || fail "btop transparency was not preserved"
    grep -Fq "[color]" "$output_dir/cava" \
        || fail "Cava color section is missing"
    if grep -Eq '^\[(general|input|output|smoothing|eq)\]$' "$output_dir/cava"; then
        fail "Cava theme unexpectedly owns non-color configuration"
    fi
    grep -Fq "active_tab_background" "$output_dir/kitty.conf" \
        || fail "Kitty UI colors are missing"
    grep -Fq "Name=Matugen" "$output_dir/fcitx5.conf" \
        || fail "Fcitx5 metadata is missing"
    grep -Fq "active-gradient" "$output_dir/niri-colors.kdl" \
        || fail "Niri focus gradient is missing"
    if grep -Fq "background-color" "$output_dir/niri-colors.kdl" \
        || grep -Fq "backdrop-color" "$output_dir/niri-colors.kdl"; then
        fail "Niri generated colors must not make wallpaper surfaces opaque"
    fi
    grep -Fq '{ url = "*", is = "orphan"' "$output_dir/yazi/theme.toml" \
        || fail "Yazi special-file rules are not compatible with the current schema"
    grep -Fq "[icon]" "$output_dir/yazi/theme.toml" \
        || fail "Yazi icon theme is missing"

    zsh -fc '
        source "$1"
        for name in \
            CLAVIS_PROMPT_PATH_BG CLAVIS_PROMPT_PATH_FG \
            CLAVIS_PROMPT_GIT_BG CLAVIS_PROMPT_GIT_FG \
            CLAVIS_PROMPT_LANG_BG CLAVIS_PROMPT_LANG_FG \
            CLAVIS_PROMPT_TIME_BG CLAVIS_PROMPT_TIME_FG \
            CLAVIS_PROMPT_ERROR_BG CLAVIS_PROMPT_ERROR_FG \
            CLAVIS_PROMPT_CONNECTOR CLAVIS_PROMPT_ARROW; do
            value=${(P)name}
            [[ "$value" =~ "^#[[:xdigit:]]{6}$" ]] || exit 1
        done
    ' clavis-matugen-test "$output_dir/zsh-prompt-colors.zsh" \
        || fail "Zsh prompt palette is invalid"

    HOME="$test_home" YAZI_CONFIG_HOME="$output_dir/yazi" \
        yazi --debug >/dev/null \
        || fail "Yazi rejected the generated $render_mode theme"

    if command -v niri >/dev/null 2>&1; then
        printf 'include "%s"\n' "$output_dir/niri-colors.kdl" \
            > "$output_dir/niri-test.kdl"
        niri validate -c "$output_dir/niri-test.kdl" >/dev/null
    fi
done

printf '%s\n' "matugen template tests passed"
