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

for file in \
    Modules/Bar/Bar.qml \
    Modules/Bar/Tray/Tray.qml \
    Modules/Bar/Tray/TrayMenu.qml \
    Modules/ControlCenter/BezierCurveLayerEditor.qml \
    Modules/ControlCenter/WallpaperColorPicker.qml \
    Modules/ControlCenter/WallpaperFileBrowser.qml \
    Modules/Keystone/Styles/Shared/KeystoneSurface.qml \
    Modules/Launcher/LauncherWindow.qml \
    Modules/Sidebars/SidebarHostWindow.qml
do
    require_text "$file" 'WlrLayershell.namespace: "clavis-shell-'
done

for file in \
    Modules/Wallpaper/DesktopWallpaper.qml \
    Modules/Wallpaper/OverviewWallpaper.qml \
    Modules/Lock/LockSurface.qml \
    Modules/Lock/LockWarmup.qml \
    Modules/RegionSelector/RegionSelectionWindow.qml \
    Services/IdleInhibitorSurface.qml
do
    reject_text "$file" 'CompositorBlurRegion'
    reject_text "$file" 'BackgroundEffect.blurRegion'
    reject_text "$file" 'clavis-shell-'
done

require_text Modules/Bar/Bar.qml 'additionalBackgroundItems: ['
reject_text Modules/Bar/Bar.qml 'backgroundItem: barContent'
require_text Modules/Sidebars/SidebarHostWindow.qml \
    'additionalBackgroundItems: ['
require_text Modules/ControlCenter/ControlCenterWindow.qml \
    'color: "transparent"'
require_text Modules/ControlCenter/ControlCenterWindow.qml \
    'flags: Qt.Window | Qt.FramelessWindowHint'
require_text Modules/FilePicker/FilePickerWindow.qml \
    'color: "transparent"'
require_text Modules/FilePicker/FilePickerWindow.qml \
    'flags: Qt.Window | Qt.FramelessWindowHint'
require_text Modules/Keystone/Styles/Shared/KeystoneSurface.qml \
    'subtractedBackgroundItems: [dashboardBlurCutout]'
require_text Widgets/common/StyledToolTip.qml \
    'PopupToolTip {'
require_text Widgets/common/PopupToolTip.qml \
    'CompositorBlurRegion {'
require_text Widgets/common/CompositorBlurRegion.qml \
    'combinedRegion.regions = combinedRegions'
require_text Widgets/common/CompositorBlurRegion.qml \
    'intersection: Intersection.Subtract'

if rg -n '(^|\\s)(PanelWindow|window|root|sidebar|controlCenter|Loader)\\.opacity\\s*[:=].*shellBackgroundOpacity' \
        Modules Widgets Services >/dev/null; then
    fail "shell background opacity is applied to a window or content parent"
fi

echo "shell blur surface audit passed"
