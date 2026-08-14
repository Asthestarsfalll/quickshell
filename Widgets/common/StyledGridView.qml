import QtQuick
import QtQuick.Controls
import qs.Common

GridView {
    id: root

    clip: true
    keyNavigationWraps: true
    maximumFlickVelocity: 3500
    boundsBehavior: Flickable.DragOverBounds

    property real removeOvershoot: 20
    property bool popin: true
    property bool animateAppearance: true
    property bool animateMovement: false
    // Keep the default path native. This opt-in path is only for views that
    // explicitly need the accelerated touchpad wheel handling.
    property bool fasterTouchpadScroll: false
    property bool showVerticalScrollBar: true
    readonly property real mouseScrollDeltaThreshold: 120
    readonly property real mouseScrollFactor: 120
    readonly property real touchpadScrollFactor: 450
    // Only used while fasterTouchpadScroll is enabled.
    property real scrollTargetY: 0

    function maxContentY() {
        return Math.max(0, root.contentHeight - root.height);
    }

    function clampContentY(value) {
        return Math.max(0, Math.min(value, root.maxContentY()));
    }

    function wheelDeltaY(wheelEvent) {
        const pixelDeltaY = Number(wheelEvent.pixelDelta.y);
        if (isFinite(pixelDeltaY) && pixelDeltaY !== 0)
            return -pixelDeltaY;

        const angleDeltaY = Number(wheelEvent.angleDelta.y);
        if (!isFinite(angleDeltaY) || angleDeltaY === 0)
            return 0;

        const normalizedDelta = angleDeltaY / Math.max(1, root.mouseScrollDeltaThreshold);
        const factor = Math.abs(angleDeltaY) >= root.mouseScrollDeltaThreshold
                       ? root.mouseScrollFactor
                       : root.touchpadScrollFactor;
        return -normalizedDelta * factor;
    }

    function handleWheel(wheelEvent) {
        if (!root.fasterTouchpadScroll)
            return;

        const delta = root.wheelDeltaY(wheelEvent);
        if (delta === 0)
            return;

        const base = scrollAnimation.running ? root.scrollTargetY : root.contentY;
        root.scrollTargetY = root.clampContentY(base + delta);
        root.contentY = root.scrollTargetY;
        wheelEvent.accepted = true;
    }

    ScrollBar.vertical: StyledScrollBar {
        policy: root.showVerticalScrollBar ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
    }

    MouseArea {
        anchors.fill: parent
        visible: root.fasterTouchpadScroll
        acceptedButtons: Qt.NoButton
        onWheel: wheelEvent => root.handleWheel(wheelEvent)
    }

    Behavior on contentY {
        enabled: root.fasterTouchpadScroll
        NumberAnimation {
            id: scrollAnimation
            alwaysRunToEnd: true
            duration: Appearance.animation.scroll.duration
            easing.type: Appearance.animation.scroll.type
            easing.bezierCurve: Appearance.animation.scroll.bezierCurve
        }
    }

    onContentYChanged: {
        if (root.fasterTouchpadScroll && !scrollAnimation.running)
            root.scrollTargetY = root.contentY;
    }

    onContentHeightChanged: {
        if (!root.fasterTouchpadScroll)
            return;

        root.scrollTargetY = root.clampContentY(root.scrollTargetY);
        if (root.contentY > root.maxContentY())
            root.contentY = root.maxContentY();
    }

    Component {
        id: elementMoveAnimation

        ElementMoveAnimation {}
    }

    add: Transition {
        animations: root.animateAppearance ? [
            elementMoveAnimation.createObject(this, {
                properties: root.popin ? "opacity,scale" : "opacity",
                from: 0,
                to: 1,
            }),
        ] : []
    }

    addDisplaced: Transition {
        animations: root.animateAppearance ? [
            elementMoveAnimation.createObject(this, {
                properties: "x,y",
            }),
            elementMoveAnimation.createObject(this, {
                properties: root.popin ? "opacity,scale" : "opacity",
                to: 1,
            }),
        ] : []
    }

    displaced: Transition {
        animations: root.animateMovement ? [
            elementMoveAnimation.createObject(this, {
                properties: "x,y",
            }),
            elementMoveAnimation.createObject(this, {
                properties: "opacity,scale",
                to: 1,
            }),
        ] : []
    }

    move: Transition {
        animations: root.animateMovement ? [
            elementMoveAnimation.createObject(this, {
                properties: "x,y",
            }),
            elementMoveAnimation.createObject(this, {
                properties: "opacity,scale",
                to: 1,
            }),
        ] : []
    }

    moveDisplaced: Transition {
        animations: root.animateMovement ? [
            elementMoveAnimation.createObject(this, {
                properties: "x,y",
            }),
            elementMoveAnimation.createObject(this, {
                properties: "opacity,scale",
                to: 1,
            }),
        ] : []
    }

    remove: Transition {
        animations: root.animateAppearance ? [
            elementMoveAnimation.createObject(this, {
                property: "x",
                to: root.width + root.removeOvershoot,
            }),
            elementMoveAnimation.createObject(this, {
                property: "opacity",
                to: 0,
            }),
        ] : []
    }

    removeDisplaced: Transition {
        animations: root.animateAppearance ? [
            elementMoveAnimation.createObject(this, {
                properties: "x,y",
            }),
            elementMoveAnimation.createObject(this, {
                properties: "opacity,scale",
                to: 1,
            }),
        ] : []
    }
}
