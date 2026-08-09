#!/usr/bin/env bash

set -euo pipefail

cursor_path="${1:?missing cursor configuration path}"
main_config="${2:?missing niri main configuration path}"
theme_name="${3-}"
size="${4:?missing cursor size}"
hide_when_typing="${5:?missing hide-when-typing value}"
hide_after_ms="${6:?missing hide-after-inactive value}"
niri_command="${7:-niri}"

die() {
    printf '%s\n' "$1" >&2
    exit 2
}

if [[ ! "$size" =~ ^[0-9]+$ ]] || (( size < 12 || size > 128 )); then
    die "invalid cursor size: $size"
fi

if [[ "$hide_when_typing" != true && "$hide_when_typing" != false ]]; then
    die "invalid hide-when-typing value: $hide_when_typing"
fi

if [[ ! "$hide_after_ms" =~ ^[0-9]+$ ]] \
    || (( hide_after_ms < 0 || hide_after_ms > 5000 )); then
    die "invalid hide-after-inactive value: $hide_after_ms"
fi

# Cursor theme names normally come from an icon directory, but the persisted
# config is user-controlled. Reject control characters and escape the KDL
# string rather than allowing config data to become KDL syntax.
if [[ "$theme_name" == *$'\n'* || "$theme_name" == *$'\r'* \
    || "$theme_name" == *$'\t'* ]]; then
    die "invalid cursor theme name"
fi

escape_kdl_string() {
    local value="$1"
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    printf '%s' "$value"
}

cursor_dir=$(dirname -- "$cursor_path")
mkdir -p -- "$cursor_dir"
cursor_tmp=$(mktemp "$cursor_dir/.cursor.kdl.XXXXXX")
main_tmp=
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

cleanup() {
    rm -f -- "$cursor_tmp"
    if [[ -n "$main_tmp" ]]; then
        rm -f -- "$main_tmp"
    fi
}
trap cleanup EXIT HUP INT TERM

{
    printf '%s\n' \
        '// Managed by Clavis. Manual edits will be replaced.' \
        '// This file is included from the user-owned Niri config.'

    if [[ -n "$theme_name" || "$size" != 24 \
        || "$hide_when_typing" == true || "$hide_after_ms" != 0 ]]; then
        printf '\ncursor {\n'
        if [[ -n "$theme_name" ]]; then
            printf '    xcursor-theme "%s"\n' "$(escape_kdl_string "$theme_name")"
        fi
        printf '    xcursor-size %s\n' "$size"
        if [[ "$hide_when_typing" == true ]]; then
            printf '    hide-when-typing\n'
        fi
        if (( hide_after_ms > 0 )); then
            printf '    hide-after-inactive-ms %s\n' "$hide_after_ms"
        fi
        printf '}\n'
    fi
} > "$cursor_tmp"

# Validate the generated fragment before touching the previous known-good
# cursor.kdl. The shared manager validates the user's main config and adds an
# include exactly once when needed.
"$niri_command" validate -c "$cursor_tmp" >/dev/null
"$script_dir/../system/manage-niri-fragment.sh" \
    configure "$main_config" "$cursor_path" "$niri_command" "CURSOR"

chmod 600 "$cursor_tmp"
mv -f -- "$cursor_tmp" "$cursor_path"

# Niri consumes the include on a config reload. A failed reload is reported to
# ThemeService even though the validated fragment remains safely installed.
"$niri_command" msg action load-config-file >/dev/null

trap - EXIT HUP INT TERM
echo "ready"
