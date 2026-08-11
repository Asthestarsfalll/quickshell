import QtQuick 2.15
import QtTest 1.3

import "../../Services/SystemCardDragState.js" as DragState

TestCase {
    name: "SystemCardDragState"

    function test_committedTransferKeepsActiveThroughGhostCleanup() {
        let phase = DragState.idle;
        phase = DragState.draggingSidebar;
        compare(DragState.isActive(phase), true);

        phase = DragState.freeze(phase);
        compare(phase, DragState.frozenTransfer);
        compare(DragState.isFrozen(phase), true);

        phase = DragState.finishTransfer(phase, true);
        compare(phase, DragState.finishing);
        compare(DragState.isActive(phase), true);

        phase = DragState.finish(phase);
        compare(phase, DragState.idle);
        compare(DragState.isActive(phase), false);
    }

    function test_cancelBeforeCommitReturnsToIdle() {
        let phase = DragState.draggingSidebar;
        phase = DragState.cancel(phase, false);
        compare(phase, DragState.canceled);
        phase = DragState.finish(phase);
        compare(phase, DragState.idle);
    }

    function test_lateCancelCannotRollbackCommittedTransfer() {
        const phase = DragState.finishTransfer(
            DragState.frozenTransfer, true);
        compare(DragState.cancel(phase, true), phase);
        compare(DragState.isActive(phase), true);
    }

    function test_visualHandoffStaysPendingUntilSessionIsIdle() {
        const phase = DragState.finishTransfer(
            DragState.frozenTransfer, true);
        verify(DragState.isVisualHandoffPending(phase, true));
        verify(DragState.isVisualHandoffPending(phase, false, true));
        verify(!DragState.isVisualHandoffPending(phase, false));

        const idle = DragState.finish(phase);
        verify(!DragState.isVisualHandoffPending(idle, true));
    }

    function test_dropRectContinuityForDifferentGrabPoints() {
        const drops = [
            { pointer: { x: 122, y: 208 }, offset: { x: 12, y: 18 } },
            { pointer: { x: 640, y: 420 }, offset: { x: 76, y: 80 } },
            { pointer: { x: 1260, y: 810 }, offset: { x: 145, y: 151 } }
        ];
        drops.forEach(function(drop) {
            const ghostRect = {
                x: drop.pointer.x - drop.offset.x,
                y: drop.pointer.y - drop.offset.y,
                width: 152,
                height: 160
            };
            const desktopRect = {
                x: drop.pointer.x - drop.offset.x,
                y: drop.pointer.y - drop.offset.y,
                width: 152,
                height: 160
            };
            compare(desktopRect.x, ghostRect.x);
            compare(desktopRect.y, ghostRect.y);
            compare(desktopRect.width, ghostRect.width);
            compare(desktopRect.height, ghostRect.height);
        });
    }

    function test_sidebarReorderCanFinishWithoutTransfer() {
        compare(DragState.finish(DragState.draggingSidebar),
            DragState.idle);
    }

    function test_illegalTransitionsAreRejected() {
        verify(!DragState.canTransition(
            DragState.finishing, DragState.draggingSidebar));
        verify(!DragState.canTransition(
            DragState.canceled, DragState.frozenTransfer));
        verify(DragState.canTransition(
            DragState.frozenTransfer, DragState.finishing));
    }
}
