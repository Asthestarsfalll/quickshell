import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components

RowLayout {
    id: root

    enum Style {
        Primary,
        Tonal
    }

    property var model: []
    property var currentValue: ""
    property int buttonHeight: 36
    property int horizontalPadding: 24
    // Connected segments use square inner edges so adjacent backgrounds do
    // not expose a dark antialiased seam. Outer edges remain rounded.
    property int innerRadius: 0
    property real edgeRadius: buttonHeight / 2
    property bool originalAppearance: false
    property int pressedExpansion: 0
    property int buttonMinWidth: 0
    property int style: StyledButtonGroup.Style.Primary
    property bool iconOnly: false
    property bool roundOuterSegments: true
    property int iconSize: 21
    property int textPixelSize: 14
    property int contentSpacing: 6
    property bool fillActiveIcon: true
    property string valueRole: "value"
    property string textRole: "label"
    property string iconRole: "icon"
    property string tooltipRole: "tooltip"
    property string enabledRole: "enabled"
    property string widthRole: "width"

    signal valueSelected(var value, var modelData)

    // The former appearance intentionally keeps a small separation between
    // segments.  Each segment is still rendered independently so the gap and
    // the inner corner remain part of the control's visual language.
    spacing: root.originalAppearance ? 2 : 0

    readonly property int effectiveInnerRadius:
        root.originalAppearance && root.innerRadius === 0
            ? 6 : root.innerRadius
    readonly property int effectivePressedExpansion:
        root.originalAppearance && root.pressedExpansion === 0
            ? 10 : root.pressedExpansion

    function roleValue(item, role, fallback) {
        if (item === undefined || item === null)
            return fallback;
        const value = item[role];
        return value === undefined || value === null ? fallback : value;
    }

    function valueFor(item, index) {
        return roleValue(item, valueRole, index);
    }

    function textFor(item) {
        const value = roleValue(item, textRole, "");
        return value === undefined || value === null ? "" : String(value);
    }

    function iconFor(item) {
        const value = roleValue(item, iconRole, "");
        return value === undefined || value === null ? "" : String(value);
    }

    function tooltipFor(item) {
        const value = roleValue(item, tooltipRole, "");
        return value === undefined || value === null ? "" : String(value);
    }

    function enabledFor(item) {
        return roleValue(item, enabledRole, true);
    }

    function segmentWidth(item, labelWidth, iconWidth) {
        const explicitWidth = Number(roleValue(item, widthRole, -1));
        if (explicitWidth > 0)
            return explicitWidth;

        const labelVisible = !iconOnly && textFor(item) !== "";
        const iconVisible = iconFor(item) !== "";
        const contentWidth = (labelVisible ? labelWidth : 0)
                           + (iconVisible ? iconWidth : 0)
                           + (labelVisible && iconVisible ? contentSpacing : 0);
        return Math.max(buttonMinWidth, contentWidth + horizontalPadding);
    }

    function fillColor(active, hovered, pressed) {
        if (style === StyledButtonGroup.Style.Tonal) {
            if (active)
                return pressed ? Appearance.colors.colPrimaryContainerActive
                               : hovered ? Appearance.colors.colPrimaryContainerHover
                                         : Appearance.colors.colPrimaryContainer;
            if (root.originalAppearance)
                return pressed ? Appearance.colors.colLayer4Active
                               : hovered ? Appearance.colors.colLayer4
                                         : Appearance.colors.colLayer2;
            return pressed ? Appearance.colors.colSecondaryContainerActive
                           : hovered ? Appearance.colors.colSecondaryContainerHover
                                     : Appearance.colors.colSecondaryContainer;
        }

        if (active)
            return pressed ? Appearance.colors.colPrimaryActive
                           : hovered ? Appearance.colors.colPrimaryHover
                                     : Appearance.colors.colPrimary;
        return pressed ? Appearance.colors.colSecondaryContainerActive
                       : hovered ? Appearance.colors.colSecondaryContainerHover
                                 : Appearance.colors.colSecondaryContainer;
    }

    function contentColor(active) {
        if (style === StyledButtonGroup.Style.Tonal)
            return active ? Appearance.colors.colOnPrimaryContainer
                          : root.originalAppearance
                            ? Appearance.colors.colOnSurfaceVariant
                            : Appearance.colors.colOnSecondaryContainer;
        return active ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer;
    }

    Repeater {
        model: root.model

        delegate: Item {
            id: segment

            required property int index
            required property var modelData

            readonly property var segmentValue: root.valueFor(modelData, index)
            readonly property bool segmentEnabled: root.enabledFor(modelData)
            readonly property bool active: root.currentValue === segmentValue
            readonly property bool first: index === 0
            readonly property bool last: index === root.model.length - 1
            readonly property bool pressed: segmentMouse.pressed && segmentEnabled
            readonly property bool hovered: segmentMouse.containsMouse && segmentEnabled
            readonly property real leftRadius: (active
                || (root.roundOuterSegments && first)
                || (pressed && root.effectivePressedExpansion > 0))
                    ? root.edgeRadius : root.effectiveInnerRadius
            readonly property real rightRadius: (active
                || (root.roundOuterSegments && last)
                || (pressed && root.effectivePressedExpansion > 0))
                    ? root.edgeRadius : root.effectiveInnerRadius
            readonly property color segmentColor: root.fillColor(active, hovered, pressed)
            readonly property color inkColor: root.contentColor(active)
            readonly property string labelText: root.textFor(modelData)
            readonly property string iconText: root.iconFor(modelData)
            readonly property string tooltipText: root.tooltipFor(modelData)

            Layout.preferredWidth: root.segmentWidth(modelData,
                label.implicitWidth, root.iconSize)
                + (pressed ? root.effectivePressedExpansion : 0)
            Layout.preferredHeight: root.buttonHeight
            opacity: segmentEnabled ? 1 : 0.45
            scale: pressed && root.effectivePressedExpansion > 0 ? 0.97 : 1
            z: pressed ? 3 : active ? 2 : hovered ? 1 : 0

            Behavior on Layout.preferredWidth {
                NumberAnimation {
                    duration: Appearance.animation.elementResize.duration
                    easing.type: Appearance.animation.elementResize.type
                    easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.animation.clickBounce.duration
                    easing.type: Appearance.animation.clickBounce.type
                    easing.bezierCurve: Appearance.animation.clickBounce.bezierCurve
                }
            }

            Rectangle {
                anchors.fill: parent
                topLeftRadius: segment.leftRadius
                topRightRadius: segment.rightRadius
                bottomLeftRadius: segment.leftRadius
                bottomRightRadius: segment.rightRadius
                color: segment.segmentColor
                antialiasing: true

                Behavior on topLeftRadius {
                    NumberAnimation {
                        duration: Appearance.animation.elementResize.duration
                        easing.type: Appearance.animation.elementResize.type
                        easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.animation.expressiveEffects.duration
                        easing.type: Appearance.animation.expressiveEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                    }
                }

                Behavior on topRightRadius {
                    NumberAnimation {
                        duration: Appearance.animation.elementResize.duration
                        easing.type: Appearance.animation.elementResize.type
                        easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                    }
                }

                Behavior on bottomLeftRadius {
                    NumberAnimation {
                        duration: Appearance.animation.elementResize.duration
                        easing.type: Appearance.animation.elementResize.type
                        easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                    }
                }

                Behavior on bottomRightRadius {
                    NumberAnimation {
                        duration: Appearance.animation.elementResize.duration
                        easing.type: Appearance.animation.elementResize.type
                        easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                    }
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: root.contentSpacing

                MaterialSymbol {
                    text: segment.iconText
                    iconSize: root.iconSize
                    fill: segment.active && root.fillActiveIcon ? 1 : 0
                    color: segment.inkColor
                    visible: segment.iconText !== ""
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.animation.expressiveEffects.duration
                            easing.type: Appearance.animation.expressiveEffects.type
                            easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                        }
                    }
                }

                Text {
                    id: label

                    text: segment.labelText
                    visible: !root.iconOnly && segment.labelText !== ""
                    color: segment.inkColor
                    font.family: Fonts.ui
                    font.pixelSize: root.textPixelSize
                    font.weight: segment.active ? Font.Medium : Font.Normal
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.animation.expressiveEffects.duration
                            easing.type: Appearance.animation.expressiveEffects.type
                            easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                        }
                    }
                }
            }

            MouseArea {
                id: segmentMouse

                anchors.fill: parent
                enabled: segment.segmentEnabled
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.valueSelected(segment.segmentValue, segment.modelData)
                z: 3
            }

            StyledToolTip {
                extraVisibleCondition: segmentMouse.containsMouse && segment.tooltipText !== ""
                text: segment.tooltipText
            }
        }
    }
}
