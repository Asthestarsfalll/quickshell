#!/usr/bin/env bash

set -euo pipefail

script_dir=$(
    CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
)
repo_root=$(
    CDPATH='' cd -- "${script_dir}/../.." && pwd
)

mode=format
scope=changed
case "${1:-}" in
    '') ;;
    --check) mode=check ;;
    --all) scope=all ;;
    --check-all) mode=check; scope=all ;;
    -h|--help)
        printf 'Usage: %s [--check|--all|--check-all]\n' "${BASH_SOURCE[0]}"
        exit 0
        ;;
    *)
        printf 'error: unknown option: %s\n' "$1" >&2
        exit 2
        ;;
esac

if [[ $# -gt 1 ]]; then
    printf 'error: expected at most one option\n' >&2
    exit 2
fi

command -v qmlformat >/dev/null 2>&1 || {
    printf 'error: qmlformat is required\n' >&2
    exit 127
}

mapfile -d '' -t all_qml_files < <(
    find "${repo_root}" \
        \( -path "${repo_root}/build" \
        -o -path "${repo_root}/generated" \
        -o -path "${repo_root}/third-party" \
        -o -path "${repo_root}/vendor" \) -prune \
        -o -type f -name '*.qml' -print0 \
        | sort -z
)

if [[ "${scope}" == all ]]; then
    qml_files=("${all_qml_files[@]}")
else
    mapfile -d '' -t qml_files < <(
        {
            git -C "${repo_root}" diff --name-only -z HEAD -- '*.qml'
            git -C "${repo_root}" ls-files --others --exclude-standard -z -- '*.qml'
        } | sort -zu | while IFS= read -r -d '' relative; do
            file="${repo_root}/${relative}"
            [[ -f "${file}" ]] && printf '%s\0' "${file}"
        done
    )
fi

if [[ ${#qml_files[@]} -eq 0 ]]; then
    printf 'format-qml: no changed QML files (use --all to format the tree)\n'
else
    if [[ "${mode}" == format ]]; then
        for file in "${qml_files[@]}"; do
            qmlformat --no-sort --inplace "${file}"
        done
        printf 'format-qml: formatted %d changed files\n' "${#qml_files[@]}"
    fi
fi

if [[ "${mode}" == format ]]; then
    exit 0
fi

if rg -n --no-heading --fixed-strings $'\t' "${all_qml_files[@]}"; then
    printf 'error: QML files contain tabs; use four spaces\n' >&2
    exit 1
fi
if rg -n --no-heading $'\r$' "${all_qml_files[@]}"; then
    printf 'error: QML files contain CRLF line endings; use Unix newlines\n' >&2
    exit 1
fi

temporary_dir=$(mktemp -d "${TMPDIR:-/tmp}/clavis-qmlformat.XXXXXX")
cleanup() {
    rm -rf -- "${temporary_dir}"
}
trap cleanup EXIT HUP INT TERM

failed=0
for file in "${qml_files[@]}"; do
    relative=${file#"${repo_root}/"}
    expected="${temporary_dir}/${relative}"
    mkdir -p -- "$(dirname -- "${expected}")"
    if ! qmlformat --no-sort "${file}" >"${expected}"; then
        printf 'format-qml: unable to format %s\n' "${relative}" >&2
        failed=1
        continue
    fi
    if ! cmp -s -- "${file}" "${expected}"; then
        printf 'format-qml: not formatted: %s\n' "${relative}" >&2
        diff -u -- "${file}" "${expected}" | sed -n '1,100p' || true
        failed=1
    fi
done

if [[ ${failed} -ne 0 ]]; then
    exit 1
fi
printf 'format-qml: check passed (%d files)\n' "${#qml_files[@]}"
