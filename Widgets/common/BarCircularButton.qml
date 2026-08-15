import QtQuick
import qs.Common
import qs.Components

Item {
    id: root

    property string iconName: ""
    property string tooltipText: ""
    property bool selected: false
    property real baseSize: Sizes.barControlCircleSize
    property real hoverSize: 34
    property real iconSize: root.pointerHovered ? 20 : 18
    property real iconFill: root.selected ? 1 : 0
    property color containerColor: Appearance.colors.colPrimaryContainer
    property color hoverContainerColor: Appearance.colors.colPrimaryContainer
    property color pressedContainerColor: root.hoverContainerColor
    property color selectedContainerColor: root.containerColor
    property color selectedHoverContainerColor: root.hoverContainerColor
    property color selectedPressedContainerColor: root.pressedContainerColor
    property color iconColor: Appearance.colors.colOnPrimaryContainer
    property color selectedIconColor: root.iconColor
    property var downAction
    property var releaseAction
    property var doubleClickAction
    property var altAction
    property var middleClickAction
    readonly property bool pointerHovered: button.pointerHovered
    readonly property bool pressed: button.down

    signal clicked(var event)
    signal doubleClicked(var event)
    signal altClicked(var event)
    signal middleClicked(var event)

    implicitWidth: root.baseSize
    implicitHeight: root.baseSize
    Accessible.name: root.tooltipText
    Accessible.role: Accessible.Button

    MaterialRippleButton {
        id: button

        anchors.centerIn: parent
        width: root.pointerHovered ? root.hoverSize : root.baseSize
        height: width
        enabled: root.enabled
        toggled: root.selected
        buttonRadius: width / 2
        buttonRadiusPressed: width / 2
        colBackground: root.containerColor
        colBackgroundHover: root.pressed ? root.pressedContainerColor : root.hoverContainerColor
        colBackgroundToggled: root.selectedContainerColor
        colBackgroundToggledHover: root.pressed ? root.selectedPressedContainerColor : root.selectedHoverContainerColor
        colRipple: Appearance.applyAlpha(root.iconColor, 0.16)
        colRippleToggled: Appearance.applyAlpha(root.selectedIconColor, 0.16)
        downAction: (event) => {
            if (root.downAction)
                root.downAction(event);

        }
        releaseAction: (event) => {
            if (root.releaseAction)
                root.releaseAction(event);

            root.clicked(event);
        }
        doubleClickAction: (event) => {
            if (root.doubleClickAction)
                root.doubleClickAction(event);

            root.doubleClicked(event);
        }
        altAction: (event) => {
            if (root.altAction)
                root.altAction(event);

            root.altClicked(event);
        }
        middleClickAction: (event) => {
            if (root.middleClickAction)
                root.middleClickAction(event);

            root.middleClicked(event);
        }

        Behavior on width {
            NumberAnimation {
                duration: Appearance.animation.expressiveFastEffects.duration
                easing.type: Appearance.animation.expressiveFastEffects.type
                easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
            }

        }

        contentItem: MaterialSymbol {
            text: root.iconName
            iconSize: root.iconSize
            fill: root.iconFill
            color: root.selected ? root.selectedIconColor : root.iconColor

            Behavior on iconSize {
                NumberAnimation {
                    duration: Appearance.animation.expressiveFastEffects.duration
                    easing.type: Appearance.animation.expressiveFastEffects.type
                    easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                }

            }

        }

    }

    StyledToolTip {
        text: root.tooltipText
        extraVisibleCondition: root.tooltipText.length > 0 && root.pointerHovered
    }

}
