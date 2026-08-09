import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components

Rectangle {
    id: root

    property string title: ""
    property string iconName: ""
    property string supportingText: ""
    default property alias content: body.data

    implicitHeight: sectionLayout.implicitHeight + Metrics.cardPadding * 2
    radius: Metrics.cornerL
    color: Appearance.colors.colLayer1

    ColumnLayout {
        id: sectionLayout

        anchors {
            fill: parent
            margins: Metrics.cardPadding
        }
        spacing: Metrics.spacingS

        RowLayout {
            Layout.fillWidth: true
            visible: root.title.length > 0 || root.iconName.length > 0
            spacing: Metrics.spacingS

            Rectangle {
                visible: root.iconName.length > 0
                Layout.preferredWidth: Metrics.controlHeightM
                Layout.preferredHeight: Metrics.controlHeightM
                radius: Appearance.rounding.normal
                color: Appearance.colors.colSecondaryContainer

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.iconName
                    iconSize: Metrics.iconM
                    fill: 1
                    color: Appearance.colors.colOnSecondaryContainer
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.title.length > 0
                text: root.title
                color: Appearance.colors.colOnLayer2
                font.family: Typography.titleMedium.family
                font.pixelSize: Typography.titleMedium.pixelSize
                font.weight: Typography.titleMedium.weight
                elide: Text.ElideRight
            }
        }

        Text {
            Layout.fillWidth: true
            visible: root.supportingText.length > 0
            text: root.supportingText
            color: Appearance.colors.colOnLayer1
            font.family: Fonts.ui
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }

        ColumnLayout {
            id: body

            Layout.fillWidth: true
            spacing: Metrics.spacingXS
        }
    }
}
