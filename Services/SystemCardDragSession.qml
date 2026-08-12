pragma Singleton

import QtQuick
import Quickshell
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
    readonly property var frozenGhostRect: ({
        x: root.frozenGhostX,
        y: root.frozenGhostY,
        width: root.frozenGhostWidth,
        height: root.frozenGhostHeight,
        valid: root.frozenGhostRectValid
    })
    property real frozenGhostX: 0
    property real frozenGhostY: 0
    property real frozenGhostWidth: 0
    property real frozenGhostHeight: 0
    property bool frozenGhostRectValid: false
    property bool sourceWasBound: false

    signal started(string cardId)
    signal moved(real x, real y)
    signal finished()
    signal canceled()
    signal transferAccepted(string cardId)
    signal handoffCheckRequested(string cardId)
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
        root.frozenGhostX = 0;
        root.frozenGhostY = 0;
        root.frozenGhostWidth = 0;
        root.frozenGhostHeight = 0;
        root.frozenGhostRectValid = false;
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
        const source = root.sourceItem;
        root.frozenGhostX = root.pointerX - root.offsetX;
        root.frozenGhostY = root.pointerY - root.offsetY;
        root.frozenGhostWidth = source ? Number(source.width) : 0;
        root.frozenGhostHeight = source ? Number(source.height) : 0;
        root.frozenGhostRectValid = root.frozenGhostWidth > 0
            && root.frozenGhostHeight > 0;
        console.log(
            "[SystemCards] frozen ghost rect",
            root.tileId,
            "x=" + root.frozenGhostX,
            "y=" + root.frozenGhostY,
            "size=" + root.frozenGhostWidth + "x"
                + root.frozenGhostHeight
        );
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
        // Keep the visual barrier continuously asserted. Setting preparing
        // false first creates a transient pending=false state before the
        // committed flag becomes visible to QML bindings.
        root.transferCommitted = true;
        root.transferPreparing = false;
        root.transferAccepted(id);
        console.log("[SystemCards] transfer committed", id);
        return true;
    }

    // Request the DesktopCard readiness check only after markTransferCommitted
    // has returned to its caller. Completing the handoff from an
    // onTransferCommittedChanged handler mutates the same properties while Qt
    // is still evaluating their bindings and can leave the desktop delegate
    // permanently hidden behind a stale waiting=true value.
    function requestVisualHandoffCheck(cardId) {
        const id = String(cardId || "");
        if (!root.transferCommitted || !root.visualHandoffPending
                || id !== root.tileId)
            return false;
        root.handoffCheckRequested(id);
        return true;
    }

    // Establish the visual handoff barrier before changing CardState.  The
    // desktop slot may be created synchronously by that change, but it must
    // remain hidden until its Loader has initialized the screen rect and
    // emitted handoffReady.
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

    // Enter the finishing phase while the visual handoff barrier remains
    // active. The sidebar source may disappear before DesktopCardCanvas has
    // consumed the frozen rect; that teardown must not end this phase.
    function finishTransfer() {
        if (!root.active || !root.transferCommitted)
            return false;
        const nextPhase = DragState.finishTransfer(
            root.phase, root.transferCommitted);
        if (root.phase !== nextPhase)
            root.transition(nextPhase,
                "desktop handoff waiting " + root.tileId);
        return true;
    }

    function completeVisualHandoff(cardId) {
        const id = String(cardId || "");
        if (!root.transferCommitted || !root.visualHandoffPending
                || id !== root.tileId)
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
        if (root.transferCommitted) {
            // Once ownership is committed, the sidebar source lifetime is no
            // longer authoritative. The DesktopCard still has to consume the
            // frozen geometry and complete the visual handoff. In particular,
            // do not clear the phase, tileId, commit flag, or frozen rect here.
            // sourceItem destruction is not handoff completion.
            console.log(
                "[SystemCards] preserving committed desktop handoff",
                root.tileId
            );
        } else {
            root.cancel();
        }
    }
}
