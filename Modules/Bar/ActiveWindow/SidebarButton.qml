import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

Item {
    id: root

    implicitHeight: 36
    implicitWidth: buttonRow.implicitWidth + 16

    Behavior on implicitWidth { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    TopBarPillBackground { anchors.fill: parent }

    RowLayout {
        id: buttonRow
        anchors.centerIn: parent
        spacing: 8

        SidebarPillButton {
            viewName: "info"
            iconName: "notifications"
            activeColor: Appearance.colors.colSecondary
            activeContentColor: Appearance.colors.colOnSecondary
        }

        SidebarPillButton {
            viewName: "sys"
            iconName: "memory"
            activeColor: Appearance.colors.colTertiary
            activeContentColor: Appearance.colors.colOnTertiary
        }

        SidebarWeatherButton {}
    }
}
