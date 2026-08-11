import QtQuick
import Quickshell
import qs.Common
import qs.Services

Item {
    id: root

    required property var scene
    required property string screenName
    property var analysis: null
    property Item hostItem: root

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

    function updateInputSlots() {
        root.inputSlot0 = cardRepeater.itemAt(0);
        root.inputSlot1 = cardRepeater.itemAt(1);
        root.inputSlot2 = cardRepeater.itemAt(2);
        root.inputSlot3 = cardRepeater.itemAt(3);
        root.inputSlot4 = cardRepeater.itemAt(4);
        root.inputSlot5 = cardRepeater.itemAt(5);
        root.inputSlot6 = cardRepeater.itemAt(6);
        root.inputSlot7 = cardRepeater.itemAt(7);
        root.inputSlot8 = cardRepeater.itemAt(8);
        root.inputSlot9 = cardRepeater.itemAt(9);
    }

    function isActive(id) {
        const tileId = String(id);
        // During Sidebar -> Desktop hand-off the frozen source delegate is
        // the only Card instance being painted by the top-level ghost.  Wait
        // for that session to end before creating the Desktop delegate.
        if (SystemCardDragSession.active
                && SystemCardDragSession.frozen
                && SystemCardDragSession.tileId === tileId)
            return false;
        return root.desktopIds.indexOf(tileId) !== -1;
    }

    function targetPosition(id, state, size) {
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

        onItemAdded: root.updateInputSlots()
        onItemRemoved: root.updateInputSlots()

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
            readonly property var size: SystemCardService.desktopSize(
                slot.tileId, root.width, root.height)
            readonly property var target: active
                ? root.targetPosition(slot.tileId, cardState, size)
                : ({ x: 0, y: 0 })

            x: target.x
            y: target.y
            width: active ? size.width : 0
            height: active ? size.height : 0
            visible: active

            // The slot moves with the reflow token.  The parent canvas itself
            // has no position animation, so wallpaper parallax remains an
            // exact shared transform instead of acquiring a second lag.
            Behavior on x {
                NumberAnimation {
                    duration: Appearance.animation.desktopCardReflow.duration
                    easing.type: Appearance.animation.desktopCardReflow.type
                    easing.bezierCurve:
                        Appearance.animation.desktopCardReflow.bezierCurve
                }
            }
            Behavior on y {
                NumberAnimation {
                    duration: Appearance.animation.desktopCardReflow.duration
                    easing.type: Appearance.animation.desktopCardReflow.type
                    easing.bezierCurve:
                        Appearance.animation.desktopCardReflow.bezierCurve
                }
            }

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
                    }
                }

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
    }

    Component.onCompleted: Qt.callLater(root.updateInputSlots)
}
