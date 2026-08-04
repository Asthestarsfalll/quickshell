#!/usr/bin/env bash
set -euo pipefail

[[ ${1:-} == apply ]] || exit 2
: "${CLAVIS_FCITX5_TEST_LOG:?CLAVIS_FCITX5_TEST_LOG is required}"
printf '%s\n' "$*" >> "$CLAVIS_FCITX5_TEST_LOG"
