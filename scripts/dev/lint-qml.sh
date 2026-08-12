#!/usr/bin/env bash

set -euo pipefail

script_dir=$(
    CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
)
repo_root=$(
    CDPATH='' cd -- "${script_dir}/../.." && pwd
)
build_root=${CLAVIS_BUILD_DIR:-${repo_root}/build}
qml_build_dir=${CLAVIS_QML_BUILD_DIR:-${build_root}/qml}
qmlls_config=${repo_root}/.qmlls.ini
tooling_timeout=${CLAVIS_QML_TOOLING_TIMEOUT:-5}

command -v qs >/dev/null 2>&1 || {
    printf 'error: Quickshell qs is required to generate QML tooling data\n' >&2
    exit 127
}
command -v cmake >/dev/null 2>&1 || {
    printf 'error: cmake is required when the native QML build is missing\n' >&2
    exit 127
}

resolve_qmllint() {
    if [[ -n "${QMLLINT:-}" ]]; then
        printf '%s\n' "${QMLLINT}"
        return 0
    fi

    local candidate
    for candidate in /usr/lib/qt6/bin/qmllint qmllint6 qmllint-qt6 qmllint; do
        if [[ "${candidate}" == /* && -x "${candidate}" ]] \
            || command -v "${candidate}" >/dev/null 2>&1; then
            printf '%s\n' "${candidate}"
            return 0
        fi
    done
    return 1
}

if ! qmllint_bin=$(resolve_qmllint); then
    printf 'error: qmllint is required (set QMLLINT to a Qt 6 qmllint binary)\n' >&2
    exit 127
fi
qmllint_version=$("${qmllint_bin}" --version 2>/dev/null || true)
if [[ "${qmllint_version}" != *" 6."* ]]; then
    printf 'error: Qt 6 qmllint is required; found %s\n' "${qmllint_version:-unknown}" >&2
    exit 1
fi

native_build_ready() {
    [[ -f "${qml_build_dir}/Clavis/Weather/qmldir" ]] \
        && [[ -f "${qml_build_dir}/Clavis/Lyrics/qmldir" ]] \
        && [[ -f "${qml_build_dir}/M3Shapes/qmldir" ]]
}

if ! native_build_ready; then
    printf 'lint-qml: native QML modules are missing; configuring and building %s\n' \
        "${build_root}"
    cmake -S "${repo_root}" -B "${build_root}" -G Ninja \
        -DCMAKE_BUILD_TYPE="${CLAVIS_BUILD_TYPE:-Debug}"
    cmake --build "${build_root}"
fi

read_ini_value() {
    local key=$1
    local value
    value=$(awk -F= -v wanted="${key}" '
        $1 == wanted {
            sub(/^[^=]*=/, "")
            if ($0 ~ /^".*"$/) {
                sub(/^"/, "")
                sub(/"$/, "")
            }
            print
            exit
        }
    ' "${qmlls_config}" 2>/dev/null || true)
    [[ -n "${value}" ]] || return 1
    printf '%s\n' "${value}"
}

tooling_config_valid() {
    [[ -e "${qmlls_config}" ]] || return 1
    [[ -f "${qmlls_config}" ]] || return 1
    local tooling_build_dir
    local import_paths
    tooling_build_dir=$(read_ini_value buildDir) || return 1
    import_paths=$(read_ini_value importPaths) || return 1
    [[ -n "${tooling_build_dir}" ]] || return 1
    [[ -d "${tooling_build_dir}" ]] || return 1
    [[ -f "${tooling_build_dir}/qs/qmldir" ]] || return 1
    [[ -n "${import_paths}" ]] || return 1
}

refresh_tooling() {
    local log_file
    local qs_status
    log_file=$(mktemp "${TMPDIR:-/tmp}/clavis-qmlls.XXXXXX.log")

    if [[ -L "${qmlls_config}" && ! -e "${qmlls_config}" ]]; then
        rm -f -- "${qmlls_config}"
    fi
    # Quickshell replaces this ignored placeholder with its tooling VFS link.
    touch "${qmlls_config}"

    set +e
    QT_QPA_PLATFORM="${CLAVIS_QML_TOOLING_PLATFORM:-offscreen}" \
    QML2_IMPORT_PATH="${qml_build_dir}${QML2_IMPORT_PATH:+:${QML2_IMPORT_PATH}}" \
    QML_IMPORT_PATH="${qml_build_dir}${QML_IMPORT_PATH:+:${QML_IMPORT_PATH}}" \
        timeout --signal=TERM "${tooling_timeout}s" qs -p "${repo_root}" -n \
        >"${log_file}" 2>&1
    qs_status=$?
    set -e

    if ! tooling_config_valid; then
        printf 'error: Quickshell did not produce a valid %s\n' "${qmlls_config}" >&2
        printf 'Quickshell output:\n' >&2
        sed -n '1,240p' "${log_file}" >&2
        rm -f -- "${log_file}"
        printf 'Try running qs -p %q in a graphical session, then rerun this script.\n' \
            "${repo_root}" >&2
        return 1
    fi

    if [[ ${qs_status} -ne 0 ]]; then
        printf 'lint-qml: qs exited %d after writing a valid tooling VFS\n' \
            "${qs_status}" >&2
    fi
    rm -f -- "${log_file}"
}

if ! tooling_config_valid \
    || [[ -f "${build_root}/CMakeCache.txt" && "${qmlls_config}" -ot "${build_root}/CMakeCache.txt" ]]; then
    printf 'lint-qml: creating or refreshing Quickshell tooling data\n'
    refresh_tooling
fi

tooling_build_dir=$(read_ini_value buildDir)
import_paths_raw=$(read_ini_value importPaths)
if [[ ! -d "${tooling_build_dir}" || ! -f "${tooling_build_dir}/qs/qmldir" ]]; then
    printf 'error: tooling VFS is stale: %s\n' "${tooling_build_dir}" >&2
    exit 1
fi

qml_import_args=(
    --max-warnings -1
    -I "${repo_root}"
    -I "${tooling_build_dir}"
    -I "${qml_build_dir}"
)
IFS=':' read -r -a import_paths <<< "${import_paths_raw}"
for path in "${import_paths[@]}"; do
    [[ -n "${path}" ]] && qml_import_args+=(-I "${path}")
done

mapfile -d '' -t qml_files < <(
    find "${repo_root}" \
        \( -path "${repo_root}/build" \
        -o -path "${repo_root}/generated" \
        -o -path "${repo_root}/third-party" \
        -o -path "${repo_root}/vendor" \) -prune \
        -o -type f -name '*.qml' -print0 \
        | sort -z
)

if [[ ${#qml_files[@]} -eq 0 ]]; then
    printf 'lint-qml: no QML files found\n'
    exit 0
fi

printf 'lint-qml: checking %d first-party QML files\n' "${#qml_files[@]}"
"${qmllint_bin}" "${qml_import_args[@]}" "${qml_files[@]}"
printf 'lint-qml: passed\n'
