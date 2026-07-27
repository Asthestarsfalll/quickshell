import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Components

Button {
    id: root

    property string iconName: ""
    property string trailingIconName: "open_in_new"
    property bool showDivider: false

    implicitHeight: 56
    padding: 0
    flat: true
    hoverEnabled: true

    background: Rectangle {
        color: root.down
            ? Appearance.colors.colLayer2Active
            : root.hovered
              ? Appearance.colors.colLayer2Hover
              : "transparent"

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            visible: root.showDivider
            color: Appearance.colors.colOutlineVariant
        }
    }

    contentItem: RowLayout {
        spacing: Appearance.spacing.medium

        MaterialSymbol {
            visible: root.iconName !== ""
            text: root.iconName
            iconSize: 22
            color: Appearance.colors.colOnSurfaceVariant
        }

        Text {
            Layout.fillWidth: true
            text: root.text
            color: Appearance.colors.colOnSurface
            font.family: Sizes.fontFamily
            font.pixelSize: Sizes.typeBodyMedium
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        MaterialSymbol {
            visible: root.trailingIconName !== ""
            text: root.trailingIconName
            iconSize: 20
            color: Appearance.colors.colOnSurfaceVariant
        }
    }
}
