import QtQuick
import QtQuick.Controls
import qs.Common

Button {
    id: root

    property bool toggled: false
    property bool pointingHandCursor: true
    property real buttonRadius: height / 2
    property color containerColor: Appearance.colors.colLayer1
    property color rippleColor: Appearance.colors.colOnLayer1
    property int rippleDuration: 700
    property real rippleOpacity: 0.22
    property bool pointerPressActive: false
    property bool dispatchingPointerClick: false
    property var downAction
    property var releaseAction
    property var doubleClickAction
    property var altAction
    property var middleClickAction
    readonly property bool pointerHovered: pointerArea.containsMouse

    function startRipple(x, y) {
        ripple.centerX = x;
        ripple.centerY = y;
        rippleAnimation.diameter = Math.sqrt(width * width + height * height) * 2.2;
        rippleAnimation.restart();
    }

    hoverEnabled: true
    opacity: enabled ? 1 : 0.4
    onClicked: {
        if (!root.pointerPressActive && !root.dispatchingPointerClick && root.releaseAction)
            root.releaseAction(null);

    }

    MouseArea {
        id: pointerArea

        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: root.pointingHandCursor ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: (event) => {
            if (event.button === Qt.RightButton) {
                if (root.altAction)
                    root.altAction(event);

                return ;
            }
            if (event.button === Qt.MiddleButton) {
                if (root.middleClickAction)
                    root.middleClickAction(event);

                return ;
            }
            root.pointerPressActive = true;
            root.down = true;
            if (root.downAction)
                root.downAction(event);

            root.startRipple(event.x, event.y);
        }
        onReleased: (event) => {
            root.down = false;
            root.pointerPressActive = false;
            if (event.button !== Qt.LeftButton)
                return ;

            if (root.releaseAction)
                root.releaseAction(event);

            root.dispatchingPointerClick = true;
            root.click();
            root.dispatchingPointerClick = false;
        }
        onDoubleClicked: (event) => {
            if (event.button === Qt.LeftButton && root.doubleClickAction)
                root.doubleClickAction(event);

        }
        onCanceled: {
            root.down = false;
            root.pointerPressActive = false;
        }
    }

    background: Rectangle {
        id: background

        radius: root.buttonRadius
        color: root.containerColor
        clip: true

        Rectangle {
            id: ripple

            property real centerX: background.width / 2
            property real centerY: background.height / 2
            property real diameter: 0

            x: centerX - width / 2
            y: centerY - height / 2
            width: diameter
            height: diameter
            radius: width / 2
            color: root.rippleColor
            opacity: 0
            visible: opacity > 0
        }

        ParallelAnimation {
            id: rippleAnimation

            property real diameter: 0

            NumberAnimation {
                target: ripple
                property: "diameter"
                from: 0
                to: rippleAnimation.diameter
                duration: root.rippleDuration
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: ripple
                property: "opacity"
                from: root.rippleOpacity
                to: 0
                duration: root.rippleDuration
                easing.type: Easing.OutCubic
            }

        }

    }

}
