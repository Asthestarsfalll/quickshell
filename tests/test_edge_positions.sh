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

config=Services/PersonalizationConfig.qml
require_text "$config" 'property string barPosition: "top"'
require_text "$config" 'property string keystonePosition: "top"'
require_text "$config" 'function normalizedEdgePosition(value)'
require_text "$config" 'function setBarPosition(value)'
require_text "$config" 'function setKeystonePosition(value)'
require_text "$config" '"position": root.barPosition'
require_text "$config" '"position": root.keystonePosition'

# Orientation changes select a different layer-surface implementation instead
# of mutating the topology of one mapped PanelWindow.
require_text Modules/Bar/Bar.qml 'HorizontalBarWindow {'
require_text Modules/Bar/Bar.qml 'VerticalBarWindow {'
require_text Modules/Bar/Bar.qml 'root.horizontal ? Quickshell.screens : []'
require_text Modules/Bar/Bar.qml 'root.horizontal ? [] : Quickshell.screens'

require_text Modules/Bar/HorizontalBarWindow.qml 'left: true'
require_text Modules/Bar/HorizontalBarWindow.qml 'right: true'
require_text Modules/Bar/HorizontalBarWindow.qml 'top: axis.isTop'
require_text Modules/Bar/HorizontalBarWindow.qml 'bottom: axis.isBottom'
require_text Modules/Bar/HorizontalBarWindow.qml 'exclusiveZone: exclusiveThickness'
require_text Modules/Bar/HorizontalBarContent.qml 'RowLayout {'

require_text Modules/Bar/VerticalBarWindow.qml 'top: true'
require_text Modules/Bar/VerticalBarWindow.qml 'bottom: true'
require_text Modules/Bar/VerticalBarWindow.qml 'left: axis.isLeft'
require_text Modules/Bar/VerticalBarWindow.qml 'right: axis.isRight'
require_text Modules/Bar/VerticalBarWindow.qml 'exclusiveZone: exclusiveThickness'
require_text Modules/Bar/VerticalBarContent.qml 'ColumnLayout {'
require_text Modules/Bar/HorizontalBarWindow.qml \
    'item: content.leadingInputRegionItem'
require_text Modules/Bar/HorizontalBarWindow.qml \
    'item: content.trailingInputRegionItem'
require_text Modules/Bar/VerticalBarWindow.qml \
    'item: content.leadingInputRegionItem'
require_text Modules/Bar/VerticalBarWindow.qml \
    'item: content.trailingInputRegionItem'
reject_text Modules/Bar/HorizontalBarContent.qml 'id: inputBand'
reject_text Modules/Bar/VerticalBarContent.qml 'id: inputBand'

require_text Common/Sizes.qml 'barVisualThickness:'
require_text Common/Sizes.qml 'barOuterEdgeMargin:'
require_text Common/Sizes.qml 'barShadowBuffer:'
require_text Common/Sizes.qml 'barPopupGap:'
require_text Modules/Bar/HorizontalBarWindow.qml \
    'outerEdgeMargin + visualThickness + shadowBuffer'
require_text Modules/Bar/HorizontalBarWindow.qml \
    'outerEdgeMargin + visualThickness'
require_text Modules/Bar/VerticalBarWindow.qml \
    'outerEdgeMargin + visualThickness + shadowBuffer'
require_text Modules/Bar/VerticalBarWindow.qml \
    'outerEdgeMargin + visualThickness'

# Vertical presentation is real layout. Directional affordances such as the
# tray expansion chevron may rotate, but text-bearing widgets may not.
for file in \
    Modules/Bar/ActiveWindow/ActiveWindow.qml \
    Modules/Bar/ActiveWindow/SidebarButton.qml \
    Modules/Bar/ActiveWindow/SidebarWeatherButton.qml \
    Modules/Bar/QuickSettings/Network.qml \
    Modules/Bar/QuickSettings/QuickSettings.qml \
    Modules/Bar/SysMonitor/SysMonitor.qml \
    Modules/Bar/Workspaces/Workspaces.qml
do
    reject_text "$file" 'sideRotation'
    reject_text "$file" 'rotation:'
done

require_text Modules/Bar/ActiveWindow/ActiveWindow.qml \
    'function verticalTitle(value)'
require_text Modules/Bar/ActiveWindow/ActiveWindow.qml \
    'verticalAppName: activeAppName || qsTr("桌面")'
require_text Modules/Bar/ActiveWindow/ActiveWindow.qml 'PopupToolTip {'
require_text Modules/Bar/QuickSettings/Network.qml \
    '34 / Sizes.barControlCircleSize'

require_text Modules/Bar/SysMonitor/SysMonitor.qml \
    'columns: root.vertical ? 1 : 4'
require_text Modules/Bar/SysMonitor/SysMonitor.qml \
    'SystemMonitorService.acquire()'
require_text Modules/Bar/SysMonitor/SysMonitor.qml \
    'Format.rootDisk(SystemMonitorService.disks)'
require_text Common/functions/SystemFormat.js 'function rootDisk(disks)'
require_text Modules/Sidebars/Left/system/SystemStorageCard.qml \
    'Format.rootDiskIndex(root.disks)'
require_text Modules/Bar/SysMonitor/SysMonitor.qml \
    'function normalizedTemperature(value)'
require_text Modules/Bar/SysMonitor/SysMonitor.qml 'Format.bytes'
require_text Modules/Bar/SysMonitor/SysMonitor.qml 'PopupToolTip {'
require_text Modules/Bar/SysMonitor/SysMonitor.qml \
    'TopBarPillBackground {'
require_text Modules/Bar/SysMonitor/SysMonitor.qml \
    'horizontalIndicatorSize: Sizes.barControlCircleSize'
require_text Modules/Bar/SysMonitor/SysMonitor.qml \
    'Sizes.barPillThickness'
require_text Modules/Bar/SysMonitor/SysMonitor.qml \
    '2 * Sizes.barPillHorizontalPadding'
reject_text Modules/Bar/SysMonitor/SysMonitor.qml 'colError'
reject_text Modules/Bar/SysMonitor/SysMonitor.qml 'colLayer4'
require_text Modules/Bar/SysMonitor/ResourcePie.qml \
    'property bool showPercentage: false'
reject_text Modules/Bar/SysMonitor/SysMonitor.qml \
    'Behavior on implicitWidth'
reject_text Modules/Bar/SysMonitor/SysMonitor.qml 'opacity:'
reject_text Modules/Bar/SysMonitor/SysMonitor.qml 'Fonts.nerdFont'
require_text Modules/Bar/SysMonitor/ResourcePie.qml 'PathAngleArc {'
require_text Modules/Bar/SysMonitor/ResourcePie.qml 'startAngle: -90'
require_text Modules/Bar/SysMonitor/ResourcePie.qml 'PathLine {'
require_text Modules/Bar/SysMonitor/ResourcePie.qml \
    'readonly property real normalizedValue:'
require_text Modules/Bar/SysMonitor/ResourcePie.qml \
    'Typography.labelLarge.pixelSize'
require_text Common/Sizes.qml 'barPillThickness: 36'
require_text Common/Sizes.qml 'barControlCircleSize: 28'
require_text Common/Sizes.qml 'barWeatherVerticalPillHeight: 56'

require_text Modules/Keystone/ClockContent/ClockContent.qml \
    'function sideDateParts(date)'
reject_text Modules/Keystone/ClockContent/ClockContent.qml 'sideRotation'
reject_text Modules/Keystone/ClockContent/ClockContent.qml \
    'text: root.verticalCharacters(root.dateStr)'
require_text Modules/Keystone/ClockContent/ClockContent.qml \
    'property var verticalDateParts: []'
require_text Modules/Keystone/ClockContent/ClockContent.qml \
    'visible: !root.vertical'
require_text Modules/Keystone/ClockContent/ClockContent.qml \
    'visible: root.vertical'
require_text Modules/Keystone/VolumeContent/VolumeContent.qml \
    'property bool vertical: false'
require_text Modules/Keystone/VolumeContent/VolumeContent.qml \
    'readonly property real splitY:'
require_text Modules/Keystone/VolumeContent/VolumeContent.qml \
    '1 - position / height'
require_text Modules/Keystone/Styles/Shared/KeystoneSurface.qml \
    'isCollapsedMode || isToolsMode || isVolumeMode'
require_text Modules/Keystone/Styles/Shared/KeystoneSurface.qml \
    'vertical: !keystoneWindow.horizontalEdge'

require_text Widgets/common/PopupToolTip.qml 'function edgeToAnchor(edge)'
require_text Widgets/common/PopupToolTip.qml 'case "left"'
require_text Widgets/common/PopupToolTip.qml 'case "right"'
require_text Modules/Bar/Tray/TrayMenu.qml 'property var barVisualItem:'
require_text Modules/Bar/Tray/TrayMenu.qml 'property real popupGap: Sizes.barPopupGap'
require_text Modules/Bar/Tray/TrayMenu.qml 'root.edge === "left"'
require_text Modules/Bar/Tray/TrayMenu.qml 'root.edge === "right"'
require_text Modules/Bar/Tray/TrayMenu.qml 'root.edge === "bottom"'
require_text Modules/Bar/Tray/Tray.qml 'function barVisualBounds()'

require_text Modules/Sidebars/SidebarHostWindow.qml \
    'WlrLayershell.exclusionMode: ExclusionMode.Normal'
require_text Modules/Sidebars/SidebarHostWindow.qml 'exclusiveZone: 0'
reject_text Modules/Sidebars/SidebarHostWindow.qml 'PersonalizationConfig.barPosition'
reject_text Modules/Sidebars/Left/LeftSidebarWindow.qml 'Sizes.barHeight'
reject_text Modules/Sidebars/Right/RightSidebar.qml 'Sizes.barHeight'

require_text Modules/Keystone/Styles/Shared/KeystoneSurface.qml \
    'readonly property string edge: PersonalizationConfig.keystonePosition'
require_text Modules/Keystone/Styles/Shared/KeystoneSurface.qml 'exclusiveZone: -1'
require_text Modules/Keystone/Styles/Shared/KeystoneSurface.qml \
    'WlrLayershell.exclusionMode: ExclusionMode.Ignore'
reject_text Modules/Keystone/Styles/Shared/KeystoneSurface.qml \
    'PersonalizationConfig.barPosition'
reject_text Modules/Keystone/Styles/Shared/KeystoneSurface.qml 'rotation: 90'
require_text Modules/Keystone/Styles/Shared/KeystoneSurface.qml \
    'collapsedH + (isCollapsedHovered ? 16 : 0)'

require_text Modules/ControlCenter/GeneralOverviewPage.qml \
    'root.sectionRequested("bar")'
require_text Modules/ControlCenter/GeneralPage.qml \
    'Qt.resolvedUrl("GeneralBarPage.qml")'
require_text Modules/ControlCenter/GeneralBarPage.qml \
    'PersonalizationConfig.setBarPosition(position)'
require_text Modules/ControlCenter/KeystonePage.qml \
    'PersonalizationConfig.setKeystonePosition(position)'
reject_text Modules/ControlCenter/ControlCenterWindow.qml '"id": "bar"'

echo "edge position architecture tests passed"
