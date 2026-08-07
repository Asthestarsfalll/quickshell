import QtQuick
import QtQuick.Layouts
import Clavis.Niri
import qs.Common
import qs.Services
import qs.Widgets.common

Item {
    id: root

    property bool vertical: false
    property string edge: "top"
    readonly property real sideRotation: edge === "left" ? -90 : 90

    implicitHeight: vertical ? Math.min(274, layout.implicitWidth + 24) : 36
    implicitWidth: vertical ? Sizes.verticalBarWidth : layout.width + 24

    Behavior on implicitWidth {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    readonly property var activeWindow: Niri.focusedWindow
    readonly property string activeTitle: activeWindow.title || qsTr("桌面")
    readonly property string activeIcon: activeWindow.iconPath || ""
    readonly property string activeAppName: activeWindow.appName || activeWindow.appId || ""

    TopBarPillBackground { anchors.fill: parent }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 10
        rotation: root.vertical ? root.sideRotation : 0

        Item {
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            Layout.alignment: Qt.AlignVCenter
            visible: root.activeIcon !== "" || root.activeAppName !== ""

            Image {
                id: appIcon
                anchors.fill: parent
                source: root.activeIcon
                sourceSize.width: 36
                sourceSize.height: 36
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                visible: root.activeIcon !== "" && status !== Image.Error
            }

            Text {
                anchors.centerIn: parent
                text: (root.activeAppName || "?").charAt(0).toUpperCase()
                color: Appearance.colors.colPrimary
                font.pixelSize: 13
                font.bold: true
                visible: !appIcon.visible
            }
        }

        Text {
            id: windowTitle
            text: root.activeTitle

            font.family: Fonts.ui
            font.pointSize: 11
            color: Appearance.colors.colOnSurface

            Layout.maximumWidth: 250
            elide: Text.ElideRight
            Layout.alignment: Qt.AlignVCenter
        }
    }

    PopupToolTip {
        extraVisibleCondition: root.vertical && activeHover.containsMouse
        text: root.activeTitle
    }

    MouseArea {
        id: activeHover
        anchors.fill: parent
        enabled: root.vertical
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}
