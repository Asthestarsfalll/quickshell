#!/usr/bin/env bash
set -u

zsh_config="${1:?missing zsh config path}"
keytop_config="${2:?missing keytop config path}"
fcitx_config="${3:?missing fcitx5 config path}"

target_available() {
    local command_name="$1"
    local config_path="$2"
    command -v "$command_name" >/dev/null 2>&1 && [[ -f "$config_path" ]]
}

target_available zsh-theme "$zsh_config" && echo "zsh=true" || echo "zsh=false"
target_available keytop "$keytop_config" && echo "keytop=true" || echo "keytop=false"
target_available fcitx5-theme "$fcitx_config" && echo "fcitx5=true" || echo "fcitx5=false"
