import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Widgets.common

Item {
    id: root

    property string title: ""
    property string iconName: "settings"
    property string backAccessibleName: qsTr("返回通用设置")
    signal backRequested()

    implicitHeight: 56

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Metrics.spacingL
        anchors.rightMargin: Metrics.spacingL
        spacing: Metrics.spacingS

        MaterialRippleButton {
            Layout.preferredWidth: Metrics.controlHeightM
            Layout.preferredHeight: Metrics.controlHeightM
            buttonRadius: Appearance.rounding.full
            colBackground: "transparent"
            colBackgroundHover: Appearance.colors.colLayer2Hover
            colRipple: Appearance.colors.colLayer2Active
            Accessible.name: root.backAccessibleName
            releaseAction: () => root.backRequested()

            contentItem: MaterialSymbol {
                text: "arrow_back"
                iconSize: Metrics.iconM
                color: Appearance.colors.colOnSurface
            }
        }

        MaterialSymbol {
            visible: root.iconName !== ""
            Layout.preferredWidth: visible ? Metrics.iconM : 0
            Layout.preferredHeight: Metrics.iconM
            text: root.iconName
            iconSize: Metrics.iconM
            color: Appearance.colors.colOnSurfaceVariant
        }

        Text {
            Layout.fillWidth: true
            text: root.title
            color: Appearance.colors.colOnSurface
            font.family: Typography.titleLarge.family
            font.pixelSize: Typography.titleLarge.pixelSize
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
    }
}
