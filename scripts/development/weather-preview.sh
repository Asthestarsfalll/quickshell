#!/usr/bin/env bash

set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/../.." && pwd)
preview_home=$(mktemp -d /tmp/clavis-weather-preview.XXXXXX)

cleanup() {
    rm -rf -- "$preview_home"
}
trap cleanup EXIT HUP INT TERM

# Keep every writable Clavis/XDG namespace away from the user's real config.
export XDG_CONFIG_HOME="$preview_home/config"
export XDG_DATA_HOME="$preview_home/data"
export XDG_STATE_HOME="$preview_home/state"
export XDG_CACHE_HOME="$preview_home/cache"
export CLAVIS_CONFIG_HOME="$preview_home/config/clavis"
export CLAVIS_DATA_HOME="$preview_home/data/clavis"
export CLAVIS_STATE_HOME="$preview_home/state/clavis"
export CLAVIS_CACHE_HOME="$preview_home/cache/clavis"
export CLAVIS_RUNTIME_HOME="$preview_home/runtime/clavis"
export CLAVIS_PROFILE=weather-preview
export CLAVIS_PROFILE_CONFIG_HOME="$CLAVIS_CONFIG_HOME/profiles/$CLAVIS_PROFILE"
export CLAVIS_PROFILE_HOME="$CLAVIS_DATA_HOME/profiles/$CLAVIS_PROFILE"
export CLAVIS_GENERATED_HOME="$CLAVIS_PROFILE_HOME/generated"
export CLAVIS_RUNTIME_MODE=development
export CLAVIS_SOURCE_ROOT="$repo_dir"

mkdir -p -- \
    "$CLAVIS_CONFIG_HOME" \
    "$CLAVIS_GENERATED_HOME/clavis" \
    "$CLAVIS_GENERATED_HOME/niri"
printf '{}\n' > "$CLAVIS_CONFIG_HOME/config.json"
printf '{}\n' > "$CLAVIS_CONFIG_HOME/ui-preferences.json"
printf '{}\n' > "$CLAVIS_GENERATED_HOME/clavis/colors.json"
: > "$CLAVIS_GENERATED_HOME/niri/session.kdl"

qml_import_home=${CLAVIS_QML_IMPORT_HOME:-$HOME/.local/lib/clavis/current/lib/qml}
if [[ ! -d "$qml_import_home" ]]; then
    printf 'Clavis QML plugin directory not found: %s\n' "$qml_import_home" >&2
    printf 'Build/install a current release or set CLAVIS_QML_IMPORT_HOME.\n' >&2
    exit 1
fi
export CLAVIS_QML_IMPORT_HOME="$qml_import_home"
export QML_IMPORT_PATH="$qml_import_home${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
export QML2_IMPORT_PATH="$qml_import_home${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"

qs -p "$repo_dir/weather-preview.qml"
