import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import qs.Common

TextField {
    id: root

    // The inherited TextField remains responsible for editing, selection,
    // IME, password echo, keyboard navigation, and accessibility. This
    // component owns the complete visual treatment around that editor.
    property bool error: false
    property string labelText: ""
    property bool compact: false
    property color containerColor: Appearance.colors.colLayer1
    property Component leadingContent
    property Component trailingContent
    property real leadingContentWidth: Metrics.iconM
    property real trailingContentWidth: Metrics.touchTarget
    property bool blinkOn: true

    readonly property string effectiveLabel: String(root.labelText || "")
        .trim() !== ""
        ? String(root.labelText)
        : String(root.placeholderText || "")
    readonly property bool labelFloating: !root.compact
        && (root.activeFocus || String(root.text || "").length > 0)
    readonly property bool fieldHovered: fieldHover.hovered
    readonly property bool hasLeadingContent:
        root.leadingContent !== null && root.leadingContent !== undefined
    readonly property bool hasTrailingContent:
        root.trailingContent !== null && root.trailingContent !== undefined
    readonly property real baseHorizontalPadding: Metrics.spacingL
    readonly property real labelX: root.leftPadding
    readonly property real labelCenterY: root.labelFloating
        ? root.outlineWidth / 2 : root.height / 2
    readonly property real notchPadding: Metrics.spacingXS
    readonly property real notchWidth: floatingLabel.width
        + root.notchPadding * 2
    readonly property real outlineInset: root.outlineWidth / 2
    readonly property real outlineCornerRadius: Math.max(0,
        root.cornerRadius - root.outlineInset)
    readonly property real notchLeft: Math.max(root.outlineInset
        + root.outlineCornerRadius, root.labelX - root.notchPadding)
    readonly property real notchRight: Math.min(root.width - root.outlineInset
        - root.outlineCornerRadius, root.labelX + floatingLabel.width
        + root.notchPadding)
    readonly property real outlineWidth: !root.enabled
        ? 1 : root.error || root.activeFocus ? 2 : 1
    readonly property real cornerRadius: Metrics.cornerXS
    readonly property color effectiveContainerColor: root.enabled
        ? root.containerColor
        : Appearance.mix(root.containerColor,
            Appearance.colors.colOnSurface, 0.96)
    readonly property color outlineColor: !root.enabled
        ? Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.38)
        : root.error
            ? Appearance.colors.colError
            : root.activeFocus
                ? Appearance.colors.colPrimary
                : root.fieldHovered
                    ? Appearance.colors.colOutline
                    : Appearance.colors.colOutlineVariant
    readonly property color labelColor: !root.enabled
        ? Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.38)
        : root.error
            ? Appearance.colors.colError
            : root.activeFocus
                ? Appearance.colors.colPrimary
                : Appearance.colors.colOnSurfaceVariant
    readonly property color inputColor: root.enabled
        ? Appearance.colors.colOnSurface
        : Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.38)

    implicitHeight: root.compact
        ? Metrics.controlHeightS + Metrics.spacingXS
        : Metrics.controlHeightXL
    renderType: Text.QtRendering
    selectByMouse: true
    wrapMode: TextInput.NoWrap
    activeFocusOnTab: true
    clip: false

    // Native placeholder text is transparent for the standard variant. The
    // visible label below is the only label renderer, avoiding a second Qt
    // Material floating-label implementation with different geometry.
    placeholderTextColor: root.compact
        ? Appearance.colors.colOnSurfaceVariant
        : "transparent"
    verticalAlignment: TextInput.AlignVCenter
    leftPadding: root.baseHorizontalPadding
        + (root.hasLeadingContent
            ? root.leadingContentWidth + Metrics.spacingXS : 0)
    rightPadding: root.baseHorizontalPadding
        + (root.hasTrailingContent
            ? root.trailingContentWidth + Metrics.spacingXS : 0)
    topPadding: root.compact
        ? 0 : root.labelFloating ? Metrics.spacingS : 0
    bottomPadding: 0
    color: root.inputColor
    selectedTextColor: Appearance.colors.colOnPrimaryContainer
    selectionColor: Appearance.colors.colPrimaryContainer

    font {
        family: Typography.bodyLarge.family
        pixelSize: Typography.bodyLarge.pixelSize
        weight: Typography.bodyLarge.weight
        hintingPreference: Font.PreferFullHinting
    }

    background: Item {
        id: fieldBackground

        anchors.fill: parent

        Rectangle {
            id: surface

            anchors.fill: parent
            radius: root.cornerRadius
            color: root.effectiveContainerColor
        }

        // Draw the outline as a path instead of masking a complete border.
        // A surface-coloured rectangle is not a reliable notch: it can blend
        // differently from the field on translucent or error surfaces and the
        // original outline can still show through at the label edges.
        Shape {
            id: completeOutline

            anchors.fill: parent
            visible: !root.labelFloating || !floatingLabel.visible
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                capStyle: ShapePath.SquareCap
                joinStyle: ShapePath.RoundJoin
                strokeWidth: root.outlineWidth
                strokeColor: root.outlineColor
                fillColor: "transparent"
                startX: root.outlineInset + root.outlineCornerRadius
                startY: root.outlineInset

                PathLine {
                    x: root.width - root.outlineInset
                        - root.outlineCornerRadius
                    y: root.outlineInset
                }
                PathArc {
                    x: root.width - root.outlineInset
                    y: root.outlineInset + root.outlineCornerRadius
                    radiusX: root.outlineCornerRadius
                    radiusY: root.outlineCornerRadius
                }
                PathLine {
                    x: root.width - root.outlineInset
                    y: root.height - root.outlineInset
                        - root.outlineCornerRadius
                }
                PathArc {
                    x: root.width - root.outlineInset
                        - root.outlineCornerRadius
                    y: root.height - root.outlineInset
                    radiusX: root.outlineCornerRadius
                    radiusY: root.outlineCornerRadius
                }
                PathLine {
                    x: root.outlineInset + root.outlineCornerRadius
                    y: root.height - root.outlineInset
                }
                PathArc {
                    x: root.outlineInset
                    y: root.height - root.outlineInset
                        - root.outlineCornerRadius
                    radiusX: root.outlineCornerRadius
                    radiusY: root.outlineCornerRadius
                }
                PathLine {
                    x: root.outlineInset
                    y: root.outlineInset + root.outlineCornerRadius
                }
                PathArc {
                    x: root.outlineInset + root.outlineCornerRadius
                    y: root.outlineInset
                    radiusX: root.outlineCornerRadius
                    radiusY: root.outlineCornerRadius
                }

                Behavior on strokeColor {
                    ColorAnimation {
                        duration: Appearance.animation.expressiveFastEffects.duration
                        easing.type: Appearance.animation.expressiveFastEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                    }
                }

                Behavior on strokeWidth {
                    NumberAnimation {
                        duration: Appearance.animation.expressiveFastEffects.duration
                        easing.type: Appearance.animation.expressiveFastEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                    }
                }
            }
        }

        Shape {
            id: notchedOutline

            anchors.fill: parent
            visible: root.labelFloating && floatingLabel.visible
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                capStyle: ShapePath.SquareCap
                joinStyle: ShapePath.RoundJoin
                strokeWidth: root.outlineWidth
                strokeColor: root.outlineColor
                fillColor: "transparent"
                startX: root.notchRight
                startY: root.outlineInset

                PathLine {
                    x: root.width - root.outlineInset
                        - root.outlineCornerRadius
                    y: root.outlineInset
                }
                PathArc {
                    x: root.width - root.outlineInset
                    y: root.outlineInset + root.outlineCornerRadius
                    radiusX: root.outlineCornerRadius
                    radiusY: root.outlineCornerRadius
                }
                PathLine {
                    x: root.width - root.outlineInset
                    y: root.height - root.outlineInset
                        - root.outlineCornerRadius
                }
                PathArc {
                    x: root.width - root.outlineInset
                        - root.outlineCornerRadius
                    y: root.height - root.outlineInset
                    radiusX: root.outlineCornerRadius
                    radiusY: root.outlineCornerRadius
                }
                PathLine {
                    x: root.outlineInset + root.outlineCornerRadius
                    y: root.height - root.outlineInset
                }
                PathArc {
                    x: root.outlineInset
                    y: root.height - root.outlineInset
                        - root.outlineCornerRadius
                    radiusX: root.outlineCornerRadius
                    radiusY: root.outlineCornerRadius
                }
                PathLine {
                    x: root.outlineInset
                    y: root.outlineInset + root.outlineCornerRadius
                }
                PathArc {
                    x: root.outlineInset + root.outlineCornerRadius
                    y: root.outlineInset
                    radiusX: root.outlineCornerRadius
                    radiusY: root.outlineCornerRadius
                }
                PathLine {
                    x: root.notchLeft
                    y: root.outlineInset
                }

                Behavior on strokeColor {
                    ColorAnimation {
                        duration: Appearance.animation.expressiveFastEffects.duration
                        easing.type: Appearance.animation.expressiveFastEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                    }
                }

                Behavior on strokeWidth {
                    NumberAnimation {
                        duration: Appearance.animation.expressiveFastEffects.duration
                        easing.type: Appearance.animation.expressiveFastEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                    }
                }
            }
        }
    }

    Text {
        id: floatingLabel

        x: root.labelX
        y: root.labelCenterY - height / 2
        width: Math.min(implicitWidth,
            Math.max(0, root.width - root.labelX
                - root.rightPadding - root.notchPadding * 2))
        visible: !root.compact && root.effectiveLabel.length > 0
        text: root.effectiveLabel
        color: root.labelColor
        font.family: root.labelFloating
            ? Typography.bodySmall.family : Typography.bodyLarge.family
        font.pixelSize: root.labelFloating
            ? Typography.bodySmall.pixelSize : Typography.bodyLarge.pixelSize
        font.weight: root.labelFloating
            ? Typography.bodySmall.weight : Typography.bodyLarge.weight
        font.hintingPreference: Font.PreferFullHinting
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignLeft
        verticalAlignment: Text.AlignVCenter
        z: 20

        Behavior on x {
            NumberAnimation {
                duration: Appearance.animation.expressiveFastEffects.duration
                easing.type: Appearance.animation.expressiveFastEffects.type
                easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
            }
        }

        Behavior on y {
            NumberAnimation {
                duration: Appearance.animation.expressiveFastEffects.duration
                easing.type: Appearance.animation.expressiveFastEffects.type
                easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
            }
        }

        Behavior on font.pixelSize {
            NumberAnimation {
                duration: Appearance.animation.expressiveFastEffects.duration
                easing.type: Appearance.animation.expressiveFastEffects.type
                easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Appearance.animation.expressiveFastEffects.duration
                easing.type: Appearance.animation.expressiveFastEffects.type
                easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
            }
        }
    }

    Loader {
        id: leadingLoader

        anchors.left: parent.left
        anchors.leftMargin: root.baseHorizontalPadding
        anchors.verticalCenter: parent.verticalCenter
        width: root.hasLeadingContent ? root.leadingContentWidth : 0
        height: root.hasLeadingContent
            ? Math.min(root.height, Metrics.touchTarget) : 0
        sourceComponent: root.leadingContent
        z: 20
    }

    Loader {
        id: trailingLoader

        anchors.right: parent.right
        anchors.rightMargin: Metrics.spacingXS
        anchors.verticalCenter: parent.verticalCenter
        width: root.hasTrailingContent ? root.trailingContentWidth : 0
        height: root.hasTrailingContent
            ? Math.min(root.height, Metrics.touchTarget) : 0
        sourceComponent: root.trailingContent
        z: 20
    }

    cursorDelegate: Rectangle {
        width: 2
        height: Math.max(18, root.font.pixelSize * 1.25)
        radius: 1
        color: Appearance.colors.colPrimary
        visible: root.activeFocus && !root.readOnly && root.blinkOn
    }

    onActiveFocusChanged: {
        root.blinkOn = true;
        if (activeFocus)
            cursorBlinkTimer.restart();
        else
            cursorBlinkTimer.stop();
    }

    Timer {
        id: cursorBlinkTimer

        interval: 530
        repeat: true
        running: root.activeFocus
        onTriggered: root.blinkOn = !root.blinkOn
    }

    HoverHandler {
        id: fieldHover

        enabled: root.enabled
        cursorShape: Qt.IBeamCursor
    }
}
