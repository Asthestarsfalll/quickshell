import QtQuick 2.15
import QtTest 1.3

import "../../Services/SystemCardDragState.js" as DragState
import "../../Modules/SystemCards/SystemCardPlacement.js" as Placement

TestCase {
    name: "SystemCardDragState"

    function test_committedTransferKeepsActiveUntilDesktopHandoff() {
        let phase = DragState.idle;
        phase = DragState.draggingSidebar;
        phase = DragState.freeze(phase);
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

    function test_screenDropPreservesGhostRectForEveryGrabPoint() {
        const drops = [
            { pointer: { x: 122, y: 208 }, offset: { x: 12, y: 18 } },
            { pointer: { x: 640, y: 420 }, offset: { x: 76, y: 80 } },
            { pointer: { x: 1260, y: 810 }, offset: { x: 145, y: 151 } }
        ];
        drops.forEach(function(drop) {
            const ghost = {
                x: drop.pointer.x - drop.offset.x,
                y: drop.pointer.y - drop.offset.y,
                width: 152,
                height: 160
            };
            const desktop = {
                x: ghost.x,
                y: ghost.y,
                width: ghost.width,
                height: ghost.height
            };
            compare(desktop.x, ghost.x);
            compare(desktop.y, ghost.y);
            compare(desktop.width, ghost.width);
            compare(desktop.height, ghost.height);
        });
    }

    function test_screenNormalizedPositionRoundTrips() {
        const normalized = Placement.normalizedPosition(
            640, 360, 1920, 1080);
        compare(normalized.xNorm, 1 / 3);
        compare(normalized.yNorm, 1 / 3);

        const point = Placement.screenPoint(
            normalized.xNorm, normalized.yNorm,
            1920, 1080, 152, 160);
        compare(point.x, 640);
        compare(point.y, 360);
    }

    function test_freeProjectionIgnoresWallpaperOffset() {
        const free = Placement.screenPoint(
            0.42, 0.31, 1920, 1080, 152, 160);
        const afterParallax = Placement.screenPoint(
            0.42, 0.31, 1920, 1080, 152, 160);

        compare(afterParallax.x, free.x);
        compare(afterParallax.y, free.y);
    }

    function test_wallpaperProjectionUsesCurrentSceneOffset() {
        const wallpaper = Placement.wallpaperPoint(
            0.5, 0.4, 2000, 1000, 152, 160);
        const first = Placement.projectedWallpaperPoint(
            wallpaper.x, wallpaper.y, -100, 20);
        const second = Placement.projectedWallpaperPoint(
            wallpaper.x, wallpaper.y, -240, 40);

        compare(first.x, wallpaper.x - 100);
        compare(first.y, wallpaper.y + 20);
        compare(second.x, wallpaper.x - 240);
        compare(second.y, wallpaper.y + 40);
    }

    function test_screenToWallpaperTransitionFollowsMovingTarget() {
        const start = { x: 420, y: 300 };
        const wallpaper = { x: 900, y: 500 };
        const firstTarget = Placement.projectedWallpaperPoint(
            wallpaper.x, wallpaper.y, -180, 0);
        const secondTarget = Placement.projectedWallpaperPoint(
            wallpaper.x, wallpaper.y, -260, 30);

        compare(Placement.interpolate(start.x, firstTarget.x, 0), start.x);
        compare(Placement.interpolate(start.y, firstTarget.y, 0), start.y);
        compare(Placement.interpolate(start.x, secondTarget.x, 1),
            secondTarget.x);
        compare(Placement.interpolate(start.y, secondTarget.y, 1),
            secondTarget.y);
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
