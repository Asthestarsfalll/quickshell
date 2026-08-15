import QtQuick
import qs.Common

Item {
    id: root

    property color color: Appearance.colors.colOnSurface
    property real effectOpacity: Appearance.interaction.rippleOpacity
    property int duration: Appearance.interaction.rippleDuration
    property int easingType: Appearance.interaction.rippleEasing
    property real shapeRadius: 0
    property real targetDiameter: 0
    readonly property bool active: rippleAnimation.running || rippleFadeAnimation.running || ripple.opacity > 0

    function clear() {
        rippleAnimation.stop();
        rippleFadeAnimation.stop();
        ripple.diameter = 0;
        ripple.opacity = 0;
        root.targetDiameter = 0;
    }

    function startAt(x, y) {
        root.clear();
        ripple.centerX = x;
        ripple.centerY = y;
        root.targetDiameter = Math.sqrt(root.width * root.width + root.height * root.height) * 2.2;
        rippleAnimation.restart();
    }

    function finish() {
        if (root.active && !rippleAnimation.running)
            rippleFadeAnimation.restart();

    }

    onColorChanged: rippleCanvas.requestPaint()
    onShapeRadiusChanged: rippleCanvas.requestPaint()
    clip: true

    Item {
        id: ripple

        property real centerX: root.width / 2
        property real centerY: root.height / 2
        property real diameter: 0

        visible: false
        opacity: 0
        onCenterXChanged: rippleCanvas.requestPaint()
        onCenterYChanged: rippleCanvas.requestPaint()
        onDiameterChanged: rippleCanvas.requestPaint()
        onOpacityChanged: rippleCanvas.requestPaint()
    }

    Canvas {
        id: rippleCanvas

        anchors.fill: parent
        visible: root.active
        renderStrategy: Canvas.Immediate
        onVisibleChanged: {
            if (visible)
                requestPaint();

        }
        onPaint: {
            const context = getContext("2d");
            const cornerRadius = Math.min(root.shapeRadius, width / 2, height / 2);
            context.reset();
            context.beginPath();
            context.moveTo(cornerRadius, 0);
            context.lineTo(width - cornerRadius, 0);
            context.quadraticCurveTo(width, 0, width, cornerRadius);
            context.lineTo(width, height - cornerRadius);
            context.quadraticCurveTo(width, height, width - cornerRadius, height);
            context.lineTo(cornerRadius, height);
            context.quadraticCurveTo(0, height, 0, height - cornerRadius);
            context.lineTo(0, cornerRadius);
            context.quadraticCurveTo(0, 0, cornerRadius, 0);
            context.closePath();
            context.clip();
            context.globalAlpha = ripple.opacity;
            context.fillStyle = root.color;
            context.beginPath();
            context.arc(ripple.centerX, ripple.centerY, ripple.diameter / 2, 0, Math.PI * 2);
            context.fill();
        }
    }

    ParallelAnimation {
        id: rippleAnimation

        onFinished: root.clear()

        NumberAnimation {
            target: ripple
            property: "diameter"
            from: 0
            to: root.targetDiameter
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
