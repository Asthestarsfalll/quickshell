import QtQuick
import qs.Common
import qs.Components

MaterialRippleButton {
    id: root

    property string iconName: ""
    property string selectedIconName: ""
    property string accessibleName: ""
    property string tooltipText: ""
    property string variant: "standard"
    property bool selected: false
    readonly property string effectiveAccessibleName: accessibleName.length > 0 ? accessibleName : tooltipText
    readonly property string effectiveTooltipText: tooltipText.length > 0 ? tooltipText : accessibleName
    property bool showTooltip: effectiveTooltipText.length > 0
    property real controlSize: Metrics.controlHeightM
    property real iconSize: Metrics.iconM
    property real iconFill: selected ? 1 : 0
    property real iconRotation: 0
    property color iconColor: root.variant === "filled" ? Appearance.colors.colOnPrimary : root.variant === "tonal" ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurfaceVariant
    property color selectedIconColor: root.variant === "filled" ? Appearance.colors.colOnPrimary : Appearance.colors.colPrimary
    property color containerColor: root.variant === "filled" ? Appearance.colors.colPrimary : root.variant === "tonal" ? Appearance.colors.colSecondaryContainer : "transparent"
    property color hoverContainerColor: root.variant === "filled" ? Appearance.colors.colPrimaryHover : root.variant === "tonal" ? Appearance.colors.colSecondaryContainerHover : Appearance.applyAlpha(root.iconColor, 0.08)
    property color pressedContainerColor: root.variant === "filled" ? Appearance.colors.colPrimaryActive : root.variant === "tonal" ? Appearance.colors.colSecondaryContainerActive : Appearance.applyAlpha(root.iconColor, 0.12)
    property color selectedContainerColor: root.variant === "standard" || root.variant === "outlined" ? "transparent" : root.containerColor
    property color selectedHoverContainerColor: root.variant === "standard" || root.variant === "outlined" ? Appearance.applyAlpha(root.selectedIconColor, 0.08) : root.hoverContainerColor
    property color selectedPressedContainerColor: root.variant === "standard" || root.variant === "outlined" ? Appearance.applyAlpha(root.selectedIconColor, 0.12) : root.pressedContainerColor
    property color outlineColor: Appearance.colors.colOutline
    readonly property alias iconItem: iconGlyph

    implicitWidth: root.controlSize
    implicitHeight: root.controlSize
    padding: 0
    toggled: root.selected
    buttonRadius: Appearance.rounding.full
    buttonRadiusPressed: Appearance.rounding.full
    colBackground: root.activeFocus ? root.hoverContainerColor : root.containerColor
    colBackgroundHover: root.down ? root.pressedContainerColor : root.hoverContainerColor
    colBackgroundToggled: root.activeFocus ? root.selectedHoverContainerColor : root.selectedContainerColor
    colBackgroundToggledHover: root.down ? root.selectedPressedContainerColor : root.selectedHoverContainerColor
    colRipple: Appearance.applyAlpha(root.iconColor, 0.12)
    colRippleToggled: Appearance.applyAlpha(root.selectedIconColor, 0.12)
    focusPolicy: Qt.StrongFocus
    Accessible.name: root.effectiveAccessibleName
    Accessible.role: Accessible.Button

    StyledToolTip {
        text: root.effectiveTooltipText
        extraVisibleCondition: root.showTooltip && (root.pointerHovered || root.activeFocus)
    }

    backgroundContent: Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.full
        color: "transparent"
        border.width: root.variant === "outlined" ? Metrics.dividerWidth : 0
        border.color: root.outlineColor
    }

    contentItem: MaterialSymbol {
        id: iconGlyph

        text: root.selected && root.selectedIconName.length > 0 ? root.selectedIconName : root.iconName
        iconSize: root.iconSize
        fill: root.iconFill
        color: root.selected ? root.selectedIconColor : root.iconColor
        rotation: root.iconRotation
    }

}
