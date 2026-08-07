import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

Item {
    id: root

    property bool vertical: false
    property string edge: "top"

    implicitHeight: vertical ? buttonRow.implicitHeight + 16 : 36
    implicitWidth: vertical ? Sizes.verticalBarWidth : buttonRow.implicitWidth + 16

    Behavior on implicitWidth { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    TopBarPillBackground { anchors.fill: parent }

    GridLayout {
        id: buttonRow
        anchors.centerIn: parent
        rowSpacing: 8
        columnSpacing: 8
        columns: root.vertical ? 1 : 3

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

        SidebarWeatherButton {
            vertical: root.vertical
            edge: root.edge
        }
    }
}
