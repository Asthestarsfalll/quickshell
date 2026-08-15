import QtQuick
import Qt5Compat.GraphicalEffects
import qs.Common

Item {
    id: root

    property color color: Appearance.colors.colOnSurface
    property real effectOpacity: Appearance.interaction.rippleOpacity
    property int duration: Appearance.interaction.rippleDuration
    property int easingType: Appearance.interaction.rippleEasing
    property real shapeRadius: 0
    readonly property bool active: ripple.visible

    function clear() {
        rippleAnimation.stop();
        rippleFadeAnimation.stop();
        ripple.visible = false;
        ripple.diameter = 0;
        ripple.opacity = 0;
    }

    function startAt(x, y) {
        root.clear();
        ripple.centerX = x;
        ripple.centerY = y;
        ripple.diameter = Math.sqrt(root.width * root.width + root.height * root.height) * 2.2;
        ripple.visible = true;
        rippleAnimation.restart();
    }

    function finish() {
        if (ripple.visible && !rippleAnimation.running)
            rippleFadeAnimation.restart();

    }

    Item {
        id: rippleSource

        anchors.fill: parent
        visible: true

        Rectangle {
            id: ripple

            property real centerX: root.width / 2
            property real centerY: root.height / 2
            property real diameter: 0

            x: centerX - width / 2
            y: centerY - height / 2
            width: diameter
            height: diameter
            radius: width / 2
            color: root.color
            opacity: 0
            visible: false
        }

    }

    OpacityMask {
        anchors.fill: parent
        source: rippleSource
        maskSource: roundedMask
        hideSource: true
        visible: ripple.visible
    }

    Rectangle {
        id: roundedMask

        anchors.fill: parent
        radius: root.shapeRadius
        color: "white"
        visible: false
    }

    ParallelAnimation {
        id: rippleAnimation

        onFinished: root.clear()

        NumberAnimation {
            target: ripple
            property: "diameter"
            from: 0
            to: ripple.diameter
            duration: root.duration
            easing.type: root.easingType
        }

        NumberAnimation {
            target: ripple
            property: "opacity"
            from: root.effectOpacity
            to: 0
            duration: root.duration
            easing.type: root.easingType
        }

    }

    NumberAnimation {
        id: rippleFadeAnimation

        target: ripple
        property: "opacity"
        to: 0
        duration: root.duration
        easing.type: root.easingType
        onFinished: root.clear()
    }

}
