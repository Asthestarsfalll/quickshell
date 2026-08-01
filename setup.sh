#!/usr/bin/env bash
set -euo pipefail

setup_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/lib/clavis-paths.sh
source "$setup_dir/scripts/lib/clavis-paths.sh"
clavis_paths_init

command_name=${1:-help}
if [[ $# -gt 0 ]]; then
    shift
fi

release=""
build_dir=""
dry_run=false
deps_install=false
allow_dirty=${CLAVIS_ALLOW_DIRTY:-false}

usage() {
    cat <<'EOF'
Clavis source build and user-level release installer

Usage:
  ./setup.sh doctor
  ./setup.sh deps [--install]
  ./setup.sh configure [--release YYYY.MM.DD[.N]] [--build-dir PATH]
  ./setup.sh build [--release VERSION] [--build-dir PATH]
  ./setup.sh test [--release VERSION] [--build-dir PATH]
  ./setup.sh install [--release VERSION] [--build-dir PATH] [--dry-run] [--allow-dirty]
  ./setup.sh uninstall-build [--release VERSION] [--build-dir PATH] [--dry-run]
  ./setup.sh dry-run [--release VERSION] [--build-dir PATH]

The default install is entirely user-level. Only `deps --install` may invoke
the distribution package manager with sudo, and only when explicitly requested.

Environment overrides:
  CLAVIS_BIN_HOME, CLAVIS_INSTALL_PREFIX, CLAVIS_CONFIG_HOME,
  CLAVIS_DATA_HOME, CLAVIS_STATE_HOME, CLAVIS_CACHE_HOME,
  CLAVIS_RUNTIME_HOME, CLAVIS_PROFILE, CLAVIS_PROFILE_HOME,
  CLAVIS_GENERATED_HOME, CLAVIS_QML_IMPORT_HOME, CLAVIS_BUILD_ROOT and
  CLAVIS_ALLOW_DIRTY (local development releases only).
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --release)
            [[ $# -ge 2 ]] || { printf 'Missing value for --release\n' >&2; exit 2; }
            release=$2
            shift 2
            ;;
        --build-dir)
            [[ $# -ge 2 ]] || { printf 'Missing value for --build-dir\n' >&2; exit 2; }
            build_dir=$2
            shift 2
            ;;
        --dry-run)
            dry_run=true
            shift
            ;;
        --install)
            deps_install=true
            shift
            ;;
        --allow-dirty)
            allow_dirty=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown option: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

validate_release() {
    local value=$1
    if [[ ! "$value" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}(\.[0-9]+)?$ ]]; then
        printf 'Invalid release: %s\n' "$value" >&2
        return 1
    fi
    local date_part=${value:0:10}
    date -u -d "${date_part//./-}" '+%Y.%m.%d' 2>/dev/null \
        | grep -Fx -- "$date_part" >/dev/null
}

resolve_release() {
    if [[ -n "$release" ]]; then
        validate_release "$release"
        return
    fi

    local base
    base=$(date -u '+%Y.%m.%d')
    release=$base
    local fingerprint
    fingerprint=$(source_fingerprint)
    local revision=0
    while [[ -d "$CLAVIS_INSTALL_PREFIX/releases/$release" ]]; do
        local installed_fingerprint=""
        if [[ -f "$CLAVIS_INSTALL_PREFIX/releases/$release/release.json" ]]; then
            installed_fingerprint=$(python3 -c \
                'import json,sys; print(json.load(open(sys.argv[1])).get("sourceFingerprint", ""))' \
                "$CLAVIS_INSTALL_PREFIX/releases/$release/release.json" 2>/dev/null || true)
        fi
        if [[ "$installed_fingerprint" == "$fingerprint" ]]; then
            return
        fi
        revision=$((revision + 1))
        release="$base.$revision"
    done
}

source_fingerprint() {
    if ! git -C "$setup_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        printf 'unknown'
        return
    fi
    git -C "$setup_dir" ls-files -co --exclude-standard -z \
        | sort -z \
        | while IFS= read -r -d '' source_path; do
            printf '%s\0' "$source_path"
            local absolute_path=$setup_dir/$source_path
            if [[ -L "$absolute_path" ]]; then
                printf 'symlink:%s\0' "$(readlink -- "$absolute_path")"
            elif [[ -f "$absolute_path" ]]; then
                printf 'file:%s:' "$(stat -c '%a' -- "$absolute_path")"
                sha256sum "$absolute_path" | awk '{printf "%s\\0", $1}'
            else
                printf 'missing\0'
            fi
        done \
        | sha256sum \
        | awk '{print $1}'
}

source_is_dirty() {
    ! git -C "$setup_dir" diff-index --quiet HEAD -- \
        || [[ -n "$(git -C "$setup_dir" ls-files --others --exclude-standard)" ]]
}

resolve_build_dir() {
    resolve_release
    if [[ -z "$build_dir" ]]; then
        build_dir=${CLAVIS_BUILD_ROOT:-$setup_dir/.build}/$release
    fi
    if [[ "$build_dir" != /* ]]; then
        build_dir=$setup_dir/$build_dir
    fi
    build_dir=$(realpath -m -- "$build_dir")
}

print_command() {
    printf '+'
    printf ' %q' "$@"
    printf '\n'
}

run() {
    if [[ "$dry_run" == true ]]; then
        print_command "$@"
    else
        "$@"
    fi
}

required_commands=(
    cmake c++ pkg-config python3 bash git qs systemctl loginctl which
)
required_pkg_modules=(Qt6Core Qt6Qml Qt6Quick libpipewire-0.3 ncursesw)
required_arch_packages=(
    cmake gcc pkgconf qt6-base qt6-declarative qt6-shadertools qt6-tools
    qt6-5compat qt6-lottie qtkeychain-qt6 pipewire ncurses cava quickshell
    python bash coreutils systemd git which
)

doctor() {
    local failed=0
    printf 'Clavis build/install diagnostics\n'
    local dependency
    for dependency in "${required_commands[@]}"; do
        if command -v "$dependency" >/dev/null 2>&1; then
            printf '  [OK]   %s\n' "$dependency"
        else
            printf '  [FAIL] %s\n' "$dependency"
            failed=1
        fi
    done
    for dependency in "${required_pkg_modules[@]}"; do
        if pkg-config --exists "$dependency" 2>/dev/null; then
            printf '  [OK]   pkg-config %s\n' "$dependency"
        elif [[ "$dependency" == "ncursesw" ]] && pkg-config --exists ncurses 2>/dev/null; then
            printf '  [OK]   pkg-config ncurses (ncursesw fallback)\n'
        else
            printf '  [FAIL] pkg-config %s\n' "$dependency"
            failed=1
        fi
    done
    if pkg-config --exists libcava 2>/dev/null || pkg-config --exists cava 2>/dev/null; then
        printf '  [OK]   pkg-config libcava/cava\n'
    else
        printf '  [FAIL] pkg-config libcava/cava\n'
        failed=1
    fi
    if cmake --find-package -DNAME=Qt6Keychain -DCOMPILER_ID=GNU \
        -DLANGUAGE=CXX -DMODE=EXIST >/dev/null 2>&1; then
        printf '  [OK]   Qt6Keychain CMake package\n'
    else
        printf '  [WARN] Qt6Keychain check deferred to CMake configure\n'
    fi
    local qt_host_root=""
    qt_host_root=$(pkg-config --variable=libexecdir Qt6Core 2>/dev/null || true)
    for dependency in \
        "$qt_host_root/bin/qsb" \
        "$qt_host_root/bin/lrelease" \
        "$qt_host_root/qml/Qt5Compat" \
        "$qt_host_root/qml/Qt/labs/lottieqt"; do
        if [[ -n "$qt_host_root" && ( -x "$dependency" || -d "$dependency" ) ]]; then
            printf '  [OK]   %s\n' "$dependency"
        else
            printf '  [FAIL] Qt 6 runtime/tool path %s\n' "$dependency"
            failed=1
        fi
    done
    printf '\nArch Linux install command (not executed):\n  sudo pacman -S --needed'
    printf ' %q' "${required_arch_packages[@]}"
    printf '\n'
    return "$failed"
}

deps() {
    if [[ "$deps_install" == false ]]; then
        doctor
        return
    fi
    if ! command -v pacman >/dev/null 2>&1; then
        printf 'Automatic dependency installation is currently implemented only for Arch Linux.\n' >&2
        exit 1
    fi
    run sudo pacman -S --needed "${required_arch_packages[@]}"
}

configure() {
    resolve_build_dir
    local commit
    commit=$(git -C "$setup_dir" rev-parse HEAD 2>/dev/null || printf 'unknown')
    local dirty=false
    if source_is_dirty; then
        dirty=true
    fi
    local fingerprint
    fingerprint=$(source_fingerprint)
    run cmake \
        -S "$setup_dir/core" \
        -B "$build_dir" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_MESSAGE=NEVER \
        -DBUILD_TESTING=ON \
        -DCLAVIS_RELEASE="$release" \
        -DCLAVIS_COMMIT="$commit" \
        -DCLAVIS_SOURCE_DIRTY="$dirty" \
        -DCLAVIS_SOURCE_FINGERPRINT="$fingerprint" \
        -DCLAVIS_CHANNEL=stable
}

build() {
    configure
    run cmake --build "$build_dir" --parallel
}

test_release() {
    build
    if [[ "$dry_run" == true ]]; then
        print_command env -u QT_QPA_PLATFORMTHEME QT_QPA_PLATFORM=offscreen \
            ctest --test-dir "$build_dir" --output-on-failure
    else
        env -u QT_QPA_PLATFORMTHEME QT_QPA_PLATFORM=offscreen \
            ctest --test-dir "$build_dir" --output-on-failure
    fi
}

install_release() {
    if source_is_dirty && [[ "$allow_dirty" != true ]]; then
        printf 'Refusing to publish a dirty source tree. Commit the release or rerun with --allow-dirty.\n' >&2
        exit 1
    fi
    resolve_build_dir
    test_release
    local partial=$CLAVIS_INSTALL_PREFIX/releases/$release.partial
    local launcher=$setup_dir/packaging/defaults/key-launcher
    if [[ "$dry_run" == true ]]; then
        print_command mkdir -p "$CLAVIS_INSTALL_PREFIX/releases"
        print_command cmake --install "$build_dir" --prefix "$partial"
        print_command python3 "$setup_dir/packaging/clavis-manager.py" \
            install-finalize --partial "$partial" --release "$release" \
            --launcher "$launcher"
        return
    fi

    mkdir -p "$CLAVIS_INSTALL_PREFIX/releases"
    if [[ -e "$partial" || -L "$partial" ]]; then
        rm -rf -- "$partial"
    fi
    cleanup_partial() {
        if [[ -d "$partial" ]]; then
            rm -rf -- "$partial"
        fi
    }
    trap cleanup_partial EXIT
    cmake --install "$build_dir" --prefix "$partial"
    python3 "$setup_dir/packaging/clavis-manager.py" \
        install-finalize --partial "$partial" --release "$release" \
        --launcher "$launcher"
    trap - EXIT
}

uninstall_build() {
    resolve_build_dir
    local default_root
    default_root=$(realpath -m -- "$setup_dir/.build")
    local allowed_root=$default_root
    if [[ -n "${CLAVIS_BUILD_ROOT:-}" ]]; then
        allowed_root=$CLAVIS_BUILD_ROOT
        if [[ "$allowed_root" != /* ]]; then
            allowed_root=$setup_dir/$allowed_root
        fi
        allowed_root=$(realpath -m -- "$allowed_root")
    fi
    if [[ "$build_dir" == / || "$build_dir" == "$HOME" \
        || "$build_dir" == "$setup_dir" || "$build_dir" == "$allowed_root" \
        || "$build_dir" != "$allowed_root/"* ]]; then
        printf 'Refusing to remove unsafe build directory outside %s: %s\n' \
            "$allowed_root" "$build_dir" >&2
        exit 1
    fi
    if [[ "$dry_run" == true ]]; then
        print_command rm -rf -- "$build_dir"
    elif [[ -d "$build_dir" ]]; then
        rm -rf -- "$build_dir"
    fi
}

case "$command_name" in
    help|-h|--help)
        usage
        ;;
    doctor)
        doctor
        ;;
    deps)
        deps
        ;;
    configure)
        configure
        ;;
    build)
        build
        ;;
    test)
        test_release
        ;;
    install)
        install_release
        ;;
    dry-run)
        dry_run=true
        install_release
        ;;
    uninstall-build)
        uninstall_build
        ;;
    *)
        printf 'Unknown command: %s\n' "$command_name" >&2
        usage >&2
        exit 2
        ;;
esac
