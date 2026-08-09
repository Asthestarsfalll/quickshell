#!/bin/sh

set -eu

mode=${1:-}
main_config=${2:-}
fragment_path=${3:-}
niri_command=${4:-niri}
label=${5:-CLAVIS}

if [ "$mode" != "configure" ] || [ -z "$main_config" ] || [ -z "$fragment_path" ]; then
    echo "usage: manage-niri-fragment.sh configure <main-config> <fragment> [niri] [label]" >&2
    exit 2
fi

if [ ! -f "$main_config" ]; then
    echo "niri config not found: $main_config" >&2
    exit 3
fi

main_dir=$(dirname -- "$main_config")
fragment_dir=$(dirname -- "$fragment_path")
mkdir -p -- "$fragment_dir"

# The fragment is intentionally referenced relative to the user's main config.
# -m also works before the generated fragment exists.
fragment_include=$(realpath -m --relative-to="$main_dir" "$fragment_path")
escaped_include=$(printf '%s' "$fragment_include" \
    | sed 's/\\/\\\\/g; s/"/\\"/g')
optional_include="include optional=true \"$escaped_include\""
plain_include="include \"$escaped_include\""
main_tmp=

cleanup() {
    if [ -n "$main_tmp" ]; then
        rm -f -- "$main_tmp"
    fi
}
trap cleanup EXIT HUP INT TERM

# Validate the user's current file even when the include is already present.
# This keeps a broken main config from being silently treated as a successful
# integration and prevents a cursor update from masking that failure.
"$niri_command" validate -c "$main_config" >/dev/null

if grep -Fq -- "$optional_include" "$main_config" \
    || grep -Fq -- "$plain_include" "$main_config"; then
    trap - EXIT HUP INT TERM
    echo "configured"
    exit 0
fi

main_tmp=$(mktemp "$main_dir/.config.kdl.clavis.XXXXXX")
cp -p -- "$main_config" "$main_tmp"
{
    echo
    echo "// BEGIN CLAVIS $label"
    echo "$optional_include"
    echo "// END CLAVIS $label"
} >> "$main_tmp"

"$niri_command" validate -c "$main_tmp" >/dev/null

backup_path="$main_config.clavis-backup"
if [ ! -e "$backup_path" ]; then
    cp -p -- "$main_config" "$backup_path"
fi

mv -f -- "$main_tmp" "$main_config"
main_tmp=
trap - EXIT HUP INT TERM
echo "configured"
