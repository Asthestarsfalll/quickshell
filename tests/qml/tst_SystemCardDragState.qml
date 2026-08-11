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
