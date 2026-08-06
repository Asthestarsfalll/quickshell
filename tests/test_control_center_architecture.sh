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

if [ -e controlcenter.qml ]; then
    fail "the detached control center entry point still exists"
fi

require_text AppShell.qml 'LazyLoader {'
require_text AppShell.qml 'ControlCenterWindow {'
require_text AppShell.qml 'ControlCenterService.registerLoader'
require_text AppShell.qml 'ControlCenterService.registerWindow'
require_text AppShell.qml 'ControlCenterService.windowClosed'
require_text AppShell.qml 'target: "control-center"'
require_text Services/ControlCenterService.qml 'function open(pageId)'
require_text Services/ControlCenterService.qml 'function toggle(pageId)'
require_text Services/ControlCenterService.qml 'controlCenterLoader.active = true'
require_text Services/ControlCenterService.qml \
    'controlCenterLoader.active = false'
require_text Modules/ControlCenter/ControlCenterWindow.qml \
    'signal popoutClosed'
require_text Modules/ControlCenter/ControlCenterWindow.qml \
    'function showWindow()'
require_text Modules/ControlCenter/ControlCenterWindow.qml \
    'property var parentModal: root'
require_text Modules/ControlCenter/ControlCenterWindow.qml \
    'item.parentModal = parentModal'
require_text Modules/ControlCenter/ControlCenterWindow.qml \
    'function closeChildWindows()'

require_text Modules/ControlCenter/AccountPage.qml \
    'parentModal: root.parentModal'
require_text Modules/ControlCenter/AutostartPage.qml \
    'onLoaded: item.parentModal = root.parentModal'
require_text Modules/ControlCenter/WallpaperPage.qml \
    'parentModal: root.parentModal'
require_text Modules/ControlCenter/AppBrowserPopup.qml \
    'parentWindow: root.parentModal'
require_text Modules/FilePicker/FilePickerWindow.qml \
    'parentWindow: root.parentModal'
require_text Modules/ControlCenter/WallpaperColorPicker.qml \
    'parentWindow: root.parentModal'
require_text Modules/ControlCenter/BezierCurveLayerEditor.qml \
    'parentWindow: root.parentModal'
require_text Modules/ControlCenter/BezierCurveLayerEditor.qml \
    'PauseAnimation {'
require_text Modules/ControlCenter/BezierCurveLayerEditor.qml \
    'readonly property real collapsedMainSize: 72'
require_text Modules/ControlCenter/BezierCurveLayerEditor.qml \
    'readonly property real expandedMainSize: 50'
require_text Modules/ControlCenter/BezierCurveLayerEditor.qml \
    'Appearance.animation.elementMoveFast'
require_text Modules/ControlCenter/BezierCurveLayerEditor.qml \
    'radius: height / 2'
require_text Modules/ControlCenter/BezierCurveLayerEditor.qml \
    'property real morphProgress: expanded ? 1 : 0'
require_text Modules/ControlCenter/BezierCurveLayerEditor.qml \
    'property real revealProgress: expanded ? 1 : 0'
require_text Modules/ControlCenter/BezierCurveLayerEditor.qml \
    'rotation: 45 * fab.morphProgress'
reject_text Modules/ControlCenter/BezierCurveLayerEditor.qml \
    'delay: miniFab.motionDelay'
reject_text Modules/ControlCenter/BezierCurveLayerEditor.qml \
    'Behavior on x {'
reject_text Modules/ControlCenter/BezierCurveLayerEditor.qml \
    'Behavior on y {'
reject_text Modules/ControlCenter/BezierCurveLayerEditor.qml \
    'collapsedY'
reject_text Modules/ControlCenter/BezierCurveLayerEditor.qml \
    'Appearance.animation.emphasizedAccel'

for file in \
    Modules/ControlCenter/AppBrowserPopup.qml \
    Modules/FilePicker/FilePickerWindow.qml \
    Modules/ControlCenter/WallpaperColorPicker.qml \
    Modules/ControlCenter/BezierCurveLayerEditor.qml
do
    reject_text "$file" 'Window.window'
    reject_text "$file" 'raise('
    reject_text "$file" 'requestActivate('
done

for file in \
    Modules/QuickSettings/QuickSettingsSurface.qml \
    Modules/Bar/QuickSettings/SettingsButton.qml \
    Modules/Sidebars/Left/ProfileHeaderCard.qml
do
    reject_text "$file" 'controlcenter.qml'
    require_text "$file" 'ControlCenterService.open()'
done

if rg -n 'controlcenter\.qml|qs[[:space:]]+--path|Paths\.shellDir[[:space:]]*\+[[:space:]]*"/controlcenter\.qml"' \
        AppShell.qml Modules Services core >/dev/null; then
    fail "a detached control center launch reference remains"
fi

legacy_open_floating="open-"floating
legacy_toggle_floating="toggle-"window-"floating"
legacy_app_browser="clavis-"autostart-"app-"browser
if rg -n "$legacy_open_floating|$legacy_toggle_floating|$legacy_app_browser" \
        Modules/ControlCenter Modules/FilePicker Services scripts tests/test_manage_niri_config.py >/dev/null; then
    fail "a compositor floating workaround for an internal control-center window remains"
fi

echo "control center architecture tests passed"
