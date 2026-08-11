import QtQuick
import Quickshell
import qs.Common
import qs.Services
import "./DesktopCardPresentation.js" as Presentation

Item {
    id: root

    required property var scene
    required property string screenName
    property Item hostItem: root
    signal delegateReady(string tileId)
    signal handoffReady(string tileId)

    // This canvas is the current output's fixed screen-space coordinate
    // system. Wallpaper movement is projected per card; it never moves this
    // item or any other ancestor of the visual handoff.
    x: 0
    y: 0

    property Item inputSlot0: null
    property Item inputSlot1: null
    property Item inputSlot2: null
    property Item inputSlot3: null
    property Item inputSlot4: null
    property Item inputSlot5: null
    property Item inputSlot6: null
    property Item inputSlot7: null
    property Item inputSlot8: null
    property Item inputSlot9: null
    property Item timeBlurExclusionItem: null

    readonly property var screenNames: {
        const result = [];
        for (let index = 0; index < Quickshell.screens.length; index += 1)
            result.push(String(Quickshell.screens[index].name));
        return result;
    }
    readonly property var desktopIds: {
        const cards = SystemCardService.cards;
        return cards
            ? SystemCardService.desktopIdsForScreen(
                root.screenName, root.screenNames)
            : [];
    }
    readonly property bool allActiveCardsPresented: {
        for (let index = 0; index < cardRepeater.count; index += 1) {
            const item = cardRepeater.itemAt(index);
            if (item && item.active && !item.positionInitialized)
                return false;
        }
        return true;
    }

    function startPresentationTransition(tileId) {
        const id = String(tileId || "");
        for (let index = 0; index < cardRepeater.count; ++index) {
            const item = cardRepeater.itemAt(index);
            if (item && item.tileId === id)
                return item.startPresentationTransition();
        }
        return false;
    }

    function inputItemAt(index) {
        return cardRepeater.itemAt(index);
    }

    function updateInputSlots() {
        root.inputSlot0 = root.inputItemAt(0);
        root.inputSlot1 = root.inputItemAt(1);
        root.inputSlot2 = root.inputItemAt(2);
        root.inputSlot3 = root.inputItemAt(3);
        root.inputSlot4 = root.inputItemAt(4);
        root.inputSlot5 = root.inputItemAt(5);
        root.inputSlot6 = root.inputItemAt(6);
        root.inputSlot7 = root.inputItemAt(7);
        root.inputSlot8 = root.inputItemAt(8);
        root.inputSlot9 = root.inputItemAt(9);
        root.timeBlurExclusionItem = null;
        for (let index = 0; index < cardRepeater.count; ++index) {
            const item = cardRepeater.itemAt(index);
            if (item && item.tileId === "time") {
                root.timeBlurExclusionItem = item;
                break;
            }
        }
    }

    function isActive(id) {
        return root.desktopIds.indexOf(String(id)) !== -1;
    }

    function targetWallpaperPosition(state, size) {
        if (!root.scene)
            return { x: 0, y: 0 };
        const point = root.scene.normalizedToWallpaper(
            state.desktop.xNorm, state.desktop.yNorm);
        return {
            x: Math.max(0, Math.min(
                Math.max(0, root.scene.canvasWidth - size.width),
                point.x)),
            y: Math.max(0, Math.min(
                Math.max(0, root.scene.canvasHeight - size.height),
                point.y))
        };
    }

    Repeater {
        id: cardRepeater

        model: SystemCardService.cardIds
        onItemAdded: root.updateInputSlots()
        onItemRemoved: root.updateInputSlots()

        delegate: Item {
            id: slot

            required property string modelData
            readonly property string tileId: modelData
            readonly property var cardState:
                SystemCardService.cards[slot.tileId] || null
            readonly property bool active:
                root.isActive(slot.tileId)
                    && cardState !== null
                    && cardState.enabled
            readonly property var size:
                SystemCardService.cardSize(slot.tileId)
            readonly property var targetWallpaper: active
                ? root.targetWallpaperPosition(cardState, size)
                : ({ x: 0, y: 0 })
            property real layoutWallpaperX: targetWallpaper.x
            property real layoutWallpaperY: targetWallpaper.y
            property real presentationOffsetX: 0
            property real presentationOffsetY: 0
            property bool positionInitialized: false
            property bool handoffPrepared: false
            readonly property bool dragging:
                cardLoader.item && cardLoader.item.dragging
            readonly property real projectedScreenX:
                slot.layoutWallpaperX
                    + Number(root.scene ? root.scene.animatedOffsetX : 0)
            readonly property real projectedScreenY:
                slot.layoutWallpaperY
                    + Number(root.scene ? root.scene.animatedOffsetY : 0)
            readonly property bool positionReady:
                slot.active && root.scene !== null
                && root.width > 1 && root.height > 1
                && cardLoader.item !== null
            readonly property bool waitingForVisualHandoff:
                slot.active
                && SystemCardDragSession.visualHandoffPending
                && SystemCardDragSession.tileId === slot.tileId

            // Wallpaper parallax contributes directly to this screen-space
            // projection and never passes through desktopCardReflow.
            x: slot.dragging
                ? cardLoader.item.dragX + root.scene.animatedOffsetX
                : slot.projectedScreenX + slot.presentationOffsetX
            y: slot.dragging
                ? cardLoader.item.dragY + root.scene.animatedOffsetY
                : slot.projectedScreenY + slot.presentationOffsetY
            width: active ? size.width : 0
            height: active ? size.height : 0
            visible: active && !slot.waitingForVisualHandoff

            onActiveChanged: {
                presentationSettleAnimation.stop();
                slot.presentationOffsetX = 0;
                slot.presentationOffsetY = 0;
                slot.handoffPrepared = false;
                slot.positionInitialized = false;
                if (active)
                    slot.presentIfReady();
            }

            function projectedRect() {
                return {
                    x: slot.projectedScreenX,
                    y: slot.projectedScreenY,
                    width: slot.width,
                    height: slot.height
                };
            }

            function visualRect() {
                return {
                    x: slot.x,
                    y: slot.y,
                    width: slot.width,
                    height: slot.height
                };
            }

            function prepareHandoffPresentation() {
                const ghost = SystemCardDragSession.frozenGhostRect;
                if (!ghost || !ghost.valid)
                    return false;
                const target = slot.projectedRect();
                const offset = Presentation.offsetForRects(ghost, target);
                presentationSettleAnimation.stop();
                slot.presentationOffsetX = offset.x;
                slot.presentationOffsetY = offset.y;
                if (!Presentation.rectsWithinTolerance(
                        slot.visualRect(), ghost, 1)) {
                    console.warn(
                        "[DesktopCards] handoff geometry mismatch",
                        slot.tileId,
                        "ghost=" + ghost.x + "," + ghost.y,
                        "desktop=" + slot.x + "," + slot.y
                    );
                    return false;
                }
                slot.handoffPrepared = true;
                console.log(
                    "[DesktopCards] handoff ready",
                    slot.tileId,
                    "ghost=" + ghost.x + "," + ghost.y,
                    "logical=" + slot.layoutWallpaperX + ","
                        + slot.layoutWallpaperY,
                    "sceneOffset=" + root.scene.animatedOffsetX + ","
                        + root.scene.animatedOffsetY,
                    "projected=" + target.x + "," + target.y,
                    "presentation=" + offset.x + "," + offset.y
                );
                return true;
            }

            function startPresentationTransition() {
                if (!slot.active || !slot.handoffPrepared)
                    return false;
                slot.handoffPrepared = false;
                if (Math.abs(slot.presentationOffsetX) <= 0.01
                        && Math.abs(slot.presentationOffsetY) <= 0.01) {
                    slot.presentationOffsetX = 0;
                    slot.presentationOffsetY = 0;
                } else {
                    presentationSettleAnimation.restart();
                }
                return true;
            }

            function beginCardDrag() {
                presentationSettleAnimation.stop();
                slot.handoffPrepared = false;
                slot.presentationOffsetX = 0;
                slot.presentationOffsetY = 0;
            }

            function finishCardDrag() {
                slot.presentationOffsetX = 0;
                slot.presentationOffsetY = 0;
            }

            function cancelCardDrag(screenX, screenY) {
                presentationSettleAnimation.stop();
                slot.presentationOffsetX = Number(screenX)
                    - slot.projectedScreenX;
                slot.presentationOffsetY = Number(screenY)
                    - slot.projectedScreenY;
                presentationSettleAnimation.restart();
            }

            function presentIfReady() {
                if (!slot.positionReady)
                    return;
                if (!slot.positionInitialized) {
                    slot.positionInitialized = true;
                    root.delegateReady(slot.tileId);
                }
                if (slot.waitingForVisualHandoff
                        && SystemCardDragSession.transferCommitted
                        && !slot.handoffPrepared
                        && slot.prepareHandoffPresentation()) {
                    root.handoffReady(slot.tileId);
                }
            }

            onPositionReadyChanged: slot.presentIfReady()
            onWaitingForVisualHandoffChanged: slot.presentIfReady()

            Connections {
                target: SystemCardDragSession

                function onTransferCommittedChanged() {
                    slot.presentIfReady();
                }
            }

            Component.onCompleted: slot.presentIfReady()

            Behavior on layoutWallpaperX {
                enabled: slot.positionInitialized && slot.active
                    && !slot.dragging
                NumberAnimation {
                    duration: Appearance.animation.desktopCardReflow.duration
                    easing.type: Appearance.animation.desktopCardReflow.type
                    easing.bezierCurve:
                        Appearance.animation.desktopCardReflow.bezierCurve
                }
            }

            Behavior on layoutWallpaperY {
                enabled: slot.positionInitialized && slot.active
                    && !slot.dragging
                NumberAnimation {
                    duration: Appearance.animation.desktopCardReflow.duration
                    easing.type: Appearance.animation.desktopCardReflow.type
                    easing.bezierCurve:
                        Appearance.animation.desktopCardReflow.bezierCurve
                }
            }

            Loader {
                id: cardLoader

                anchors.fill: parent
                active: slot.active
                sourceComponent: Component {
                    DesktopCard {
                        anchors.fill: parent
                        tileId: slot.tileId
                        scene: root.scene
                        hostItem: root.hostItem
                        targetWallpaperX: slot.layoutWallpaperX
                        targetWallpaperY: slot.layoutWallpaperY
                        presentationController: slot
                    }
                }
                onItemChanged: slot.presentIfReady()
            }

            ParallelAnimation {
                id: presentationSettleAnimation

                NumberAnimation {
                    target: slot
                    property: "presentationOffsetX"
                    to: 0
                    duration: Appearance.animation.desktopCardReflow.duration
                    easing.type: Appearance.animation.desktopCardReflow.type
                    easing.bezierCurve:
                        Appearance.animation.desktopCardReflow.bezierCurve
                }
                NumberAnimation {
                    target: slot
                    property: "presentationOffsetY"
                    to: 0
                    duration: Appearance.animation.desktopCardReflow.duration
                    easing.type: Appearance.animation.desktopCardReflow.type
                    easing.bezierCurve:
                        Appearance.animation.desktopCardReflow.bezierCurve
                }
            }
        }
    }

    Component.onCompleted: root.updateInputSlots()
}
