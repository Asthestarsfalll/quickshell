import QtQuick
import qs.Common
import qs.Services
import qs.Widgets.common

BarCircularButton {
    id: root

    property var screen: null
    readonly property bool active: WidgetState.qsOpen && WidgetState.qsView === "settings"

    iconName: "settings"
    selected: root.active
    containerColor: Appearance.colors.colPrimaryContainer
    hoverContainerColor: Appearance.colors.colPrimaryContainerHover
    pressedContainerColor: Appearance.colors.colPrimaryContainerActive
    selectedContainerColor: Appearance.colors.colPrimaryContainer
    iconColor: Appearance.colors.colOnPrimaryContainer
    selectedIconColor: Appearance.colors.colOnPrimaryContainer
    tooltipText: qsTr("左键：快捷设置\n右键：控制中心")
    onClicked: {
        if (root.screen && root.screen.name)
            WidgetState.qsScreenName = root.screen.name;

        if (root.active) {
            WidgetState.qsOpen = false;
        } else {
            WidgetState.qsView = "settings";
            WidgetState.qsOpen = true;
        }
    }
    onAltClicked: ControlCenterService.open()
}
