#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
project_dir=$(cd -- "${script_dir}/.." && pwd)

shader_consumers=(
    "Modules/Keystone/Styles/Recording/PillMorphSurface.qml"
    "Modules/Launcher/SpotlightModeMorphSurface.qml"
    "Modules/Wallpaper/WallpaperTransitionSurface.qml"
)

for relative_path in "${shader_consumers[@]}"; do
    qml_file="${project_dir}/${relative_path}"
    if ! grep -Fq 'Paths.fileUrl(' "$qml_file" \
        || ! grep -Fq 'Paths.assetsDir' "$qml_file"; then
        echo "Shader URL does not use the release-aware asset path: ${relative_path}" >&2
        exit 1
    fi
done

if grep -REn \
    'Qt\.resolvedUrl\([^)]*assets/shaders|"\.\./[^" ]*assets/shaders' \
    "${shader_consumers[@]/#/${project_dir}/}"; then
    echo "A shader URL still depends on the QML installation directory" >&2
    exit 1
fi

qsb_command=""
if command -v qsb >/dev/null 2>&1; then
    qsb_command=$(command -v qsb)
else
    qt_paths_command=""
    if command -v qtpaths6 >/dev/null 2>&1; then
        qt_paths_command=$(command -v qtpaths6)
    elif command -v qtpaths >/dev/null 2>&1; then
        qt_paths_command=$(command -v qtpaths)
    fi

    if [[ -n "$qt_paths_command" ]]; then
        qt_libexec=$($qt_paths_command --query QT_HOST_LIBEXECS 2>/dev/null || true)
        qt_bins=$($qt_paths_command --query QT_INSTALL_BINS 2>/dev/null || true)
        if [[ -x "${qt_libexec}/qsb" ]]; then
            qsb_command="${qt_libexec}/qsb"
        elif [[ -x "${qt_bins}/qsb" ]]; then
            qsb_command="${qt_bins}/qsb"
        fi
    fi

    if [[ -z "$qsb_command" ]] && command -v pkg-config >/dev/null 2>&1 \
        && pkg-config --exists Qt6Core; then
        qt_libexec=$(pkg-config --variable=libexecdir Qt6Core)
        if [[ -x "${qt_libexec}/bin/qsb" ]]; then
            qsb_command="${qt_libexec}/bin/qsb"
        fi
    fi
fi

if [[ -z "$qsb_command" ]]; then
    echo "Qt Shader Tools qsb was not found" >&2
    exit 1
fi

shader_count=0
while IFS= read -r -d '' fragment_file; do
    compiled_file=${fragment_file/\/frag\//\/qsb\/}.qsb
    if [[ ! -f "$compiled_file" ]]; then
        echo "Missing compiled shader: ${compiled_file#${project_dir}/}" >&2
        exit 1
    fi
    "$qsb_command" --dump "$compiled_file" >/dev/null
    shader_count=$((shader_count + 1))
done < <(find "${project_dir}/assets/shaders" -type f -path '*/frag/*.frag' \
    -print0 | sort -z)

if (( shader_count == 0 )); then
    echo "No shader sources were found" >&2
    exit 1
fi

echo "Validated ${shader_count} compiled shaders and release-aware QML URLs"
