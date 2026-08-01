#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
scripts_dir=$(cd -- "$script_dir/.." && pwd)
# shellcheck source=scripts/lib/clavis-paths.sh
source "$scripts_dir/lib/clavis-paths.sh"
clavis_paths_init

share_root=$(cd -- "$scripts_dir/.." && pwd)
if [[ -f "$share_root/libexec/matugen_config.py" ]]; then
    config_helper=$share_root/libexec/matugen_config.py
elif [[ -f "$share_root/packaging/matugen_config.py" ]]; then
    config_helper=$share_root/packaging/matugen_config.py
else
    printf 'Clavis Matugen config helper is missing below %s\n' "$share_root" >&2
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

mkdir -p "$CLAVIS_RUNTIME_HOME/temporary"
runtime_dir=$(mktemp -d "$CLAVIS_RUNTIME_HOME/temporary/matugen.XXXXXX")
cleanup() {
    rm -rf -- "$runtime_dir"
}
trap cleanup EXIT HUP INT TERM
runtime_config=$runtime_dir/config.toml
helper_args=(
    --share-root "$share_root"
    --config "$CLAVIS_PROFILE_CONFIG_HOME/matugen/config.toml"
    --generated-home "$CLAVIS_GENERATED_HOME"
    --runtime-config "$runtime_config"
    --templates "$templates_csv"
)
if [[ "$dry_run" == true ]]; then
    helper_args+=(--dry-run)
fi
python3 "$config_helper" "${helper_args[@]}" >/dev/null

common_args=(--mode "$mode" --type "$scheme" --config "$runtime_config")
if [[ "$dry_run" == true ]]; then
    common_args+=(--dry-run)
fi

if [[ -n "$image_path" ]]; then
    matugen --source-color-index 0 image "$image_path" "${common_args[@]}"
else
    matugen color hex "$source_color" "${common_args[@]}"
fi
