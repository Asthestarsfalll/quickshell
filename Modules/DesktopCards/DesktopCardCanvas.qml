import QtQuick
import Quickshell
import qs.Common
import qs.Services
import "./DesktopCardPresentation.js" as Presentation

Item {
    id: root

    required property var scene
    required property string screenName
    property var analysis: null
    property Item hostItem: root
    signal delegateReady(string tileId)
    signal handoffReady(string tileId)

    // Exposed properties make the fixed host Region bindings observable when
    // the Repeater creates its ten delegates after the PanelWindow is ready.
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
        // Read the state property directly so this binding is invalidated
        // even when the filtering helper itself is a JS function call.
        const cards = SystemCardService.cards;
        return cards
            ? SystemCardService.desktopIdsForScreen(
                root.screenName, root.screenNames)
            : [];
    }

    width: root.scene ? root.scene.canvasWidth : 1
    height: root.scene ? root.scene.canvasHeight : 1
    x: root.scene ? root.scene.animatedOffsetX : 0
    y: root.scene ? root.scene.animatedOffsetY : 0

    function slotAt(index) {
        return cardRepeater.itemAt(index);
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

    readonly property bool allActiveCardsPresented: {
        for (let index = 0; index < cardRepeater.count; index += 1) {
            const item = cardRepeater.itemAt(index);
            if (item && item.active && !item.positionInitialized)
                return false;
        }
        return true;
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
                root.timeBlurExclusionItem = item.presentationItem;
                break;
            }
        }
    }

    function inputItemAt(index) {
        const item = cardRepeater.itemAt(index);
        return item ? item.presentationItem : null;
    }

    function isActive(id) {
        const tileId = String(id);
        // Ownership is the only source of truth.  A frozen drag ghost is a
        // visual proxy and must never delay the real DesktopCard delegate.
        return root.desktopIds.indexOf(tileId) !== -1;
    }

    function targetPosition(id, state, size) {
        if (!root.scene)
            return { x: 0, y: 0 };
        const point = root.scene.normalizedToWallpaper(
            state.desktop.xNorm, state.desktop.yNorm);
        return {
            x: Math.max(0, Math.min(
                Math.max(0, root.width - size.width), point.x)),
            y: Math.max(0, Math.min(
                Math.max(0, root.height - size.height), point.y))
        };
    }

    Repeater {
        id: cardRepeater

        onItemAdded: {
            root.updateInputSlots();
            Qt.callLater(root.updateInputSlots);
        }
        onItemRemoved: {
            root.updateInputSlots();
            Qt.callLater(root.updateInputSlots);
        }

        // Ten fixed slots keep the PanelWindow mask stable.  Only the one
        // output that owns a card activates its DesktopCard Loader.
        model: SystemCardService.cardIds

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
            readonly property var size: SystemCardService.cardSize(
                slot.tileId)
            readonly property var target: active
                ? root.targetPosition(slot.tileId, cardState, size)
                : ({ x: 0, y: 0 })
            property bool positionInitialized: false
            property bool positionAnimationEnabled: false
            property real presentationOffsetX: 0
            property real presentationOffsetY: 0
            property bool handoffPresentationPrepared: false
            property bool handoffPinned: false
            property bool presentationSettling: false
            property var handoffSourceRect: null
            readonly property Item presentationItem: presentationLayer
            readonly property bool positionReady:
                slot.active && root.scene !== null
                && root.width > 1 && root.height > 1
                && cardLoader.item !== null
            readonly property bool waitingForVisualHandoff:
                slot.active
                && SystemCardDragSession.visualHandoffPending
                && SystemCardDragSession.tileId === slot.tileId

            x: target.x
            y: target.y
            width: active ? size.width : 0
            height: active ? size.height : 0
            // A committed transfer keeps the ghost as the only visible
            // owner until this slot has loaded and presented its real card.
            visible: active && !slot.waitingForVisualHandoff

            onActiveChanged: {
                if (active && SystemCardDragSession.transferCommitted
                        && SystemCardDragSession.tileId === tileId) {
                    console.log(
                        "[SystemCards] desktop delegate active", tileId);
                }
                if (active) {
                    handoffFrameGate.stop();
                    presentationSettleAnimation.stop();
                    slot.positionInitialized = false;
                    slot.positionAnimationEnabled = false;
                    slot.presentationOffsetX = 0;
                    slot.presentationOffsetY = 0;
                    slot.handoffPresentationPrepared = false;
                    slot.handoffPinned = false;
                    slot.presentationSettling = false;
                    slot.handoffSourceRect = null;
                    Qt.callLater(slot.presentIfReady);
                } else {
                    // An inactive fixed slot may reset to (0, 0), but it is
                    // invisible and never animates that reset.  Re-entry is
                    // treated as a new presentation at its committed point.
                    slot.positionInitialized = false;
                    slot.positionAnimationEnabled = false;
                    handoffFrameGate.stop();
                    presentationSettleAnimation.stop();
                    slot.presentationOffsetX = 0;
                    slot.presentationOffsetY = 0;
                    slot.handoffPresentationPrepared = false;
                    slot.handoffPinned = false;
                    slot.presentationSettling = false;
                    slot.handoffSourceRect = null;
                }
            }

            function logicalScreenRect() {
                const point = slot.mapToItem(root.hostItem, 0, 0);
                return {
                    x: point.x,
                    y: point.y,
                    width: slot.width,
                    height: slot.height
                };
            }

            function presentedScreenRect() {
                const point = presentationLayer.mapToItem(
                    root.hostItem, 0, 0);
                return {
                    x: point.x,
                    y: point.y,
                    width: presentationLayer.width,
                    height: presentationLayer.height
                };
            }

            function syncPinnedPresentation() {
                if (!slot.handoffPinned || !slot.handoffSourceRect)
                    return;
                const target = slot.logicalScreenRect();
                const offset = Presentation.offsetForRects(
                    slot.handoffSourceRect, target);
                slot.presentationOffsetX = offset.x;
                slot.presentationOffsetY = offset.y;
            }

            function prepareHandoffPresentation() {
                const ghost = SystemCardDragSession.frozenGhostRect;
                if (!ghost || !ghost.valid)
                    return false;

                presentationSettleAnimation.stop();
                slot.handoffSourceRect = {
                    x: ghost.x,
                    y: ghost.y,
                    width: ghost.width,
                    height: ghost.height
                };
                // Loader readiness is not yet visual readiness. Keep the
                // DesktopCard pinned to the frozen ghost rect until it has
                // rendered a frame. Any scene/slot movement in that interval
                // recomputes A-B instead of exposing B as a teleport.
                slot.handoffPinned = true;
                slot.syncPinnedPresentation();

                const firstRect = slot.presentedScreenRect();
                if (!Presentation.rectsWithinTolerance(
                        firstRect, slot.handoffSourceRect, 1)) {
                    console.warn(
                        "[DesktopCards] handoff geometry mismatch",
                        slot.tileId,
                        "ghost=" + ghost.x + "," + ghost.y,
                        "desktop=" + firstRect.x + "," + firstRect.y
                    );
                    slot.handoffPinned = false;
                    slot.handoffSourceRect = null;
                    return false;
                }

                slot.handoffPresentationPrepared = true;
                const target = slot.logicalScreenRect();
                console.log(
                    "[DesktopCards] handoff ready",
                    slot.tileId,
                    "ghost=" + ghost.x + "," + ghost.y,
                    "target=" + target.x + "," + target.y,
                    "offset=" + slot.presentationOffsetX + ","
                        + slot.presentationOffsetY,
                    "sceneOffset=" + Number(root.scene.animatedOffsetX)
                        + "," + Number(root.scene.animatedOffsetY),
                    "parallax=" + String(
                        root.scene.manualParallaxActive)
                );
                return true;
            }

            function startPresentationTransition() {
                if (!slot.active || !slot.handoffPresentationPrepared)
                    return false;
                slot.handoffPresentationPrepared = false;
                slot.presentationSettling = true;
                // Keep one rendered DesktopCard frame exactly on the frozen
                // Ghost rect. The pin remains live during that frame, so a
                // simultaneous scene/slot change cannot invalidate A-B.
                handoffFrameGate.frameCount = 0;
                handoffFrameGate.start();
                return true;
            }

            function beginCardDrag() {
                handoffFrameGate.stop();
                presentationSettleAnimation.stop();
                slot.presentationSettling = false;
                slot.handoffPresentationPrepared = false;
                slot.handoffPinned = false;
                slot.handoffSourceRect = null;
                slot.presentationOffsetX = 0;
                slot.presentationOffsetY = 0;
            }

            function finishCardDrag() {
                slot.presentationOffsetX = 0;
                slot.presentationOffsetY = 0;
            }

            function cancelCardDrag(screenX, screenY) {
                const target = slot.logicalScreenRect();
                handoffFrameGate.stop();
                presentationSettleAnimation.stop();
                slot.presentationOffsetX = Number(screenX) - target.x;
                slot.presentationOffsetY = Number(screenY) - target.y;
                slot.presentationSettling = true;
                presentationSettleAnimation.restart();
            }

            function presentIfReady() {
                if (!slot.active || !slot.positionReady)
                    return;
                if (!slot.positionInitialized) {
                    slot.positionInitialized = true;
                    slot.positionAnimationEnabled = true;
                    root.delegateReady(slot.tileId);
                }
                if (slot.waitingForVisualHandoff
                        && SystemCardDragSession.transferCommitted
                        && !slot.handoffPresentationPrepared
                        && slot.prepareHandoffPresentation()) {
                    root.handoffReady(slot.tileId);
                }
            }

            onPositionReadyChanged: Qt.callLater(slot.presentIfReady)
            onWaitingForVisualHandoffChanged:
                Qt.callLater(slot.presentIfReady)
            onXChanged: slot.syncPinnedPresentation()
            onYChanged: slot.syncPinnedPresentation()

            Connections {
                target: SystemCardDragSession

                function onTransferCommittedChanged() {
                    Qt.callLater(slot.presentIfReady);
                }
            }

            Connections {
                target: root

                function onXChanged() {
                    slot.syncPinnedPresentation();
                }

                function onYChanged() {
                    slot.syncPinnedPresentation();
                }
            }

            Component.onCompleted: {
                slot.positionInitialized = false;
                slot.positionAnimationEnabled = false;
                Qt.callLater(slot.presentIfReady);
            }

            // The slot moves with the reflow token.  The parent canvas itself
            // has no position animation, so wallpaper parallax remains an
            // exact shared transform instead of acquiring a second lag.
            Behavior on x {
                enabled: slot.positionAnimationEnabled
                    && slot.positionInitialized && slot.active
                    && !(cardLoader.item && cardLoader.item.dragging)
                NumberAnimation {
                    duration: Appearance.animation.desktopCardReflow.duration
                    easing.type: Appearance.animation.desktopCardReflow.type
                    easing.bezierCurve:
                        Appearance.animation.desktopCardReflow.bezierCurve
                }
            }
            Behavior on y {
                enabled: slot.positionAnimationEnabled
                    && slot.positionInitialized && slot.active
                    && !(cardLoader.item && cardLoader.item.dragging)
                NumberAnimation {
                    duration: Appearance.animation.desktopCardReflow.duration
                    easing.type: Appearance.animation.desktopCardReflow.type
                    easing.bezierCurve:
                        Appearance.animation.desktopCardReflow.bezierCurve
                }
            }

            Item {
                id: presentationLayer

                x: slot.presentationOffsetX
                y: slot.presentationOffsetY
                width: slot.width
                height: slot.height
                visible: slot.visible

                Loader {
                    id: cardLoader

                    property real targetWallpaperX: slot.x
                    property real targetWallpaperY: slot.y

                    x: cardLoader.item && cardLoader.item.dragging
                        ? cardLoader.item.dragX - slot.x : 0
                    y: cardLoader.item && cardLoader.item.dragging
                        ? cardLoader.item.dragY - slot.y : 0
                    width: slot.width
                    height: slot.height
                    active: slot.active
                    sourceComponent: Component {
                        DesktopCard {
                            anchors.fill: parent
                            tileId: slot.tileId
                            scene: root.scene
                            hostItem: root.hostItem
                            targetWallpaperX: cardLoader.targetWallpaperX
                            targetWallpaperY: cardLoader.targetWallpaperY
                            presentationController: slot
                        }
                    }

                    onItemChanged: Qt.callLater(slot.presentIfReady)

                    Behavior on x {
                        enabled: !(cardLoader.item
                            && cardLoader.item.dragging)
                        NumberAnimation {
                            duration: Appearance.animation.desktopCardReflow.duration
                            easing.type: Appearance.animation.desktopCardReflow.type
                            easing.bezierCurve:
                                Appearance.animation.desktopCardReflow.bezierCurve
                        }
                    }
                    Behavior on y {
                        enabled: !(cardLoader.item
                            && cardLoader.item.dragging)
                        NumberAnimation {
                            duration: Appearance.animation.desktopCardReflow.duration
                            easing.type: Appearance.animation.desktopCardReflow.type
                            easing.bezierCurve:
                                Appearance.animation.desktopCardReflow.bezierCurve
                        }
                    }
                }
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

                onFinished: {
                    slot.presentationSettling = false;
                    slot.handoffSourceRect = null;
                }
            }

            FrameAnimation {
                id: handoffFrameGate

                property int frameCount: 0

                onTriggered: {
                    frameCount += 1;
                    if (frameCount < 2)
                        return;
                    handoffFrameGate.stop();
                    if (!slot.active || !slot.presentationSettling)
                        return;
                    // Capture A-currentB before releasing the pin. Both
                    // assignments happen in this render turn, so the visible
                    // rect is unchanged when ownership becomes unpinned.
                    slot.syncPinnedPresentation();
                    const firstFrame = slot.presentedScreenRect();
                    console.log(
                        "[DesktopCards] first presented frame",
                        slot.tileId,
                        "rect=" + firstFrame.x + "," + firstFrame.y,
                        "target=" + slot.logicalScreenRect().x + ","
                            + slot.logicalScreenRect().y
                    );
                    slot.handoffPinned = false;
                    if (Math.abs(slot.presentationOffsetX) <= 0.01
                            && Math.abs(slot.presentationOffsetY) <= 0.01) {
                        slot.presentationOffsetX = 0;
                        slot.presentationOffsetY = 0;
                        slot.presentationSettling = false;
                        slot.handoffSourceRect = null;
                    } else {
                        presentationSettleAnimation.restart();
                    }
                }
            }
        }
    }

    Component.onCompleted: Qt.callLater(root.updateInputSlots)
}
