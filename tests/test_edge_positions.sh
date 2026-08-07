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

require_text Modules/Bar/Bar.qml \
    'readonly property string edge: PersonalizationConfig.barPosition'
require_text Modules/Bar/Bar.qml \
    'exclusiveZone: barWindow.isHorizontal'
require_text Modules/Bar/Bar.qml 'columns: barWindow.isHorizontal ? 3 : 1'
require_text Widgets/common/PopupToolTip.qml 'function edgeToAnchor(edge)'
require_text Modules/Bar/Tray/TrayMenu.qml 'root.edge === "left"'
require_text Modules/Bar/Tray/TrayMenu.qml 'root.edge === "right"'
reject_text Modules/Bar/Bar.qml 'rotation: 90'

require_text Modules/Sidebars/SidebarHostWindow.qml \
    'WlrLayershell.exclusionMode: ExclusionMode.Normal'
require_text Modules/Sidebars/SidebarHostWindow.qml 'exclusiveZone: 0'
reject_text Modules/Sidebars/SidebarHostWindow.qml 'PersonalizationConfig.barPosition'
reject_text Modules/Sidebars/Left/LeftSidebarWindow.qml 'Sizes.barHeight'
reject_text Modules/Sidebars/Right/RightSidebar.qml 'Sizes.barHeight'

require_text Modules/Keystone/Styles/Shared/KeystoneSurface.qml \
    'readonly property string edge: PersonalizationConfig.keystonePosition'
require_text Modules/Keystone/Styles/Shared/KeystoneSurface.qml \
    'exclusiveZone: -1'
require_text Modules/Keystone/Styles/Shared/KeystoneSurface.qml \
    'WlrLayershell.exclusionMode: ExclusionMode.Ignore'
reject_text Modules/Keystone/Styles/Shared/KeystoneSurface.qml \
    'PersonalizationConfig.barPosition'
reject_text Modules/Keystone/Styles/Shared/KeystoneSurface.qml 'rotation: 90'
require_text Modules/Keystone/Styles/Shared/KeystoneSurface.qml \
    'readonly property bool sideCompactLayout:'
require_text Modules/Keystone/Styles/Shared/KeystoneSurface.qml \
    'vertical: !keystoneWindow.horizontalEdge'
require_text Modules/Keystone/ClockContent/ClockContent.qml \
    'rotation: root.vertical ? root.sideRotation : 0'
require_text Modules/Keystone/Tools/ToolsContent.qml \
    'columns: toolsRoot.vertical ? 1 : toolsRoot.toolsModel.length'

require_text Modules/ControlCenter/GeneralOverviewPage.qml \
    'root.sectionRequested("bar")'
require_text Modules/ControlCenter/GeneralPage.qml \
    'Qt.resolvedUrl("GeneralBarPage.qml")'
require_text Modules/ControlCenter/GeneralBarPage.qml \
    'PersonalizationConfig.setBarPosition(position)'
reject_text Modules/ControlCenter/GeneralBarPage.qml 'iconName:'
require_text Modules/ControlCenter/KeystonePage.qml \
    'PersonalizationConfig.setKeystonePosition(position)'
reject_text Modules/ControlCenter/ControlCenterWindow.qml \
    '"id": "bar"'

echo "edge position architecture tests passed"
