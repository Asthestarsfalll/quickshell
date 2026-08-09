#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
scripts_dir=$(cd -- "$script_dir/.." && pwd)
# shellcheck source=scripts/lib/clavis-paths.sh
source "$scripts_dir/lib/clavis-paths.sh"
clavis_paths_init

share_root=$(cd -- "$scripts_dir/.." && pwd)
matugen_dir="$share_root/defaults/matugen"
if [[ ! -d "$matugen_dir/templates" ]]; then
    matugen_dir="$share_root/matugen"
fi
config_path="$matugen_dir/config.toml"
mode=dark
scheme=scheme-tonal-spot
image_path=""
source_color=""
dry_run=false
templates_requested=false
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
            templates_requested=true
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
if [[ ! -f "$config_path" ]]; then
    printf 'Missing matugen config: %s\n' "$config_path" >&2
    exit 1
fi

all_external_templates=(
    btop
    cava
    kitty
    niri
    yazi
)

selected_templates=(quickshell)
zsh_requested=false
keytop_requested=false
fcitx_requested=false
if [[ "$templates_requested" == false ]]; then
    selected_templates+=("${all_external_templates[@]}")
    zsh_requested=true
    keytop_requested=true
    fcitx_requested=true
elif [[ -n "$templates_csv" ]]; then
    IFS=',' read -r -a requested_templates <<< "$templates_csv"
    for template_id in "${requested_templates[@]}"; do
        case "$template_id" in
            btop|cava|kitty|niri|yazi)
                ;;
            zsh)
                zsh_requested=true
                continue
                ;;
            keytop)
                keytop_requested=true
                continue
                ;;
            fcitx5)
                fcitx_requested=true
                continue
                ;;
            *)
                printf 'Unknown matugen template: %s\n' "$template_id" >&2
                exit 2
                ;;
        esac
        already_selected=false
        for selected_id in "${selected_templates[@]}"; do
            if [[ "$selected_id" == "$template_id" ]]; then
                already_selected=true
                break
            fi
        done
        if [[ "$already_selected" == false ]]; then
            selected_templates+=("$template_id")
        fi
    done
fi

template_file() {
    case "$1" in
        quickshell) printf '%s\n' quickshell-colors.json ;;
        btop) printf '%s\n' btop.theme ;;
        cava) printf '%s\n' cava-colors.ini ;;
        kitty) printf '%s\n' kitty-colors.conf ;;
        niri) printf '%s\n' niri-colors.kdl ;;
        yazi) printf '%s\n' yazi-theme.toml ;;
    esac
}

for template_id in "${selected_templates[@]}"; do
    template_path="$matugen_dir/templates/$(template_file "$template_id")"
    [[ -f "$template_path" ]] || {
        printf 'Missing matugen template: %s\n' "$template_path" >&2
        exit 1
    }
done

CLAVIS_NIRI_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/niri"
if [[ "$dry_run" == false ]]; then
    mkdir -p "$CLAVIS_GENERATED_HOME/clavis"
    for template_id in "${selected_templates[@]}"; do
        case "$template_id" in
            btop) mkdir -p "$HOME/.config/btop/themes" ;;
            cava) mkdir -p "$HOME/.config/cava/themes" ;;
            kitty) mkdir -p "$HOME/.config/kitty/themes" ;;
            niri) mkdir -p "$CLAVIS_NIRI_HOME/clavis" ;;
            yazi) mkdir -p "$HOME/.config/yazi" ;;
        esac
    done
fi

enabled_sections=,
for template_id in "${selected_templates[@]}"; do
    enabled_sections+="$template_id,"
done

mkdir -p "$CLAVIS_RUNTIME_HOME/temporary"
runtime_dir=$(mktemp -d "$CLAVIS_RUNTIME_HOME/temporary/matugen.XXXXXX")
cleanup() {
    rm -rf -- "$runtime_dir"
}
trap cleanup EXIT HUP INT TERM
runtime_config="$runtime_dir/config.toml"

awk \
    -v enabled="$enabled_sections" \
    -v matugen_dir="$matugen_dir" \
    -v generated_home="$CLAVIS_GENERATED_HOME" \
    -v niri_home="$CLAVIS_NIRI_HOME" '
    /^\[templates\.[^]]+\]$/ {
        name = $0
        sub(/^\[templates\./, "", name)
        sub(/\]$/, "", name)
        emit = index(enabled, "," name ",") > 0
    }
    /^\[config\]$/ { emit = 1 }
    /^\[[^]]+\]$/ && $0 !~ /^\[templates\./ && $0 !~ /^\[config\]$/ {
        emit = 0
    }
    emit {
        line = $0
        if (line ~ /^input_path = "templates\//)
            sub(/^input_path = "/, "input_path = \"" matugen_dir "/", line)
        gsub(/@CLAVIS_GENERATED_HOME@/, generated_home, line)
        gsub(/@CLAVIS_NIRI_HOME@/, niri_home, line)
        print line
    }
' "$config_path" > "$runtime_config"

common_args=(--mode "$mode" --type "$scheme" --config "$runtime_config")
if [[ "$dry_run" == true ]]; then
    common_args+=(--dry-run)
fi

if [[ -n "$image_path" ]]; then
    matugen --source-color-index 0 image "$image_path" "${common_args[@]}"
else
    matugen color hex "$source_color" "${common_args[@]}"
fi

generate_external_colors() {
    local template_id=$1
    local config_dir template_path color_path color_temp target_config status
    external_colors_updated=false
    case "$template_id" in
        zsh) config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/clavis-zsh-theme" ;;
        keytop) config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/keytop" ;;
        fcitx5) config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/fcitx5-matugen-theme" ;;
        *) printf 'Unknown external color target: %s\n' "$template_id" >&2; return 2 ;;
    esac
    template_path="$config_dir/matugen.conf"
    color_path="$config_dir/colors.conf"
    if [[ ! -f "$template_path" ]]; then
        printf 'Warning: %s target is not installed; skipped (%s is missing).\n' \
            "$template_id" "$template_path" >&2
        return 0
    fi
    if [[ "$dry_run" == true ]]; then
        printf 'Dry run: would generate %s/colors.conf from %s.\n' "$template_id" "$template_path"
        return 0
    fi

    mkdir -p "$config_dir"
    color_temp=$(mktemp "${color_path}.XXXXXX")
    target_config=$(mktemp "$runtime_dir/${template_id}.config.XXXXXX")
    printf '[config]\nversion_check = false\n\n[templates.%s]\ninput_path = "%s"\noutput_path = "%s"\n' \
        "$template_id" "$template_path" "$color_temp" > "$target_config"
    status=0
    if [[ -n "$image_path" ]]; then
        matugen --source-color-index 0 image "$image_path" \
            --mode "$mode" --type "$scheme" --config "$target_config" --quiet \
            || status=$?
    else
        matugen color hex "$source_color" --mode "$mode" --type "$scheme" \
            --config "$target_config" --quiet || status=$?
    fi
    if (( status == 0 )) && [[ -s "$color_temp" ]]; then
        mv -f -- "$color_temp" "$color_path"
        external_colors_updated=true
        printf 'Updated %s\n' "$color_path"
        return 0
    fi
    rm -f -- "$color_temp"
    printf 'Warning: Matugen failed for %s; preserving its previous colors.conf.\n' \
        "$template_id" >&2
    return 1
}

if [[ "$zsh_requested" == true ]]; then
    if ! generate_external_colors zsh; then
        printf 'Warning: Zsh Prompt color generation failed; other targets continue.\n' >&2
    fi
fi

if [[ "$keytop_requested" == true && "$dry_run" == false ]]; then
    if generate_external_colors keytop; then
        if [[ "$external_colors_updated" == true ]]; then
            keytop_reload=${CLAVIS_KEYTOP_RELOAD_COMMAND:-keytop}
            if command -v "$keytop_reload" >/dev/null 2>&1; then
                "$keytop_reload" reload >/dev/null \
                    || printf 'Warning: Keytop color reload failed; existing TUI continues.\n' >&2
            else
                printf 'Warning: Keytop reload command is unavailable (%s).\n' \
                    "$keytop_reload" >&2
            fi
        fi
    else
        printf 'Warning: Keytop color generation failed; other targets continue.\n' >&2
    fi
fi

if [[ "$fcitx_requested" == true ]]; then
    if generate_external_colors fcitx5; then
        if [[ "$dry_run" == false && "$external_colors_updated" == true ]]; then
            fcitx_provider=${CLAVIS_FCITX5_THEME_COMMAND:-fcitx5-theme}
            if command -v "$fcitx_provider" >/dev/null 2>&1; then
                if ! "$fcitx_provider" apply; then
                    printf 'Warning: Fcitx5 theme apply failed; preserving its previous complete theme.\n' >&2
                fi
            else
                printf 'Warning: Fcitx5 theme provider is unavailable (%s); preserving its previous theme.\n' \
                    "$fcitx_provider" >&2
            fi
        fi
    else
        printf 'Warning: Fcitx5 color generation failed; other targets continue.\n' >&2
    fi
fi
