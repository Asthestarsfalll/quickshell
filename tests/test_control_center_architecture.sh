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
reject_text Modules/ControlCenter/ControlCenterWindow.qml \
    '"id": "autostart"'
reject_text Modules/ControlCenter/ControlCenterWindow.qml \
    '"id": "niri"'

for removed_file in \
    Modules/ControlCenter/NiriPage.qml \
    Services/NiriConfigService.qml \
    Services/NiriOutputConfigService.qml \
    Services/NiriLayoutConfigService.qml \
    Services/NiriKeybindService.qml \
    Services/NiriRuntimeService.qml \
    scripts/system/manage-niri-config.py \
    tests/test_manage_niri_config.py \
    Common/functions/MetricsMath.js \
    tests/qml/tst_Metrics.qml
do
    if [ -e "$removed_file" ]; then
        fail "$removed_file should have been removed"
    fi
done

require_text Modules/ControlCenter/GeneralPage.qml \
    'case "autostart": return Qt.resolvedUrl("AutostartPage.qml")'
require_text Modules/ControlCenter/GeneralOverviewPage.qml \
    'trailingIconName: "chevron_right"'
for section in '界面' '交互' '应用'; do
    require_text Modules/ControlCenter/GeneralOverviewPage.qml "$section"
done
reject_text Modules/ControlCenter/GeneralOverviewPage.qml \
    '调整 Shell 的常用行为与用户级启动应用。'
reject_text Modules/ControlCenter/GeneralOverviewPage.qml 'title: qsTr("设置")'
for section in sidebar effects scrolling autostart; do
    require_text Modules/ControlCenter/GeneralOverviewPage.qml \
        "root.sectionRequested(\"$section\")"
done
reject_text Modules/ControlCenter/ThemePage.qml 'Niri 光标配置'
reject_text Modules/ControlCenter/AutostartPage.qml \
    'supportingText: AutostartService.autostartDir'
reject_text Modules/ControlCenter/AutostartPage.qml \
    '只显示用户目录中的 .desktop 条目'
reject_text Modules/ControlCenter/AutostartPage.qml \
    '从已安装应用中选择一个加入用户级开机启动。'
reject_text Modules/ControlCenter/DefaultAppsPage.qml \
    'required property string description'
reject_text Modules/ControlCenter/DefaultAppsPage.qml \
    'description: qsTr('
reject_text Modules/ControlCenter/DefaultAppsPage.qml \
    '选择用于打开常见文件和链接的系统默认应用'
reject_text Modules/ControlCenter/WallpaperPage.qml 'MaterialRadioGroup'
require_text Modules/ControlCenter/WallpaperPage.qml \
    'headerTrailing: SearchSelectMenuField'
require_text Modules/ControlCenter/WallpaperPage.qml \
    'component OriginalButtonGroup: StyledButtonGroup'
require_text Modules/ControlCenter/ThemePage.qml \
    'component OriginalButtonGroup: StyledButtonGroup'
require_text Modules/ControlCenter/GeneralOverviewPage.qml \
    'iconName: "dashboard"'
require_text Modules/ControlCenter/GeneralOverviewPage.qml \
    'iconName: "touch_app"'
require_text Modules/ControlCenter/GeneralOverviewPage.qml \
    'iconName: "apps"'
require_text Modules/Keystone/WeatherContent/WeatherMapLayerSelector.qml \
    'pressedExpansion: 4'
require_text Widgets/common/SearchSelectMenuField.qml \
    'property string enabledRole: "enabled"'
require_text Widgets/common/SearchSelectMenuField.qml \
    'property string tooltipRole: "tooltip"'
for file in \
    Modules/ControlCenter/GeneralSliderSetting.qml \
    Modules/ControlCenter/ThemePage.qml \
    Modules/ControlCenter/WallpaperPage.qml \
    Modules/ControlCenter/ClockSliderSetting.qml
do
    require_text "$file" 'MaterialSlider {'
    reject_text "$file" 'MaterialAccessibleSlider'
done
if [ -e Widgets/common/MaterialAccessibleSlider.qml ] \
        || [ -e Modules/ControlCenter/MaterialSlider.qml ]; then
    fail "duplicate Control Center slider implementation remains"
fi
require_text Widgets/common/MaterialSlider.qml 'signal moved(real value)'
require_text Widgets/common/MaterialSlider.qml 'signal committed(real value)'
require_text Widgets/common/MaterialSlider.qml 'property bool live: true'
require_text Widgets/common/MaterialSlider.qml 'property string valueSuffix: ""'
require_text Widgets/common/MaterialSlider.qml 'property var valueFormatter:'
require_text Widgets/common/MaterialSlider.qml 'property bool showValueIndicator: true'
require_text Widgets/common/MaterialTextField.qml 'verticalAlignment: TextInput.AlignVCenter'
require_text Widgets/common/MaterialTextField.qml \
    'readonly property bool fieldHovered:'
reject_text Widgets/common/MaterialTextField.qml \
    'readonly property bool hovered:'
require_text Widgets/common/SettingsSection.qml 'property string iconName: ""'
require_text Widgets/common/SettingsSection.qml \
    'Appearance.colors.colSecondaryContainer'
require_text Widgets/common/SettingsActionRow.qml 'leftPadding: Metrics.spacingL'
require_text Widgets/common/SettingsActionRow.qml 'rightPadding: Metrics.spacingL'
require_text Widgets/common/StyledButtonGroup.qml \
    'spacing: root.originalAppearance ? 2 : 0'
require_text Widgets/common/StyledButtonGroup.qml 'property int innerRadius: 0'
require_text Widgets/common/StyledButtonGroup.qml 'property int pressedExpansion: 0'
require_text Widgets/common/StyledButtonGroup.qml \
    'Appearance.colors.colSecondaryContainer'
require_text Widgets/common/MaterialSlider.qml \
    'track.trackEndX - root.trackHeight / 2 - width / 2'
reject_text Widgets/common/MaterialSlider.qml 'indicatorCone'
reject_text Widgets/common/MaterialSlider.qml '"#000000"'
reject_text Widgets/common/MaterialSlider.qml '"#ffffff"'
reject_text AppShell.qml 'property: "uiScale"'
reject_text Modules/ControlCenter/ControlCenterWindow.qml \
    'property: "uiScale"'
reject_text Common/Metrics.qml 'function scaled('
reject_text Common/Metrics.qml 'property real uiScale'
reject_text Services/PersonalizationConfig.qml 'uiScale'
reject_text Services/PersonalizationConfig.qml 'pomodoroSoundEnabled'
reject_text Services/TimerService.qml 'playSystemSound('

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
        Modules/ControlCenter Modules/FilePicker Services scripts tests >/dev/null; then
    fail "a compositor floating workaround for an internal control-center window remains"
fi

echo "control center architecture tests passed"
