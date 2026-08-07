import QtQuick
import QtQuick.Layouts
import qs.Modules.Bar.Workspaces
import qs.Modules.Bar.ActiveWindow
import qs.Modules.Bar.Tray
import qs.Modules.Bar.SysMonitor
import qs.Modules.Bar.QuickSettings
import qs.Common

Item {
    id: root

    required property var screen
    required property var axis
    property string popupEdge: axis.edge

    readonly property alias inputRegionItem: inputBand
    readonly property alias workspacesItem: workspaces
    readonly property alias sidebarButtonItem: sidebarButton
    readonly property alias activeWindowItem: activeWindow
    readonly property alias trayItem: tray
    readonly property alias sysMonitorItem: sysMonitor
    readonly property alias quickSettingsItem: quickSettings

    Item {
        id: inputBand
        anchors.fill: parent
    }

    RowLayout {
        id: leftSection
        anchors {
            left: parent.left
            leftMargin: 10
            verticalCenter: parent.verticalCenter
        }
        spacing: 8

        Workspaces {
            id: workspaces
            screenName: root.screen.name
        }

        SidebarButton {
            id: sidebarButton
        }

        ActiveWindow {
            id: activeWindow
        }
    }

    RowLayout {
        id: rightSection
        anchors {
            right: parent.right
            rightMargin: 10
            verticalCenter: parent.verticalCenter
        }
        spacing: 8

        Tray {
            id: tray
            screen: root.screen
            edge: root.axis.edge
            barVisualItem: root
        }

        SysMonitor {
            id: sysMonitor
            Layout.alignment: Qt.AlignVCenter
        }

        QuickSettings {
            id: quickSettings
            screen: root.screen
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
