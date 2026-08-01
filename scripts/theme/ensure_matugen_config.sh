#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
scripts_dir=$(cd -- "$script_dir/.." && pwd)
# shellcheck source=scripts/lib/clavis-paths.sh
source "$scripts_dir/lib/clavis-paths.sh"
clavis_paths_init

share_root=$(cd -- "$scripts_dir/.." && pwd)
if [[ -f "$share_root/libexec/matugen_config.py" ]]; then
    helper=$share_root/libexec/matugen_config.py
else
    helper=$share_root/packaging/matugen_config.py
fi

python3 "$helper" \
    --share-root "$share_root" \
    --config "$CLAVIS_PROFILE_CONFIG_HOME/matugen/config.toml" \
    --generated-home "$CLAVIS_GENERATED_HOME" \
    --initialize-only
