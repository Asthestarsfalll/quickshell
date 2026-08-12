import QtQuick
import qs.Common
import qs.Services
import qs.Modules.SystemCards

Item {
    id: root

    required property string tileId
    property bool active: true
    property bool dragging: false
    property bool motionEnabled: true
    readonly property bool presentationOwned:
        SystemCardDragSession.active
        && SystemCardDragSession.tileId === root.tileId
    readonly property Item contentItem: cardContent

    signal dragStarted(
        string tileId,
        Item sourceItem,
        real sidebarPointerX,
        real sidebarPointerY
    )
    signal dragMoved(
        string tileId,
        real sidebarPointerX,
        real sidebarPointerY
    )
    signal dragFinished(string tileId)
    signal dragCanceled(string tileId)

    Accessible.role: Accessible.Pane

    Behavior on x {
        enabled: root.motionEnabled && !root.dragging
        NumberAnimation {
            duration: Appearance.animation.expressiveSlowSpatial.duration
            easing.type: Appearance.animation.expressiveSlowSpatial.type
            easing.bezierCurve:
                Appearance.animation.expressiveSlowSpatial.bezierCurve
        }
    }

    Behavior on y {
        enabled: root.motionEnabled && !root.dragging
        NumberAnimation {
            duration: Appearance.animation.expressiveSlowSpatial.duration
            easing.type: Appearance.animation.expressiveSlowSpatial.type
            easing.bezierCurve:
                Appearance.animation.expressiveSlowSpatial.bezierCurve
        }
    }

    Behavior on width {
        enabled: root.motionEnabled && !root.dragging
        NumberAnimation {
            duration: Appearance.animation.expressiveEffects.duration
            easing.type: Appearance.animation.expressiveEffects.type
            easing.bezierCurve:
                Appearance.animation.expressiveEffects.bezierCurve
        }
    }

    Behavior on height {
        enabled: root.motionEnabled && !root.dragging
        NumberAnimation {
            duration: Appearance.animation.expressiveEffects.duration
            easing.type: Appearance.animation.expressiveEffects.type
            easing.bezierCurve:
                Appearance.animation.expressiveEffects.bezierCurve
        }
    }

    // Only cards opted into the new shell-managed surface receive a backing
    // rectangle.  The first six cards retain their original backgrounds.
    Rectangle {
        anchors.fill: parent
        visible: !root.presentationOwned && cardContent.shellManagedSurface
        radius: Appearance.rounding.extraLarge
        color: BlurService.opaqueBackgroundColor(
            Appearance.m3colors.m3surfaceContainerHigh)
    }

    SystemCardContent {
        id: cardContent

        anchors.fill: parent
        tileId: root.tileId
        // Once extraction starts the presentation-host proxy becomes the
        // only active sidebar-side renderer. Keep this delegate allocated so
        // Grid state remains stable, but do not run a second Card content.
        active: root.active && !root.presentationOwned
        visible: !root.presentationOwned
        useShellManagedSurface: true
    }

    HoverHandler {
        cursorShape: dragHandler.active
            ? Qt.ClosedHandCursor
            : Qt.OpenHandCursor
    }

    DragHandler {
        id: dragHandler

        target: null
        enabled: root.active
        acceptedButtons: Qt.LeftButton
        grabPermissions:
            PointerHandler.CanTakeOverFromAnything
            | PointerHandler.ApprovesTakeOverByAnything

        property bool started: false

        onActiveChanged: {
            if (active) {
                started = true;
                const point = root.mapToItem(
                    null,
                    centroid.position.x,
                    centroid.position.y
                );
                root.dragStarted(
                    root.tileId,
                    root,
                    point.x,
                    point.y
                );
            } else if (started) {
                started = false;
                root.dragFinished(root.tileId);
            }
        }

        onCentroidChanged: {
            if (!active)
                return;
            const point = root.mapToItem(
                null,
                centroid.position.x,
                centroid.position.y
            );
            root.dragMoved(root.tileId, point.x, point.y);
        }

        onCanceled: {
            started = false;
            root.dragCanceled(root.tileId);
        }
    }
}
