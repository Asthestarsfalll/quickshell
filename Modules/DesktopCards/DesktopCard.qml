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
    property real dragX: targetWallpaperX
    property real dragY: targetWallpaperY
    property real dragOffsetX: 0
    property real dragOffsetY: 0

    readonly property var cardState:
        SystemCardService.cards[root.tileId] || null
    readonly property string placementMode:
        cardState && cardState.desktop
            ? cardState.desktop.mode : "free"
    readonly property bool canDrag: root.active && root.scene !== null

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

    SystemCardContent {
        anchors.fill: parent
        tileId: root.tileId
        active: true
    }

    HoverHandler {
        cursorShape: dragHandler.active
            ? Qt.ClosedHandCursor : Qt.OpenHandCursor
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
                root.dragOffsetX = wallpaperPoint.x
                    - root.targetWallpaperX;
                root.dragOffsetY = wallpaperPoint.y
                    - root.targetWallpaperY;
                root.dragX = root.targetWallpaperX;
                root.dragY = root.targetWallpaperY;
                root.dragging = true;
                if (root.placementMode !== "free")
                    SystemCardService.setDesktopMode(
                        root.tileId, "free");
            } else if (started) {
                started = false;
                const xNorm = root.dragX
                    / Math.max(1, root.scene.canvasWidth);
                const yNorm = root.dragY
                    / Math.max(1, root.scene.canvasHeight);
                SystemCardService.setDesktopPosition(
                    root.tileId, xNorm, yNorm, true);
                root.dragging = false;
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
            started = false;
            root.dragging = false;
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
            text: qsTr("自由拖拽")
            checkable: true
            checked: root.placementMode === "free"
            onTriggered: SystemCardService.setDesktopMode(
                root.tileId, "free")
        }
        MenuItem {
            text: qsTr("最空旷处")
            checkable: true
            checked: root.placementMode === "leastBusy"
            onTriggered: SystemCardService.setDesktopMode(
                root.tileId, "leastBusy")
        }
        MenuItem {
            text: qsTr("最密集处")
            checkable: true
            checked: root.placementMode === "mostBusy"
            onTriggered: SystemCardService.setDesktopMode(
                root.tileId, "mostBusy")
        }
        MenuSeparator {}
        MenuItem {
            text: qsTr("收回到侧边栏")
            onTriggered: SystemCardService.setContainer(
                root.tileId, "sidebar", "")
        }
    }
}
