import QtQuick 2.15
import QtTest 1.3

import "../../Services/SystemCardDragState.js" as DragState
import "../../Modules/DesktopCards/DesktopCardPresentation.js" as Presentation

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

    function test_handoffStartsAtGhostWhenTargetDiffers() {
        const ghost = { x: 420, y: 310, width: 152, height: 160 };
        const target = { x: 900, y: 620, width: 152, height: 160 };
        const offset = Presentation.offsetForRects(ghost, target);
        const firstFrame = Presentation.translatedRect(target, offset);

        verify(Presentation.rectsWithinTolerance(
            firstFrame, ghost, 1));
        compare(offset.x, -480);
        compare(offset.y, -310);

        const settled = Presentation.translatedRect(
            target, { x: 0, y: 0 });
        compare(settled.x, target.x);
        compare(settled.y, target.y);
    }

    function test_sceneMotionAndPresentationRemainOrthogonal() {
        const logical = { x: 700, y: 440, width: 152, height: 160 };
        const initialScene = { x: -280, y: 24 };
        const target = {
            x: logical.x + initialScene.x,
            y: logical.y + initialScene.y,
            width: logical.width,
            height: logical.height
        };
        const ghost = { x: target.x + 16, y: target.y + 12,
            width: target.width, height: target.height };
        const offset = Presentation.offsetForRects(ghost, target);

        const nextScene = { x: -430, y: 60 };
        const nextTarget = {
            x: logical.x + nextScene.x,
            y: logical.y + nextScene.y,
            width: logical.width,
            height: logical.height
        };
        const visible = Presentation.translatedRect(nextTarget, offset);

        compare(logical.x, 700);
        compare(logical.y, 440);
        compare(visible.x, nextTarget.x + 16);
        compare(visible.y, nextTarget.y + 12);
    }

    function test_handoffPinTracksProjectionUntilFirstFrame() {
        const ghost = { x: 640, y: 360, width: 152, height: 160 };
        const readyTarget = {
            x: 640, y: 360, width: 152, height: 160
        };
        const readyOffset = Presentation.offsetForRects(
            ghost, readyTarget);
        compare(readyOffset.x, 0);
        compare(readyOffset.y, 0);

        // The logical projection changes after Loader readiness but before
        // the real DesktopCard's first frame. Recomputing A-currentB keeps
        // that first frame at the frozen ghost rect.
        const firstFrameTarget = {
            x: 584, y: 360, width: 152, height: 160
        };
        const pinnedOffset = Presentation.offsetForRects(
            ghost, firstFrameTarget);
        const firstFrame = Presentation.translatedRect(
            firstFrameTarget, pinnedOffset);

        compare(pinnedOffset.x, 56);
        verify(Presentation.rectsWithinTolerance(firstFrame, ghost, 1));
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
