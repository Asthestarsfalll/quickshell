#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d /tmp/clavis-setup-install.XXXXXX)
cleanup() { rm -rf -- "$test_dir"; }
trap cleanup EXIT HUP INT TERM

fake_bin="$test_dir/bin"
mkdir -p "$fake_bin"

for command_name in qs keytop; do
    printf '#!/usr/bin/env bash\nexit 0\n' > "$fake_bin/$command_name"
    chmod +x "$fake_bin/$command_name"
done

cat > "$fake_bin/key" <<'EOF'
#!/usr/bin/env bash
if [[ ${1:-} == version && ${2:-} == --json ]]; then
    printf '{"product":"clavis-key"}\n'
    exit 0
fi
printf '%s\n' "$*" >> "${CLAVIS_SETUP_KEY_LOG:?}"
exit "${CLAVIS_SETUP_KEY_EXIT:-0}"
EOF
chmod +x "$fake_bin/key"

cat > "$fake_bin/cmake" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ ${1:-} != --install ]]; then
    exit 0
fi
prefix=""
while [[ $# -gt 0 ]]; do
    if [[ $1 == --prefix ]]; then
        prefix=$2
        break
    fi
    shift
done
[[ -n "$prefix" ]]
mkdir -p "$prefix/share/clavis/qml" "$prefix/lib/qml/Clavis" \
    "$prefix/lib/qml/M3Shapes"
printf '{}\n' > "$prefix/release.json"
printf 'import QtQuick\n' > "$prefix/share/clavis/qml/shell.qml"
EOF
chmod +x "$fake_bin/cmake"

export PATH="$fake_bin:$PATH"
export HOME="$test_dir/home"
export CLAVIS_INSTALL_PREFIX="$test_dir/install"
export CLAVIS_BUILD_ROOT="$test_dir/build-root"
export CLAVIS_SETUP_KEY_LOG="$test_dir/key.log"
unset CLAVIS_KEY CLAVIS_BIN_HOME

# Model the pre-split launcher that exists but cannot start without current.
mkdir -p "$HOME/.local/bin"
printf '#!/usr/bin/env bash\nexit 127\n' > "$HOME/.local/bin/key"
chmod +x "$HOME/.local/bin/key"

release=2099.01.01
dry_output=$(bash "$repo_dir/setup.sh" install --allow-dirty --dry-run \
    --release "$release" --build-dir "$test_dir/build")
grep -Fq "$fake_bin/key release install-finalize $release" <<<"$dry_output"
if grep -Fq "$HOME/.local/bin/key" <<<"$dry_output"; then
    printf 'setup selected a nonexistent HOME-local key instead of PATH\n' >&2
    exit 1
fi

export CLAVIS_SETUP_KEY_EXIT=42
set +e
failure_output=$(bash "$repo_dir/setup.sh" install --allow-dirty \
    --release "$release" --build-dir "$test_dir/build" 2>&1)
failure_status=$?
set -e
[[ $failure_status -eq 42 ]]
if grep -Fq '未绑定的变量' <<<"$failure_output" \
    || grep -Fq 'unbound variable' <<<"$failure_output"; then
    printf 'partial cleanup referenced an out-of-scope variable\n' >&2
    exit 1
fi
[[ ! -e "$CLAVIS_INSTALL_PREFIX/releases/$release.partial" ]]
grep -Fq "release install-finalize $release" "$CLAVIS_SETUP_KEY_LOG"

printf 'Clavis setup install tests passed\n'
