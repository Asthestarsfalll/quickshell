import QtQuick
import Quickshell
import qs.Common
import qs.Services
import "../SystemCards/SystemCardPlacement.js" as Placement

Item {
    id: root

    required property var scene
    required property string screenName
    property Item hostItem: root
    signal delegateReady(string tileId)
    signal handoffReady(string tileId)

    // The canvas is always the output-local screen coordinate system. A
    // wallpaper transform is an input to wallpaper-anchored slots; it never
    // moves this item or creates a second handoff coordinate system.
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

    function screenPositionFor(state, size) {
        return Placement.screenPoint(
            state.desktop.screen.xNorm,
            state.desktop.screen.yNorm,
            root.width,
            root.height,
            size.width,
            size.height
        );
    }

    function wallpaperPositionFor(state, size) {
        if (!root.scene)
            return { x: 0, y: 0 };
        return Placement.wallpaperPoint(
            state.desktop.wallpaper.xNorm,
            state.desktop.wallpaper.yNorm,
            root.scene.canvasWidth,
            root.scene.canvasHeight,
            size.width,
            size.height
        );
    }

    // Convert the currently displayed screen rect to the normalized screen
    // state in one batch. This is the only operation used when switching an
    // automatic wallpaper layout back to free mode.
    function promoteCardsToScreen() {
        if (root.width <= 1 || root.height <= 1)
            return;
        const positions = [];
        for (let index = 0; index < cardRepeater.count; ++index) {
            const item = cardRepeater.itemAt(index);
            if (!item || !item.active)
                continue;
            if (item.placementSpace === Placement.wallpaper
                    && !root.scene)
                continue;
            const point = item.captureVisualScreenPosition();
            positions.push({
                id: item.tileId,
                xNorm: Placement.normalizedPosition(
                    point.x, point.y, root.width, root.height).xNorm,
                yNorm: Placement.normalizedPosition(
                    point.x, point.y, root.width, root.height).yNorm
            });
        }
        SystemCardService.setDesktopScreenPositions(positions);
        for (let index = 0; index < cardRepeater.count; ++index) {
            const item = cardRepeater.itemAt(index);
            if (item && item.active)
                item.finishScreenPromotion();
        }
    }

    // Automatic solving writes wallpaper targets first. Screen-placed cards
    // then animate from their visible screen rect into the live wallpaper
    // projection. The slot's target is evaluated every frame, so parallax can
    // continue while the space migration is in progress.
    function startAutomaticTransitions() {
        if (SystemCardService.globalDesktopLayoutMode === "free")
            return;
        for (let index = 0; index < cardRepeater.count; ++index) {
            const item = cardRepeater.itemAt(index);
            if (item && item.active)
                item.beginWallpaperTransition();
        }
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
            readonly property string placementSpace:
                active && cardState.desktop
                    ? String(cardState.desktop.placementSpace || "screen")
                    : Placement.screen
            readonly property var screenTarget: active
                ? root.screenPositionFor(cardState, size)
                : ({ x: 0, y: 0 })
            readonly property var wallpaperTarget: active
                ? root.wallpaperPositionFor(cardState, size)
                : ({ x: 0, y: 0 })
            property real layoutWallpaperX: wallpaperTarget.x
            property real layoutWallpaperY: wallpaperTarget.y
            property bool positionInitialized: false
            property bool handoffReadySent: false
            property bool wallpaperTransitionActive: false
            property real wallpaperTransitionProgress: 0
            property real transitionStartX: 0
            property real transitionStartY: 0
            readonly property bool dragging:
                cardLoader.item && cardLoader.item.dragging
            readonly property real projectedWallpaperX:
                slot.layoutWallpaperX
                    + Number(root.scene ? root.scene.animatedOffsetX : 0)
            readonly property real projectedWallpaperY:
                slot.layoutWallpaperY
                    + Number(root.scene ? root.scene.animatedOffsetY : 0)
            readonly property bool positionReady:
                slot.active
                && root.width > 1 && root.height > 1
                && cardLoader.item !== null
            readonly property bool waitingForVisualHandoff:
                slot.active
                && SystemCardDragSession.visualHandoffPending
                && SystemCardDragSession.tileId === slot.tileId
            readonly property real visualScreenX:
                slot.dragging
                    ? cardLoader.item.dragX
                    : slot.wallpaperTransitionActive
                    ? Placement.interpolate(
                        slot.transitionStartX,
                        slot.projectedWallpaperX,
                        slot.wallpaperTransitionProgress)
                    : slot.placementSpace === Placement.screen
                    ? slot.screenTarget.x
                    : slot.projectedWallpaperX
            readonly property real visualScreenY:
                slot.dragging
                    ? cardLoader.item.dragY
                    : slot.wallpaperTransitionActive
                    ? Placement.interpolate(
                        slot.transitionStartY,
                        slot.projectedWallpaperY,
                        slot.wallpaperTransitionProgress)
                    : slot.placementSpace === Placement.screen
                    ? slot.screenTarget.y
                    : slot.projectedWallpaperY

            x: slot.visualScreenX
            y: slot.visualScreenY
            width: active ? size.width : 0
            height: active ? size.height : 0
            visible: active && !slot.waitingForVisualHandoff

            function visualRect() {
                return {
                    x: slot.visualScreenX,
                    y: slot.visualScreenY,
                    width: slot.width,
                    height: slot.height
                };
            }

            function captureVisualScreenPosition() {
                return { x: slot.visualScreenX, y: slot.visualScreenY };
            }

            function finishScreenPromotion() {
                slot.wallpaperTransitionActive = false;
                wallpaperTransition.stop();
                slot.wallpaperTransitionProgress = 0;
            }

            function beginCardDrag() {
                const point = slot.captureVisualScreenPosition();
                // Write the current visible point while the transition is
                // still active. Turning the transition off afterwards leaves
                // the screen-space binding at exactly the same point.
                SystemCardService.setDesktopScreenPosition(
                    slot.tileId,
                    Placement.normalizedPosition(
                        point.x, point.y, root.width, root.height).xNorm,
                    Placement.normalizedPosition(
                        point.x, point.y, root.width, root.height).yNorm,
                    false
                );
                slot.wallpaperTransitionActive = false;
                wallpaperTransition.stop();
                slot.wallpaperTransitionProgress = 0;
                return point;
            }

            function finishCardDrag() {
                // The DesktopCard has already committed the screen point.
                // Automatic modes are scheduled by that commit and will
                // perform the explicit screen -> wallpaper migration.
            }

            function cancelCardDrag() {
                SystemCardService.requestDesktopLayout();
            }

            function beginWallpaperTransition() {
                if (!slot.active
                        || slot.placementSpace !== Placement.screen
                        || slot.waitingForVisualHandoff
                        || slot.wallpaperTransitionActive)
                    return false;
                slot.transitionStartX = slot.visualScreenX;
                slot.transitionStartY = slot.visualScreenY;
                slot.wallpaperTransitionProgress = 0;
                slot.wallpaperTransitionActive = true;
                wallpaperTransition.restart();
                return true;
            }

            function finishWallpaperTransition() {
                if (!slot.wallpaperTransitionActive)
                    return;
                slot.wallpaperTransitionProgress = 1;
                // The last animated frame already projects the wallpaper
                // target. Commit the new space only after that frame exists.
                SystemCardService.setPlacementSpace(
                    slot.tileId, Placement.wallpaper);
                slot.wallpaperTransitionActive = false;
                slot.wallpaperTransitionProgress = 0;
            }

            function prepareHandoff() {
                const ghost = SystemCardDragSession.frozenGhostRect;
                if (!ghost || !ghost.valid
                        || slot.placementSpace !== Placement.screen)
                    return false;
                const actual = slot.visualRect();
                const matches = Math.abs(actual.x - ghost.x) <= 1
                    && Math.abs(actual.y - ghost.y) <= 1
                    && Math.abs(actual.width - ghost.width) <= 1
                    && Math.abs(actual.height - ghost.height) <= 1;
                if (!matches) {
                    console.warn(
                        "[DesktopCards] screen handoff geometry mismatch",
                        slot.tileId,
                        "ghost=" + ghost.x + "," + ghost.y,
                        "desktop=" + actual.x + "," + actual.y
                    );
                    return false;
                }
                slot.handoffReadySent = true;
                console.log(
                    "[DesktopCards] screen handoff ready",
                    slot.tileId,
                    "rect=" + actual.x + "," + actual.y
                );
                return true;
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
                        && !slot.handoffReadySent
                        && slot.prepareHandoff()) {
                    root.handoffReady(slot.tileId);
                }
            }

            onActiveChanged: {
                wallpaperTransition.stop();
                slot.wallpaperTransitionActive = false;
                slot.wallpaperTransitionProgress = 0;
                slot.handoffReadySent = false;
                slot.positionInitialized = false;
                if (active)
                    slot.presentIfReady();
            }

            onPositionReadyChanged: slot.presentIfReady()
            onPlacementSpaceChanged: slot.presentIfReady()

            Connections {
                target: SystemCardDragSession

                function onHandoffCheckRequested(tileId) {
                    if (String(tileId) === slot.tileId)
                        slot.presentIfReady();
                }
            }

            Component.onCompleted: slot.presentIfReady()

            Behavior on layoutWallpaperX {
                enabled: slot.positionInitialized
                    && slot.active
                    && slot.placementSpace === Placement.wallpaper
                    && !slot.wallpaperTransitionActive
                    && !slot.dragging
                NumberAnimation {
                    duration: Appearance.animation.desktopCardReflow.duration
                    easing.type: Appearance.animation.desktopCardReflow.type
                    easing.bezierCurve:
                        Appearance.animation.desktopCardReflow.bezierCurve
                }
            }

            Behavior on layoutWallpaperY {
                enabled: slot.positionInitialized
                    && slot.active
                    && slot.placementSpace === Placement.wallpaper
                    && !slot.wallpaperTransitionActive
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
                        hostItem: root.hostItem
                        placementController: slot
                    }
                }
                onItemChanged: slot.presentIfReady()
            }

            NumberAnimation {
                id: wallpaperTransition

                target: slot
                property: "wallpaperTransitionProgress"
                from: 0
                to: 1
                duration: Appearance.animation.desktopCardReflow.duration
                easing.type: Appearance.animation.desktopCardReflow.type
                easing.bezierCurve:
                    Appearance.animation.desktopCardReflow.bezierCurve
                onStopped: slot.finishWallpaperTransition()
            }
        }
    }

    Component.onCompleted: root.updateInputSlots()
}
