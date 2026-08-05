#!/usr/bin/env bash
set -euo pipefail

path="${1:?missing cursor configuration path}"
content="${2-}"
mkdir -p "$(dirname "$path")"
printf '%s' "$content" > "$path"
