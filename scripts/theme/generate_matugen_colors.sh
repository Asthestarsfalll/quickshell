#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
scripts_dir=$(cd -- "$script_dir/.." && pwd)
# shellcheck source=scripts/lib/clavis-paths.sh
source "$scripts_dir/lib/clavis-paths.sh"
clavis_paths_init

share_root=$(cd -- "$scripts_dir/.." && pwd)
if [[ -d "$share_root/defaults/matugen/templates" ]]; then
    template_dir=$share_root/defaults/matugen/templates
elif [[ -d "$share_root/matugen/templates" ]]; then
    template_dir=$share_root/matugen/templates
else
    printf 'Clavis Matugen templates are missing below %s\n' "$share_root" >&2
    exit 1
fi

mode=dark
scheme=scheme-tonal-spot
image_path=""
source_color=""
dry_run=false
templates_csv=""

usage() {
    printf 'Usage: %s (--image PATH | --color HEX) [--mode dark|light] [--scheme SCHEME] [--templates ID,...] [--dry-run]\n' "$0" >&2
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --image)
            [[ $# -ge 2 ]] || { usage; exit 2; }
            image_path=$2
            shift 2
            ;;
        --color)
            [[ $# -ge 2 ]] || { usage; exit 2; }
            source_color=$2
            shift 2
            ;;
        --mode)
            [[ $# -ge 2 ]] || { usage; exit 2; }
            mode=$2
            shift 2
            ;;
        --scheme)
            [[ $# -ge 2 ]] || { usage; exit 2; }
            scheme=$2
            shift 2
            ;;
        --templates)
            [[ $# -ge 2 ]] || { usage; exit 2; }
            templates_csv=$2
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

if [[ -n "$image_path" && -n "$source_color" ]] \
    || [[ -z "$image_path" && -z "$source_color" ]]; then
    usage
    exit 2
fi
if [[ "$mode" != dark && "$mode" != light ]]; then
    usage
    exit 2
fi
if ! command -v matugen >/dev/null 2>&1; then
    printf 'matugen is required but was not found in PATH\n' >&2
    exit 1
fi

template_file() {
    case "$1" in
        quickshell) printf '%s\n' quickshell-colors.json ;;
        btop) printf '%s\n' btop.theme ;;
        cava) printf '%s\n' cava-colors.ini ;;
        kitty) printf '%s\n' kitty-colors.conf ;;
        fcitx5) printf '%s\n' fcitx5-theme.conf ;;
        fcitx5_panel_svg) printf '%s\n' fcitx5-panel.svg ;;
        fcitx5_highlight_svg) printf '%s\n' fcitx5-highlight.svg ;;
        niri) printf '%s\n' niri-colors.kdl ;;
        yazi) printf '%s\n' yazi-theme.toml ;;
        zsh_prompt) printf '%s\n' zsh-prompt-colors.zsh ;;
        *) return 1 ;;
    esac
}

output_path() {
    case "$1" in
        quickshell) printf '%s\n' "$CLAVIS_GENERATED_HOME/clavis/colors.json" ;;
        btop) printf '%s\n' "$CLAVIS_GENERATED_HOME/btop/themes/clavis.theme" ;;
        cava) printf '%s\n' "$CLAVIS_GENERATED_HOME/cava/colors.ini" ;;
        kitty) printf '%s\n' "$CLAVIS_GENERATED_HOME/kitty/colors.conf" ;;
        fcitx5) printf '%s\n' "$CLAVIS_GENERATED_HOME/fcitx5/Matugen/theme.conf" ;;
        fcitx5_panel_svg) printf '%s\n' "$CLAVIS_GENERATED_HOME/fcitx5/Matugen/panel.svg" ;;
        fcitx5_highlight_svg) printf '%s\n' "$CLAVIS_GENERATED_HOME/fcitx5/Matugen/highlight.svg" ;;
        niri) printf '%s\n' "$CLAVIS_GENERATED_HOME/niri/colors.kdl" ;;
        yazi) printf '%s\n' "$CLAVIS_GENERATED_HOME/yazi/theme.toml" ;;
        zsh_prompt) printf '%s\n' "$CLAVIS_GENERATED_HOME/zsh/prompt-colors.zsh" ;;
        *) return 1 ;;
    esac
}

selected_templates=(quickshell)
if [[ -n "$templates_csv" ]]; then
    IFS=',' read -r -a requested_templates <<< "$templates_csv"
    for template_id in "${requested_templates[@]}"; do
        if ! template_file "$template_id" >/dev/null; then
            printf 'Unknown Matugen profile template: %s\n' "$template_id" >&2
            exit 2
        fi
        duplicate=false
        for selected in "${selected_templates[@]}"; do
            if [[ "$selected" == "$template_id" ]]; then
                duplicate=true
                break
            fi
        done
        if [[ "$duplicate" == false ]]; then
            selected_templates+=("$template_id")
        fi
    done
fi

toml_escape() {
    local value=$1
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    printf '%s' "$value"
}

mkdir -p "$CLAVIS_RUNTIME_HOME/temporary"
runtime_dir=$(mktemp -d "$CLAVIS_RUNTIME_HOME/temporary/matugen.XXXXXX")
cleanup() {
    rm -rf -- "$runtime_dir"
}
trap cleanup EXIT HUP INT TERM
runtime_config=$runtime_dir/config.toml

printf '[config]\nversion_check = false\n' > "$runtime_config"
for template_id in "${selected_templates[@]}"; do
    template_name=$(template_file "$template_id")
    input=$template_dir/$template_name
    output=$(output_path "$template_id")
    if [[ ! -f "$input" ]]; then
        printf 'Missing Matugen template: %s\n' "$input" >&2
        exit 1
    fi
    if [[ "$dry_run" == false ]]; then
        mkdir -p "$(dirname -- "$output")"
    fi
    {
        printf '\n[templates.%s]\n' "$template_id"
        printf 'input_path = "%s"\n' "$(toml_escape "$input")"
        printf 'output_path = "%s"\n' "$(toml_escape "$output")"
    } >> "$runtime_config"
done

common_args=(--mode "$mode" --type "$scheme" --config "$runtime_config")
if [[ "$dry_run" == true ]]; then
    common_args+=(--dry-run)
fi

if [[ -n "$image_path" ]]; then
    matugen --source-color-index 0 image "$image_path" "${common_args[@]}"
else
    matugen color hex "$source_color" "${common_args[@]}"
fi
