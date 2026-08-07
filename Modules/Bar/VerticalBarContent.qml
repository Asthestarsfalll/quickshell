import QtQuick
import QtQuick.Layouts
import qs.Modules.Bar.Workspaces
import qs.Modules.Bar.ActiveWindow
import qs.Modules.Bar.Tray
import qs.Modules.Bar.SysMonitor
import qs.Modules.Bar.QuickSettings

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

    // One stable window-coordinate band covers every visible control. It does
    // not depend on rotated bounds or dynamically measured section geometry.
    Item {
        id: inputBand
        anchors.fill: parent
    }

    ColumnLayout {
        id: topSection
        anchors {
            top: parent.top
            topMargin: 10
            horizontalCenter: parent.horizontalCenter
        }
        spacing: 8

        Workspaces {
            id: workspaces
            screenName: root.screen.name
            vertical: true
        }

        SidebarButton {
            id: sidebarButton
            vertical: true
        }

        ActiveWindow {
            id: activeWindow
            vertical: true
        }
    }

    ColumnLayout {
        id: bottomSection
        anchors {
            bottom: parent.bottom
            bottomMargin: 10
            horizontalCenter: parent.horizontalCenter
        }
        spacing: 8

        Tray {
            id: tray
            screen: root.screen
            edge: root.axis.edge
            vertical: true
            barVisualItem: root
        }

        SysMonitor {
            id: sysMonitor
            vertical: true
            Layout.alignment: Qt.AlignHCenter
        }

        QuickSettings {
            id: quickSettings
            screen: root.screen
            vertical: true
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
