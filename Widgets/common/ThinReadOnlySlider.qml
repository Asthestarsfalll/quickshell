import QtQuick
import QtQuick.Controls
import qs.Common

Slider {
    id: root

    from: 0
    to: 1
    enabled: false
    opacity: 1
    focusPolicy: Qt.NoFocus
    implicitHeight: 14

    background: Item {
        x: root.leftPadding
        y: root.topPadding + root.availableHeight / 2 - height / 2
        implicitWidth: 200
        implicitHeight: 8
        width: root.availableWidth
        height: implicitHeight

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 2
            radius: Appearance.rounding.full
            color: Appearance.colors.colOutlineVariant
        }

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, root.visualPosition * parent.width)
            height: 4
            radius: Appearance.rounding.full
            color: Appearance.colors.colPrimary
        }
    }

    handle: Rectangle {
        x: root.leftPadding
            + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + root.availableHeight / 2 - height / 2
        implicitWidth: 4
        implicitHeight: 12
        radius: Appearance.rounding.full
        color: Appearance.colors.colPrimary
    }
}
