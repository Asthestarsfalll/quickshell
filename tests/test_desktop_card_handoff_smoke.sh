#!/bin/sh

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_file=$(mktemp)
trap 'rm -f "$output_file"' EXIT INT TERM

qs -p "$repo_dir/smoke_desktop_card_handoff.qml" \
    >"$output_file" 2>&1
cat "$output_file"

grep -Fq -- "DESKTOP_CARD_HANDOFF_SMOKE_PASS" "$output_file" \
    || {
        echo "FAIL: Desktop Card handoff smoke did not pass" >&2
        exit 1
    }
