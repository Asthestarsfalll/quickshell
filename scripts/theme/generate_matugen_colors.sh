#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
config_path="$repo_root/matugen/config.toml"
mode="dark"
scheme="scheme-tonal-spot"
image_path=""
source_color=""
dry_run=false

usage() {
    printf 'Usage: %s (--image PATH | --color HEX) [--mode dark|light] [--scheme SCHEME] [--dry-run]\n' "$0" >&2
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --image)
            image_path="${2:-}"
            shift 2
            ;;
        --color)
            source_color="${2:-}"
            shift 2
            ;;
        --mode)
            mode="${2:-}"
            shift 2
            ;;
        --scheme)
            scheme="${2:-}"
            shift 2
            ;;
        --dry-run)
            dry_run=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage
            exit 2
            ;;
    esac
done

if [[ -n "$image_path" && -n "$source_color" ]] || [[ -z "$image_path" && -z "$source_color" ]]; then
    usage
    exit 2
fi

if [[ "$mode" != "dark" && "$mode" != "light" ]]; then
    usage
    exit 2
fi

if ! command -v matugen >/dev/null 2>&1; then
    printf 'matugen is required but was not found in PATH\n' >&2
    exit 1
fi

if [[ ! -f "$config_path" ]]; then
    printf 'Missing matugen config: %s\n' "$config_path" >&2
    exit 1
fi

required_templates=(
    quickshell-colors.json
    btop.theme
    cava-colors.ini
    kitty-colors.conf
    fcitx5-theme.conf
    niri-colors.kdl
    yazi-theme.toml
    zsh-prompt-colors.zsh
)
for template_name in "${required_templates[@]}"; do
    template_path="$repo_root/matugen/templates/$template_name"
    if [[ ! -f "$template_path" ]]; then
        printf 'Missing matugen template: %s\n' "$template_path" >&2
        exit 1
    fi
done

mkdir -p \
    "$HOME/.cache/quickshell-dev-colorscheme" \
    "$HOME/.config/btop/themes" \
    "$HOME/.config/cava/themes" \
    "$HOME/.config/kitty/themes" \
    "$HOME/.local/share/fcitx5/themes/Matugen" \
    "$HOME/.config/niri" \
    "$HOME/.config/yazi"

common_args=(
    --mode "$mode"
    --type "$scheme"
    --config "$config_path"
)
if [[ "$dry_run" == true ]]; then
    common_args+=(--dry-run)
fi

if [[ -n "$image_path" ]]; then
    matugen --source-color-index 0 image "$image_path" "${common_args[@]}"
else
    matugen color hex "$source_color" "${common_args[@]}"
fi
