import QtQuick
import QtQuick.Layouts
import Clavis.Niri
import qs.Common
import qs.Services
import qs.Widgets.common

Item {
    id: root

    property bool vertical: false

    implicitHeight: vertical ? layout.implicitHeight + 16 : Sizes.barPillThickness
    implicitWidth: vertical ? Sizes.barVisualThickness
        : layout.implicitWidth + 24

    Behavior on implicitWidth {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }
    Behavior on implicitHeight {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    readonly property var activeWindow: Niri.focusedWindow
    readonly property string activeTitle: activeWindow.title || qsTr("桌面")
    readonly property string activeIcon: activeWindow.iconPath || ""
    readonly property string activeAppName: activeWindow.appName || activeWindow.appId || ""
    readonly property string verticalAppName: activeAppName || qsTr("桌面")
    readonly property string detailedTooltipText:
        activeAppName && activeAppName !== activeTitle
            ? activeAppName + "\n" + activeTitle
            : activeTitle

    function verticalTitle(value) {
        const characters = Array.from(String(value || ""));
        const limit = 14;
        if (characters.length > limit)
            return characters.slice(0, limit - 1).concat(["…"]).join("\n");
        return characters.join("\n");
    }

    TopBarPillBackground { anchors.fill: parent }

    GridLayout {
        id: layout
        anchors.centerIn: parent
        columns: root.vertical ? 1 : 2
        rowSpacing: root.vertical ? 6 : 0
        columnSpacing: root.vertical ? 0 : 10

        Item {
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            Layout.alignment: Qt.AlignCenter
            visible: root.vertical || root.activeIcon !== ""
                || root.activeAppName !== ""

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
            text: root.vertical
                ? root.verticalTitle(root.verticalAppName) : root.activeTitle

            font.family: Fonts.ui
            font.pointSize: 11
            color: Appearance.colors.colOnSurface
            horizontalAlignment: Text.AlignHCenter
            lineHeight: root.vertical ? 0.9 : 1.0

            Layout.maximumWidth: 250
            elide: root.vertical ? Text.ElideNone : Text.ElideRight
            Layout.alignment: Qt.AlignCenter
        }
    }

    MouseArea {
        id: activeHover
        anchors.fill: parent
        enabled: root.vertical
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    PopupToolTip {
        extraVisibleCondition: root.vertical && activeHover.containsMouse
        text: root.detailedTooltipText
    }
}
