#!/usr/bin/env bash

set -euo pipefail

script_dir=$(
    CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
)
repo_root=$(
    CDPATH='' cd -- "${script_dir}/../.." && pwd
)
build_root=${CLAVIS_BUILD_DIR:-${repo_root}/build}

printf '%s\n' 'Clavis quality checks'

git -C "${repo_root}" diff --check
"${repo_root}/scripts/dev/format-qml.sh" --check

command -v clang-format >/dev/null 2>&1 || {
    printf 'error: clang-format is required\n' >&2
    exit 127
}
mapfile -d '' -t cpp_files < <(
    find "${repo_root}/core" \
        -path "${repo_root}/core/src/m3shapes" -prune \
        -o -path "${repo_root}/core/plugin/m3shapes/src" -prune \
        -o -type f \( -name '*.cpp' -o -name '*.h' -o -name '*.hpp' \) -print0 \
        | sort -z
)
if [[ ${#cpp_files[@]} -gt 0 ]]; then
    clang-format --dry-run --Werror "${cpp_files[@]}"
fi

mapfile -d '' -t shell_files < <(
    find "${repo_root}/scripts" "${repo_root}/tests" \
        -type f -name '*.sh' -print0 | sort -z
)
for file in "${shell_files[@]}"; do
    bash -n "${file}"
done
if [[ ${#shell_files[@]} -gt 0 ]]; then
    command -v shellcheck >/dev/null 2>&1 || {
        printf 'error: shellcheck is required to check shell scripts\n' >&2
        exit 127
    }
    shellcheck "${shell_files[@]}"
fi

if find "${repo_root}/scripts" "${repo_root}/tests" -type f -name '*.py' \
    -print -quit | grep -q .; then
    python3 -m compileall -q "${repo_root}/scripts" "${repo_root}/tests"
fi

cmake -S "${repo_root}" -B "${build_root}" -G Ninja \
    -DCMAKE_BUILD_TYPE="${CLAVIS_BUILD_TYPE:-Debug}"
cmake --build "${build_root}"
"${repo_root}/scripts/dev/lint-qml.sh"
ctest --test-dir "${build_root}" --output-on-failure

git -C "${repo_root}" diff --check
printf '%s\n' 'Clavis quality checks passed'
