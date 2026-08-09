#!/usr/bin/env bash

set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
shell_unit="$repo_dir/packaging/systemd/user/clavis-shell.service"
clipboard_unit="$repo_dir/packaging/systemd/user/clavis-clipboard.service"
core_cmake="$repo_dir/core/CMakeLists.txt"

fail() {
    printf 'systemd architecture test: %s\n' "$1" >&2
    exit 1
}

test -f "$shell_unit" || fail "missing Clavis shell unit"
test ! -e "$clipboard_unit" || fail "clipboard unit still belongs to Clavis"
grep -Fq 'CLAVIS_SYSTEMD_USER_INSTALL_DIR' "$repo_dir/CMakeLists.txt" \
    || fail "systemd install destination is not configurable"
grep -Fq 'clavis-shell.service' "$core_cmake" \
    || fail "CMake does not install the shell unit"
grep -Fq 'DESTINATION "${CLAVIS_SYSTEMD_USER_INSTALL_DIR}"' "$core_cmake" \
    || fail "CMake still uses the old shared-data unit destination"
grep -Fq 'Requisite=niri.service' "$shell_unit" \
    || fail "shell unit is not bound to niri"
grep -Fq 'PartOf=niri.service' "$shell_unit" \
    || fail "shell unit does not stop with niri"
grep -Fq 'WantedBy=niri.service' "$shell_unit" \
    || fail "shell unit is not enabled from niri"
grep -Fq 'ExecStart=key shell' "$shell_unit" \
    || fail "shell unit does not use key-cli"
