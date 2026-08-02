import QtQuick
import QtQuick.Layouts
import qs.Common

Rectangle {
    id: root

    property string title: ""
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

        Text {
            Layout.fillWidth: true
            visible: root.title.length > 0
            text: root.title
            color: Appearance.colors.colOnLayer2
            font.family: Sizes.fontFamily
            font.pixelSize: 15
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            visible: root.supportingText.length > 0
            text: root.supportingText
            color: Appearance.colors.colOnLayer1
            font.family: Sizes.fontFamily
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
