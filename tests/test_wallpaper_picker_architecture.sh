#!/bin/sh

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_dir"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

require_text() {
    grep -Fq -- "$2" "$1" || fail "$1 does not contain: $2"
}

reject_text() {
    if grep -Fq -- "$2" "$1"; then
        fail "$1 unexpectedly contains: $2"
    fi
}

require_text Modules/ControlCenter/WallpaperPage.qml \
    'WallpaperService.setWallpaperFromFile('
reject_text Modules/ControlCenter/WallpaperPage.qml \
    'WallpaperService.setWallpaperFolder(folder)'
reject_text Modules/ControlCenter/WallpaperPage.qml \
    'key ipc call wallpaper'

require_text Services/WallpaperService.qml 'function setWallpaperFromFile(path, screenName)'
require_text Services/WallpaperService.qml 'root.pendingWallpaperPath = path'
require_text Services/WallpaperService.qml 'if (root.scanRequested)'
require_text Services/WallpaperService.qml \
    'root.setWallpaper(path, screenName);'
reject_text Services/WallpaperService.qml 'function forwardIpc'
reject_text Services/WallpaperService.qml 'primaryInstance'
reject_text Services/WallpaperService.qml 'fromIpc'
reject_text Services/WallpaperService.qml 'key", "ipc", "call", "wallpaper"'

require_text Services/AwwwWallpaperService.qml \
    'target: WallpaperService'
reject_text Services/AwwwWallpaperService.qml 'primaryInstance'
require_text AppShell.qml 'WallpaperService.setWallpaper(path || "", "")'

echo "wallpaper picker architecture tests passed"
