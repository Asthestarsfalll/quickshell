import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets.common

BarCircularButton {
    iconName: "power_settings_new"
    iconFill: 1
    containerColor: Appearance.colors.colError
    hoverContainerColor: Appearance.colors.colErrorHover
    pressedContainerColor: Appearance.colors.colErrorActive
    selectedContainerColor: Appearance.colors.colError
    iconColor: Appearance.colors.colOnError
    selectedIconColor: Appearance.colors.colOnError
    tooltipText: qsTr("电源菜单")
    onClicked: Quickshell.execDetached([Paths.systemScriptsDir + "/power-menu.sh", PersonalizationConfig.powerMenuStyle])
}
