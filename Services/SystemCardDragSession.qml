pragma Singleton

import QtQuick
import Quickshell
import qs.Common
import "./SystemCardDragState.js" as DragState

Singleton {
    id: root

    // The phase is the source of truth for the gesture lifecycle.  `active`
    // and `frozen` remain as compatibility/readability aliases for the
    // existing overlay and sidebar bindings.
    readonly property string idlePhase: DragState.idle
    readonly property string draggingSidebarPhase:
        DragState.draggingSidebar
    readonly property string frozenTransferPhase:
        DragState.frozenTransfer
    readonly property string finishingPhase: DragState.finishing
    readonly property string canceledPhase: DragState.canceled

    property string phase: root.idlePhase
    readonly property bool active: DragState.isActive(root.phase)
    readonly property bool frozen: DragState.isFrozen(root.phase)
    readonly property bool ending: root.phase === root.finishingPhase
    readonly property bool visualHandoffPending:
        DragState.isVisualHandoffPending(
            root.phase, root.transferCommitted, root.transferPreparing)
    // Set before SystemCardService.setContainer() emits its state change.
    // This closes the small binding window in which a newly-created desktop
    // slot could otherwise become visible before the commit flag is written.
    property bool transferPreparing: false
    property bool transferCommitted: false

    property string tileId: ""
    property Item sourceItem: null
    property real pointerX: 0
    property real pointerY: 0
    property real offsetX: 0
    property real offsetY: 0
    property bool sourceWasBound: false

    signal started(string cardId)
    signal moved(real x, real y)
    signal finished()
    signal canceled()
    signal transferAccepted(string cardId)
    signal cancelRequested(string requestedTileId)

    function transition(nextPhase, reason) {
        if (root.phase === nextPhase)
            return;
        if (!DragState.canTransition(root.phase, nextPhase)) {
            console.warn(
                "[SystemCards] invalid drag transition",
                root.phase + " -> " + nextPhase
            );
            return;
        }
        const previous = root.phase;
        root.phase = nextPhase;
        console.log(
            "[SystemCards] drag",
            previous + " -> " + nextPhase,
            reason || ""
        );
    }

    function clearToIdle(reason) {
        const cardId = root.tileId;
        handoffWatchdogTimer.stop();
        // Move to idle before clearing sourceItem.  If the source was
        // destroyed, its automatic null assignment must not recursively
        // interpret this cleanup as a new cancellation.
        root.transition(root.idlePhase, reason || "reset");
        root.tileId = "";
        root.sourceItem = null;
        root.pointerX = 0;
        root.pointerY = 0;
        root.offsetX = 0;
        root.offsetY = 0;
        root.transferPreparing = false;
        root.transferCommitted = false;
        root.sourceWasBound = false;
        if (cardId !== "")
            console.log("[SystemCards] drag session idle", cardId);
    }

    function begin(cardId, item, x, y, offsetX, offsetY) {
        if (root.active)
            root.clearToIdle("replaced");

        root.tileId = String(cardId || "");
        root.sourceItem = item;
        root.sourceWasBound = item !== null;
        root.pointerX = Number(x) || 0;
        root.pointerY = Number(y) || 0;
        root.offsetX = Number(offsetX) || 0;
        root.offsetY = Number(offsetY) || 0;
        root.transferPreparing = false;
        root.transferCommitted = false;
        root.transition(root.draggingSidebarPhase,
            "begin " + root.tileId);
        root.started(root.tileId);
    }

    function update(x, y) {
        if (!root.active || root.phase !== root.draggingSidebarPhase)
            return;
        root.pointerX = Number(x) || 0;
        root.pointerY = Number(y) || 0;
        root.moved(root.pointerX, root.pointerY);
    }

    function freezeGhost() {
        if (root.phase !== root.draggingSidebarPhase)
            return false;
        root.transition(root.frozenTransferPhase,
            "ghost frozen " + root.tileId);
        return true;
    }

    // This is called only after SystemCardService has synchronously committed
    // container=desktop.  It deliberately does not create or destroy a Card;
    // it only records that a later source teardown must never roll ownership
    // back to the sidebar.
    function markTransferCommitted(cardId) {
        const id = String(cardId || "");
        if (!root.active || id !== root.tileId)
            return false;
        if (!root.frozen)
            root.freezeGhost();
        root.transferPreparing = false;
        root.transferCommitted = true;
        root.transferAccepted(root.tileId);
        console.log("[SystemCards] transfer committed", root.tileId);
        return true;
    }

    // Establish the visual handoff barrier before changing CardState.  The
    // desktop slot may be created synchronously by that change, but it must
    // remain hidden until its Loader has emitted cardPresented().
    function prepareVisualHandoff(cardId) {
        const id = String(cardId || "");
        if (!root.active || id !== root.tileId
                || root.transferCommitted
                || root.phase !== root.frozenTransferPhase)
            return false;
        root.transferPreparing = true;
        console.log("[SystemCards] desktop handoff preparing", id);
        return true;
    }

    // Enter the finishing phase while the ghost remains the sole visible
    // owner. The normal path ends when DesktopCardCanvas reports that the
    // real delegate is ready; the timer below is only an abnormal watchdog.
    function finishTransfer() {
        if (!root.active || !root.transferCommitted)
            return false;
        const nextPhase = DragState.finishTransfer(
            root.phase, root.transferCommitted);
        if (root.phase !== nextPhase)
            root.transition(nextPhase,
                "desktop handoff waiting " + root.tileId);
        handoffWatchdogTimer.restart();
        return true;
    }

    function completeVisualHandoff(cardId) {
        const id = String(cardId || "");
        if (!root.visualHandoffPending || id !== root.tileId)
            return false;
        console.log("[SystemCards] visual handoff ghost -> desktop", id);
        // clearToIdle changes the two visual-owner bindings in one QML turn:
        // the ghost becomes invisible before the DesktopCard waiting binding
        // can become visible in the next scene render.
        return root.finishGhost();
    }

    function finishGhost() {
        if (!root.active)
            return false;
        if (root.transferCommitted)
            console.log("[SystemCards] drag ghost finished", root.tileId);
        root.clearToIdle("ghost finished");
        root.finished();
        return true;
    }

    function end() {
        if (!root.active)
            return;
        if (root.transferCommitted) {
            root.finishTransfer();
            return;
        }
        root.finishGhost();
    }

    function cancel() {
        if (!root.active)
            return false;
        // A committed transfer is final.  Late Escape/cancel callbacks may
        // clean up the visual ghost, but they must never roll state back.
        if (root.transferCommitted)
            return root.finishTransfer();

        const canceledPhase = DragState.cancel(
            root.phase, root.transferCommitted);
        root.transition(canceledPhase, "drag canceled " + root.tileId);
        root.clearToIdle("cancel complete");
        root.canceled();
        return true;
    }

    function reset() {
        if (!root.active)
            return;
        if (root.transferCommitted)
            root.finishTransfer();
        else
            root.cancel();
    }

    // SidebarHostWindow owns exclusive keyboard focus while a sidebar is
    // open.  Before commit, route Escape to SystemView.  After commit, only
    // finish visual cleanup; never emit a rollback-capable cancel request.
    function requestCancel() {
        if (!root.active)
            return;
        if (root.transferCommitted) {
            root.finishTransfer();
            return;
        }
        root.cancelRequested(root.tileId);
    }

    onSourceItemChanged: {
        if (root.sourceItem !== null) {
            root.sourceWasBound = true;
            return;
        }
        if (!root.sourceWasBound || !root.active)
            return;

        console.log("[SystemCards] drag source destroyed", root.tileId);
        if (root.transferCommitted)
            root.finishGhost();
        else
            root.cancel();
    }

    Timer {
        id: handoffWatchdogTimer

        // This is not part of the successful handoff path. It only prevents
        // a broken/unavailable Desktop host from leaving the global session
        // active forever.
        interval: Math.max(
            1000,
            Appearance.animation.expressiveSlowSpatial.duration * 3)
        repeat: false
        onTriggered: {
            if (root.transferCommitted) {
                console.warn(
                    "[SystemCards] desktop handoff watchdog", root.tileId);
                root.finishGhost();
            } else {
                root.cancel();
            }
        }
    }
}
