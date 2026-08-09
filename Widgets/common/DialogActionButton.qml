import QtQuick
import QtQuick.Controls
import qs.Common

MaterialRippleButton {
    id: root

    property bool filled: false

    implicitWidth: Math.max(64,
        label.implicitWidth + Metrics.spacingL)
    implicitHeight: Metrics.controlHeightM
    buttonRadius: Appearance.rounding.full
    buttonRadiusPressed: Appearance.rounding.full
    leftPadding: Metrics.spacingM
    rightPadding: Metrics.spacingM
    colBackground: filled
        ? Appearance.colors.colPrimary : "transparent"
    colBackgroundHover: filled
        ? Appearance.colors.colPrimaryHover
        : Appearance.applyAlpha(Appearance.colors.colPrimary, 0.08)
    colRipple: filled
        ? Appearance.applyAlpha(Appearance.colors.colOnPrimary, 0.12)
        : Appearance.applyAlpha(Appearance.colors.colPrimary, 0.12)
    colBackgroundToggled: colBackground
    colBackgroundToggledHover: colBackgroundHover
    colRippleToggled: colRipple
    focusPolicy: Qt.StrongFocus
    Accessible.name: root.text

    backgroundContent: Rectangle {
        anchors.fill: parent
        radius: root.buttonEffectiveRadius
        color: "transparent"
        border.width: root.activeFocus ? 2 : 0
        border.color: Appearance.colors.colPrimary
        antialiasing: true
    }

    contentItem: Text {
        id: label

        text: root.text
        anchors.centerIn: parent
        color: root.filled
            ? Appearance.colors.colOnPrimary
            : Appearance.colors.colPrimary
        font.family: Typography.labelLarge.family
        font.pixelSize: Typography.labelLarge.pixelSize
        font.weight: Typography.labelLarge.weight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
