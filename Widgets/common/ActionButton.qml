import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components

MaterialRippleButton {
    id: root

    property bool filled: false
    property string iconName: ""

    implicitWidth: Math.max(64, actionContent.implicitWidth
        + Metrics.spacingL * 2)
    implicitHeight: Metrics.controlHeightM
    leftPadding: Metrics.spacingM
    rightPadding: Metrics.spacingM
    buttonRadius: Appearance.rounding.full
    buttonRadiusPressed: Appearance.rounding.full
    colBackground: root.filled ? Appearance.colors.colPrimary : "transparent"
    colBackgroundHover: root.filled ? Appearance.colors.colPrimaryHover : Appearance.applyAlpha(Appearance.colors.colPrimary, root.down ? 0.12 : 0.08)
    colRipple: root.filled ? Appearance.applyAlpha(Appearance.colors.colOnPrimary, 0.12) : Appearance.applyAlpha(Appearance.colors.colPrimary, 0.12)
    colBackgroundToggled: colBackground
    colBackgroundToggledHover: colBackgroundHover
    colRippleToggled: colRipple
    focusPolicy: Qt.StrongFocus
    Accessible.name: root.text

    contentItem: Item {
        implicitWidth: actionContent.implicitWidth
        implicitHeight: actionContent.implicitHeight

        RowLayout {
            id: actionContent

            anchors.centerIn: parent
            spacing: Metrics.spacingXS

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                visible: root.iconName !== ""
                text: root.iconName
                iconSize: Metrics.iconS + Metrics.spacingXXS
                color: root.filled ? Appearance.colors.colOnPrimary : Appearance.colors.colPrimary
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: root.text
                color: root.filled ? Appearance.colors.colOnPrimary : Appearance.colors.colPrimary
                font.family: Typography.labelLarge.family
                font.pixelSize: Typography.labelLarge.pixelSize
                font.weight: Typography.labelLarge.weight
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

}
