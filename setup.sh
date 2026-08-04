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
build_testing=OFF
source_shell_args=()
stable_key=""
partial_cleanup_path=""

usage() {
    cat <<'EOF'
Clavis Shell source build and user-level release installer

Usage:
  ./setup.sh doctor
  ./setup.sh deps [--install]
  ./setup.sh configure [--release YYYY.MM.DD[.N]] [--build-dir PATH]
  ./setup.sh build [--release VERSION] [--build-dir PATH]
  ./setup.sh test [--release VERSION] [--build-dir PATH]
  ./setup.sh smoke [--release VERSION] [--build-dir PATH]
  ./setup.sh dev-build [--build-dir PATH]
  ./setup.sh run-source [-- QS_OPTIONS...]
  ./setup.sh install [--release VERSION] [--build-dir PATH] [--dry-run] [--allow-dirty]
  ./setup.sh uninstall-build [--release VERSION] [--build-dir PATH] [--dry-run]

Build and test responsibilities are intentionally separate. `build` never
runs CTest, smoke checks, installs, or changes user configuration. `install`
publishes a Shell-only runtime through the already installed stable `key` CLI;
Keytop and the CLI are owned by their own repositories.

Environment overrides:
  CLAVIS_BIN_HOME, CLAVIS_INSTALL_PREFIX, CLAVIS_CONFIG_HOME,
  CLAVIS_DATA_HOME, CLAVIS_STATE_HOME, CLAVIS_CACHE_HOME,
  CLAVIS_RUNTIME_HOME, CLAVIS_PROFILE, CLAVIS_PROFILE_HOME,
  CLAVIS_PROFILE_CONFIG_HOME, CLAVIS_GENERATED_HOME,
  CLAVIS_QML_IMPORT_HOME, CLAVIS_BUILD_ROOT and CLAVIS_ALLOW_DIRTY.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --)
            shift
            source_shell_args=("$@")
            break
            ;;
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

resolve_dev_build_dir() {
    if [[ -z "$build_dir" ]]; then
        build_dir=$setup_dir/.build/dev
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

build_commands=(cmake c++ pkg-config python3 bash git)
build_modules=(Qt6Core Qt6Qml Qt6Quick Qt6Network libpipewire-0.3)
runtime_commands=(qs key keytop)
runtime_optional=(niri systemctl loginctl busctl matugen)
required_arch_packages=(
    cmake gcc pkgconf qt6-base qt6-declarative qt6-shadertools qt6-tools
    qt6-5compat qt6-lottie qtkeychain-qt6 pipewire cava quickshell
    python bash coreutils systemd git
)

check_command_group() {
    local label=$1
    shift
    printf '%s dependencies:\n' "$label"
    local failed=0 dependency
    for dependency in "$@"; do
        if command -v "$dependency" >/dev/null 2>&1; then
            printf '  [OK]   %s\n' "$dependency"
        else
            printf '  [FAIL] %s\n' "$dependency"
            failed=1
        fi
    done
    return "$failed"
}

doctor() {
    local failed=0 dependency
    printf 'Clavis Shell diagnostics\n'
    check_command_group "Build" "${build_commands[@]}" || failed=1
    for dependency in "${build_modules[@]}"; do
        if pkg-config --exists "$dependency" 2>/dev/null; then
            printf '  [OK]   build pkg-config %s\n' "$dependency"
        else
            printf '  [FAIL] build pkg-config %s\n' "$dependency"
            failed=1
        fi
    done
    if cmake --find-package -DNAME=Qt6Keychain -DCOMPILER_ID=GNU \
        -DLANGUAGE=CXX -DMODE=EXIST >/dev/null 2>&1; then
        printf '  [OK]   build Qt6Keychain CMake package\n'
    else
        printf '  [WARN] build Qt6Keychain CMake package (configure will confirm)\n'
    fi

    check_command_group "Runtime" "${runtime_commands[@]}" || true
    check_command_group "Optional runtime" "${runtime_optional[@]}" || true
    printf '\nRuntime paths are checked again by install; missing optional tools do not block build.\n'
    printf 'Arch Linux dependency command (not executed):\n  sudo pacman -S --needed'
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
        printf 'Automatic dependency installation is implemented only for Arch Linux.\n' >&2
        exit 1
    fi
    run sudo pacman -S --needed "${required_arch_packages[@]}"
}

configure() {
    resolve_build_dir
    local commit dirty=false fingerprint build_time=""
    commit=$(git -C "$setup_dir" rev-parse HEAD 2>/dev/null || printf 'unknown')
    source_is_dirty && dirty=true
    fingerprint=$(source_fingerprint)
    if [[ -f "$CLAVIS_INSTALL_PREFIX/releases/$release/release.json" ]]; then
        build_time=$(python3 -c \
            'import json,sys; print(json.load(open(sys.argv[1])).get("buildTime", ""))' \
            "$CLAVIS_INSTALL_PREFIX/releases/$release/release.json" 2>/dev/null || true)
    fi
    [[ -n "$build_time" ]] || build_time=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    run cmake \
        -S "$setup_dir/core" \
        -B "$build_dir" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_MESSAGE=NEVER \
        -DBUILD_TESTING="$build_testing" \
        -DCLAVIS_RELEASE="$release" \
        -DCLAVIS_COMMIT="$commit" \
        -DCLAVIS_SOURCE_DIRTY="$dirty" \
        -DCLAVIS_SOURCE_FINGERPRINT="$fingerprint" \
        -DCLAVIS_BUILD_TIME="$build_time" \
        -DCLAVIS_CHANNEL=stable
}

configure_development() {
    resolve_dev_build_dir
    local commit dirty=false fingerprint build_time=""
    commit=$(git -C "$setup_dir" rev-parse HEAD 2>/dev/null || printf 'unknown')
    source_is_dirty && dirty=true
    fingerprint=$(source_fingerprint)
    if [[ -f "$build_dir/CMakeCache.txt" ]]; then
        build_time=$(sed -n 's/^CLAVIS_BUILD_TIME:[^=]*=//p' "$build_dir/CMakeCache.txt" | head -n 1)
    fi
    [[ -n "$build_time" ]] || build_time=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    run cmake \
        -S "$setup_dir/core" \
        -B "$build_dir" \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DCMAKE_INSTALL_MESSAGE=NEVER \
        -DBUILD_TESTING=OFF \
        -DCLAVIS_RELEASE=development \
        -DCLAVIS_COMMIT="$commit" \
        -DCLAVIS_SOURCE_DIRTY="$dirty" \
        -DCLAVIS_SOURCE_FINGERPRINT="$fingerprint" \
        -DCLAVIS_BUILD_TIME="$build_time" \
        -DCLAVIS_CHANNEL=development
}

build() {
    build_testing=OFF
    configure
    run cmake --build "$build_dir" --parallel
}

test_release() {
    build_testing=ON
    configure
    run cmake --build "$build_dir" --parallel
    if [[ "$dry_run" == true ]]; then
        print_command env -u QT_QPA_PLATFORMTHEME QT_QPA_PLATFORM=offscreen \
            ctest --test-dir "$build_dir" --output-on-failure
    else
        env -u QT_QPA_PLATFORMTHEME QT_QPA_PLATFORM=offscreen \
            ctest --test-dir "$build_dir" --output-on-failure
    fi
}

dev_build() {
    configure_development
    run cmake --build "$build_dir" --parallel
    printf 'Development native QML modules: %s\n' "$build_dir/lib/qml"
}

smoke() {
    resolve_build_dir
    local metadata=$build_dir/generated/release.json
    [[ -f "$metadata" ]] || {
        printf 'Smoke requires a configured build with %s\n' "$metadata" >&2
        exit 1
    }
    python3 - "$metadata" "$setup_dir" "$build_dir" <<'PY'
import json
import pathlib
import sys

metadata = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
root = pathlib.Path(sys.argv[2])
build = pathlib.Path(sys.argv[3])
required = ("component", "release", "minimumKeyCli", "minimumKeytop", "shellProtocol")
missing = [field for field in required if field not in metadata]
if missing:
    raise SystemExit("release metadata missing: " + ", ".join(missing))
if metadata["component"] != "quickshell":
    raise SystemExit("release metadata component is not quickshell")
for relative in (
    "shell.qml",
    "AppShell.qml",
    "Common/Paths.qml",
    "lib/qml/Clavis/Runtime/qmldir",
    "lib/qml/Clavis/WeatherMap/qmldir",
    "lib/qml/M3Shapes/qmldir",
):
    path = root / relative if not relative.startswith("lib/") else build / relative
    if not path.exists():
        raise SystemExit(f"smoke missing: {path}")
print("release metadata, Shell roots, and native QML module paths: OK")
PY
    if command -v qmlimportscanner >/dev/null 2>&1; then
        local scanner_log
        scanner_log=$(mktemp)
        if qmlimportscanner -importPath "$build_dir/lib/qml" -rootPath "$setup_dir" \
            "$setup_dir/shell.qml" >/dev/null 2>"$scanner_log"; then
            if [[ -s "$scanner_log" ]]; then
                printf 'QML import scanner: completed with diagnostics (first 8 lines):\n'
                sed -n '1,8p' "$scanner_log"
            else
                printf 'QML import scanner: OK\n'
            fi
        else
            cat "$scanner_log" >&2
            rm -f -- "$scanner_log"
            return 1
        fi
        rm -f -- "$scanner_log"
    else
        printf 'QML import scanner: SKIP (not installed)\n'
    fi
}

check_install_runtime() {
    local failed=0 dependency resolved
    stable_key=""
    for dependency in qs key keytop; do
        resolved=""
        if [[ "$dependency" == key ]]; then
            resolved=$(resolve_stable_key || true)
        elif [[ -x "$CLAVIS_BIN_HOME/$dependency" ]]; then
            resolved=$CLAVIS_BIN_HOME/$dependency
        else
            resolved=$(command -v "$dependency" 2>/dev/null || true)
        fi
        if [[ -n "$resolved" ]]; then
            [[ "$resolved" == /* ]] || resolved=$(realpath -m -- "$resolved")
            printf '  [OK]   %s: %s\n' "$dependency" "$resolved"
            [[ "$dependency" == key ]] && stable_key=$resolved
        else
            printf '  [FAIL] %s\n' "$dependency"
            failed=1
        fi
    done
    if [[ "$failed" -ne 0 ]]; then
        printf 'Install requires both the stable key CLI and independent keytop runtime.\n' >&2
        return 1
    fi
}

key_cli_is_standalone() {
    local candidate=$1 output
    output=$(env \
        CLAVIS_INSTALL_PREFIX="$CLAVIS_RUNTIME_HOME/setup-key-probe-$$" \
        CLAVIS_RELEASE_ROOT= \
        CLAVIS_KEY="$candidate" \
        "$candidate" version --json 2>/dev/null) || return 1
    python3 -c '
import json, sys
payload = json.loads(sys.argv[1])
raise SystemExit(0 if payload.get("product") == "clavis-key" else 1)
' "$output" >/dev/null 2>&1
}

resolve_stable_key() {
    local candidate seen=":"
    local -a candidates=()
    if [[ -n "${CLAVIS_KEY:-}" && "$CLAVIS_KEY" == /* ]]; then
        candidates+=("$CLAVIS_KEY")
    fi
    candidates+=("$CLAVIS_BIN_HOME/key")
    while IFS= read -r candidate; do
        [[ -n "$candidate" ]] && candidates+=("$candidate")
    done < <(type -aP key 2>/dev/null || true)

    for candidate in "${candidates[@]}"; do
        [[ "$candidate" == /* && -x "$candidate" ]] || continue
        [[ "$seen" != *":$candidate:"* ]] || continue
        seen+="$candidate:"
        if key_cli_is_standalone "$candidate"; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

cleanup_partial() {
    local candidate=${partial_cleanup_path:-}
    if [[ -n "$candidate" && -d "$candidate" ]]; then
        rm -rf -- "$candidate"
    fi
}

validate_partial() {
    local partial=$1
    [[ -f "$partial/release.json" ]] || { printf 'partial release has no release.json\n' >&2; return 1; }
    [[ -f "$partial/share/clavis/qml/shell.qml" ]] || { printf 'partial release has no Shell root\n' >&2; return 1; }
    [[ -d "$partial/lib/qml/Clavis" ]] || { printf 'partial release has no Clavis QML modules\n' >&2; return 1; }
    [[ -d "$partial/lib/qml/M3Shapes" ]] || { printf 'partial release has no M3Shapes module\n' >&2; return 1; }
    [[ ! -e "$partial/bin/key" ]] || { printf 'partial release must not contain bin/key\n' >&2; return 1; }
}

install_release() {
    check_install_runtime
    if source_is_dirty && [[ "$allow_dirty" != true ]]; then
        printf 'Refusing to publish a dirty source tree. Commit the release or rerun with --allow-dirty.\n' >&2
        exit 1
    fi
    build
    local partial
    resolve_build_dir
    partial=$CLAVIS_INSTALL_PREFIX/releases/$release.partial
    if [[ "$dry_run" == true ]]; then
        print_command mkdir -p "$CLAVIS_INSTALL_PREFIX/releases"
        print_command cmake --install "$build_dir" --prefix "$partial"
        print_command "$stable_key" release install-finalize \
            "$release" --partial "$partial"
        return
    fi

    mkdir -p "$CLAVIS_INSTALL_PREFIX/releases"
    if [[ -e "$partial" || -L "$partial" ]]; then
        rm -rf -- "$partial"
    fi
    partial_cleanup_path=$partial
    trap cleanup_partial EXIT
    cmake --install "$build_dir" --prefix "$partial"
    validate_partial "$partial"
    "$stable_key" release install-finalize \
        "$release" --partial "$partial"
    trap - EXIT
    partial_cleanup_path=""
}

run_source() {
    local source_key
    source_key=$(resolve_stable_key || true)
    [[ -n "$source_key" ]] || {
        printf 'run-source requires an installed key CLI in CLAVIS_KEY, CLAVIS_BIN_HOME, or PATH\n' >&2
        exit 1
    }
    exec "$source_key" shell --dev --native --source "$setup_dir" "${source_shell_args[@]}"
}

uninstall_build() {
    resolve_build_dir
    local allowed_root
    allowed_root=$(realpath -m -- "${CLAVIS_BUILD_ROOT:-$setup_dir/.build}")
    if [[ "$allowed_root" != /* ]]; then
        allowed_root=$setup_dir/$allowed_root
    fi
    allowed_root=$(realpath -m -- "$allowed_root")
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
    help|-h|--help) usage ;;
    doctor) doctor ;;
    deps) deps ;;
    configure) configure ;;
    build) build ;;
    test) test_release ;;
    smoke) smoke ;;
    dev-build) dev_build ;;
    run-source) run_source ;;
    install) install_release ;;
    uninstall-build) uninstall_build ;;
    *)
        printf 'Unknown command: %s\n' "$command_name" >&2
        usage >&2
        exit 2
        ;;
esac
