import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets.common

BarCircularButton {
    iconName: "power_settings_new"
    containerColor: Appearance.colors.colError
    rippleColor: Appearance.colors.colOnError
    iconColor: Appearance.colors.colOnError
    tooltipText: qsTr("电源菜单")
    onClicked: Quickshell.execDetached([Paths.systemScriptsDir + "/power-menu.sh", PersonalizationConfig.powerMenuStyle])
}
