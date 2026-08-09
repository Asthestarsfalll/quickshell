#!/usr/bin/env bash

set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
app_provider="$repo_dir/Modules/Launcher/SpotlightAppProvider.qml"
wallpaper_provider="$repo_dir/Modules/Launcher/SpotlightWallpaperProvider.qml"
clipboard_provider="$repo_dir/Modules/Launcher/SpotlightClipboardProvider.qml"
results_panel="$repo_dir/Modules/Launcher/SpotlightResultsPanel.qml"
wallpaper_service="$repo_dir/Services/WallpaperService.qml"

fail() {
    printf 'spotlight architecture test: %s\n' "$1" >&2
    exit 1
}

require_text() {
    rg -Fq -- "$2" "$1" || fail "$1 does not contain: $2"
}

reject_text() {
    if rg -Fq -- "$2" "$1"; then
        fail "$1 unexpectedly contains: $2"
    fi
}

require_text "$app_provider" 'target: ApplicationService'
require_text "$app_provider" 'function onApplicationsChanged()'
reject_text "$app_provider" 'target: DesktopEntries'

require_text "$wallpaper_provider" 'function onWallpapersChanged()'
reject_text "$wallpaper_provider" 'function onCurrentWallpaperChanged()'
reject_text "$wallpaper_provider" 'function onRevisionChanged()'
reject_text "$wallpaper_provider" 'current:'
require_text "$wallpaper_service" 'function normalizedPath(value)'

require_text "$results_panel" 'readonly property bool isCurrentWallpaper:'
require_text "$results_panel" 'WallpaperService.normalizedPath('
require_text "$results_panel" 'readonly property var displayData:'
require_text "$results_panel" 'ClipboardService.detailsRevision'
require_text "$results_panel" '.displayData.previewUrl'
require_text "$results_panel" 'clipboardDelegate.displayData.title'
require_text "$results_panel" 'clipboardDelegate.displayData.subtitle'
require_text "$results_panel" 'clipboardDelegate.displayData.icon'
reject_text "$results_panel" 'wallpaperDelegate.modelData.current'
reject_text "$results_panel" 'clipboardDelegate.modelData.previewUrl'
reject_text "$results_panel" 'clipboardDelegate.modelData.title'
reject_text "$results_panel" 'clipboardDelegate.modelData.subtitle'
reject_text "$results_panel" 'clipboardDelegate.modelData.icon'

require_text "$clipboard_provider" 'const useInspectedDetails = needle !== "";'
require_text "$clipboard_provider" 'function onDetailsRevisionChanged()'
require_text "$clipboard_provider" \
    'if (String(root.query || "").trim() !== "")'

printf '%s\n' 'spotlight architecture audit passed'
