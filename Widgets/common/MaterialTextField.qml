import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import qs.Common

TextField {
    id: root

    property bool error: false
    readonly property bool fieldHovered: fieldHover.containsMouse

    implicitHeight: Metrics.controlHeightXL
    property bool blinkOn: true
    renderType: Text.QtRendering
    selectedTextColor: Appearance.colors.colOnPrimaryContainer
    selectionColor: Appearance.colors.colPrimaryContainer
    placeholderTextColor: Appearance.colors.colOnSurfaceVariant
    clip: true
    selectByMouse: true
    wrapMode: TextInput.NoWrap
    verticalAlignment: TextInput.AlignVCenter
    leftPadding: Metrics.spacingL
    rightPadding: Metrics.spacingL
    topPadding: 0
    bottomPadding: 0
    activeFocusOnTab: true

    font {
        family: Typography.bodyLarge.family
        pixelSize: Typography.bodyLarge.pixelSize
        weight: Typography.bodyLarge.weight
        hintingPreference: Font.PreferFullHinting
    }

    background: Rectangle {
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer1
        border.width: root.error || root.activeFocus ? 2 : 1
        border.color: root.error
            ? Appearance.colors.colError
            : root.activeFocus
                ? Appearance.colors.colPrimary
                : root.fieldHovered
                    ? Appearance.colors.colOutline
                    : Appearance.colors.colOutlineVariant
        antialiasing: true

        Behavior on border.color {
            ColorAnimation {
                duration: Appearance.animation.expressiveFastEffects.duration
                easing.type: Appearance.animation.expressiveFastEffects.type
                easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
            }
        }

        Behavior on border.width {
            NumberAnimation {
                duration: Appearance.animation.expressiveFastEffects.duration
                easing.type: Appearance.animation.expressiveFastEffects.type
                easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
            }
        }
    }

    cursorDelegate: Rectangle {
        width: 2
        height: Math.max(18, root.font.pixelSize * 1.25)
        radius: 1
        color: Appearance.colors.colPrimary
        visible: root.activeFocus && root.blinkOn
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

    MouseArea {
        id: fieldHover

        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        cursorShape: Qt.IBeamCursor
    }
}
