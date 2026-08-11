import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import qs.Common
import qs.Services
import qs.Modules.SystemCards

Item {
    id: root

    required property string tileId
    required property var scene
    required property Item hostItem
    property bool active: true
    property bool dragging: false
    property real targetWallpaperX: 0
    property real targetWallpaperY: 0
    property var presentationController: null
    property real dragX: targetWallpaperX
    property real dragY: targetWallpaperY
    property real dragOffsetX: 0
    property real dragOffsetY: 0

    readonly property var cardState:
        SystemCardService.cards[root.tileId] || null
    readonly property bool canDrag:
        root.active
        && root.scene !== null
        && SystemCardService.globalDesktopLayoutMode === "free"

    Accessible.role: Accessible.Pane
    Accessible.name: SystemCardService.cardName(root.tileId)

    scale: root.dragging ? 1.025 : 1
    Behavior on scale {
        NumberAnimation {
            duration: Appearance.animation.expressiveEffects.duration
            easing.type: Appearance.animation.expressiveEffects.type
            easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
        }
    }

    // Keep the same surface contract used by sidebar tiles.  The first six
    // cards retain their original component backgrounds.
    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.extraLarge
        visible: cardContent.shellManagedSurface
        color: BlurService.opaqueBackgroundColor(
            Appearance.m3colors.m3surfaceContainerHigh)
    }

    SystemCardContent {
        id: cardContent

        anchors.fill: parent
        tileId: root.tileId
        active: true
        useShellManagedSurface: true
    }

    HoverHandler {
        cursorShape: !root.canDrag
            ? Qt.ArrowCursor
            : dragHandler.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    }

    DragHandler {
        id: dragHandler

        target: null
        enabled: root.canDrag
        acceptedButtons: Qt.LeftButton
        grabPermissions:
            PointerHandler.CanTakeOverFromAnything
            | PointerHandler.ApprovesTakeOverByAnything

        property bool started: false

        function hostPoint() {
            return root.mapToItem(
                root.hostItem,
                centroid.position.x,
                centroid.position.y
            );
        }

        onActiveChanged: {
            if (active) {
                started = true;
                const point = dragHandler.hostPoint();
                const wallpaperPoint = root.scene.screenToWallpaper(
                    point.x, point.y);
                // A handoff transition may still be settling. Start this drag
                // from the card's actual visible top-left, then convert that
                // screen point back into wallpaper space before removing the
                // transient presentation offset.
                const visibleTopLeft = root.mapToItem(
                    root.hostItem, 0, 0);
                const visualWallpaperPoint = root.scene.screenToWallpaper(
                    visibleTopLeft.x, visibleTopLeft.y);
                if (root.presentationController
                        && typeof root.presentationController
                            .beginCardDrag === "function") {
                    root.presentationController.beginCardDrag();
                }
                root.dragOffsetX = wallpaperPoint.x
                    - visualWallpaperPoint.x;
                root.dragOffsetY = wallpaperPoint.y
                    - visualWallpaperPoint.y;
                root.dragX = visualWallpaperPoint.x;
                root.dragY = visualWallpaperPoint.y;
                root.dragging = true;
            } else if (started) {
                started = false;
                const xNorm = root.dragX
                    / Math.max(1, root.scene.canvasWidth);
                const yNorm = root.dragY
                    / Math.max(1, root.scene.canvasHeight);
                SystemCardService.setDesktopPosition(
                    root.tileId, xNorm, yNorm);
                root.dragging = false;
                if (root.presentationController
                        && typeof root.presentationController
                            .finishCardDrag === "function") {
                    root.presentationController.finishCardDrag();
                }
            }
        }

        onCentroidChanged: {
            if (!active)
                return;
            const point = dragHandler.hostPoint();
            const wallpaperPoint = root.scene.screenToWallpaper(
                point.x, point.y);
            root.dragX = Math.max(
                0,
                Math.min(
                    Math.max(0, root.scene.canvasWidth - root.width),
                    wallpaperPoint.x - root.dragOffsetX
                )
            );
            root.dragY = Math.max(
                0,
                Math.min(
                    Math.max(0, root.scene.canvasHeight - root.height),
                    wallpaperPoint.y - root.dragOffsetY
                )
            );
        }

        onCanceled: {
            const visibleTopLeft = root.mapToItem(
                root.hostItem, 0, 0);
            started = false;
            root.dragging = false;
            if (root.presentationController
                    && typeof root.presentationController
                        .cancelCardDrag === "function") {
                root.presentationController.cancelCardDrag(
                    visibleTopLeft.x, visibleTopLeft.y);
            }
        }
    }

    MouseArea {
        id: contextPointer

        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        hoverEnabled: true
        onPressed: menu.open()
    }

    Menu {
        id: menu

        Material.theme: Material.System
        Material.accent: Appearance.colors.colPrimary

        MenuItem {
            text: qsTr("收回到侧边栏")
            onTriggered: SystemCardService.setContainer(
                root.tileId, "sidebar", "")
        }
    }
}
