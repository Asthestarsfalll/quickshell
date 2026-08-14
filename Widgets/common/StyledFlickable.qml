import QtQuick
import QtQuick.Controls
import qs.Common

Flickable {
    id: root

    clip: true
    maximumFlickVelocity: 3500
    boundsBehavior: Flickable.DragOverBounds

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
            // A new wheel event replaces the running destination instead of
            // queueing the previous one to completion first.
            alwaysRunToEnd: false
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
}
