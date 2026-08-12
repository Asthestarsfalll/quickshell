import QtQuick 2.15
import QtTest 1.3
import "../../Modules/DesktopCards/DesktopCardLayout.js" as DesktopCardLayout
import "../../Modules/SystemCards/SystemCardGeometry.js" as CardGeometry

TestCase {
    name: "DesktopCardLayout"

    function realisticAnalysis() {
        return {
            valid: true,
            busyScore: function(x, y, width, height) {
                const center = Number(x) + Number(width) / 2;
                if (center < 250)
                    return 0.018;
                if (center < 500)
                    return 0.035;
                if (center < 750)
                    return 0.084;
                return 0.112;
            }
        };
    }

    function canonicalCard(id, xNorm, yNorm) {
        const size = CardGeometry.sizeFor(id);
        return {
            id: id,
            width: size.width,
            height: size.height,
            xNorm: xNorm,
            yNorm: yNorm
        };
    }

    function test_globalAutomaticCardsNeverOverlapWithCanonicalGeometry() {
        const cards = [
            canonicalCard("weather", 0.03, 0.03),
            canonicalCard("storage", 0.05, 0.05),
            canonicalCard("network", 0.8, 0.1),
            canonicalCard("cpu", 0.4, 0.6)
        ];
        const placements = DesktopCardLayout.solve(
            cards, 1800, 1000, realisticAnalysis(), "leastBusy");

        compare(placements.length, cards.length);
        verify(DesktopCardLayout.hasNoOverlap(placements, 12));
        placements.forEach(function(placement) {
            const source = cards.find(item => item.id === placement.id);
            compare(placement.rect.width, source.width);
            compare(placement.rect.height, source.height);
        });
    }

    function test_leastAndMostBusyPreferDifferentRealisticRegions() {
        const leastCards = [canonicalCard("cpu", 0.58, 0.45)];
        const mostCards = [canonicalCard("cpu", 0.18, 0.45)];
        const least = DesktopCardLayout.solve(
            leastCards, 1000, 700, realisticAnalysis(), "leastBusy")[0];
        const most = DesktopCardLayout.solve(
            mostCards, 1000, 700, realisticAnalysis(), "mostBusy")[0];

        verify(least !== undefined);
        verify(most !== undefined);
        verify(least.xNorm < 0.35);
        verify(most.xNorm > 0.55);
        verify(Math.abs(least.xNorm - most.xNorm) > 0.2);
    }

    function test_currentPositionIsNotAnAbsoluteBusyScoreBias() {
        const card = canonicalCard("cpu", 0.58, 0.45);
        const placement = DesktopCardLayout.solve(
            [card], 1000, 700, realisticAnalysis(), "leastBusy")[0];

        verify(placement !== undefined);
        // The current point is in the 0.084 region; the 0.018 region must win
        // despite requiring movement.
        verify(placement.xNorm < 0.35);
    }

    function test_freeModeDoesNotRunWallpaperSolver() {
        const placements = DesktopCardLayout.solve([
            canonicalCard("cpu", 0.62, 0.48)
        ], 1000, 700, realisticAnalysis(), "free");
        compare(placements.length, 0);
    }

    function test_autoModeProducesAllCardsWhenThereIsRoom() {
        const cards = [
            canonicalCard("weather", 0.1, 0.1),
            canonicalCard("battery", 0.3, 0.2),
            canonicalCard("storage", 0.5, 0.4)
        ];
        const placements = DesktopCardLayout.solve(
            cards, 1800, 1000, realisticAnalysis(), "mostBusy");
        compare(placements.length, cards.length);
        verify(DesktopCardLayout.hasNoOverlap(placements, 12));
    }

    function test_invalidAnalysisStillUsesDeterministicWallpaperPlacement() {
        const cards = [
            canonicalCard("weather", 0.1, 0.1),
            canonicalCard("cpu", 0.4, 0.5)
        ];
        const placements = DesktopCardLayout.solve(
            cards, 1800, 1000, { valid: false }, "leastBusy");

        compare(placements.length, cards.length);
        verify(DesktopCardLayout.hasNoOverlap(placements, 12));
    }

    function test_screenAnchorModesPackInsideBoundsWithoutOverlap() {
        const cards = [
            canonicalCard("weather", 0.1, 0.1),
            canonicalCard("storage", 0.2, 0.2),
            canonicalCard("battery", 0.4, 0.4),
            canonicalCard("cpu", 0.6, 0.6),
            canonicalCard("gpu", 0.7, 0.7)
        ];
        const modes = [
            "screenTopLeft", "screenTopRight", "screenBottomLeft",
            "screenBottomRight", "screenCenter"
        ];
        modes.forEach(function(mode) {
            const placements = DesktopCardLayout.solveScreen(
                cards, 1600, 1000, mode);
            compare(placements.length, cards.length);
            verify(DesktopCardLayout.hasNoOverlap(placements, 12));
            placements.forEach(function(placement) {
                verify(placement.rect.x >= 24 - 0.01);
                verify(placement.rect.y >= 24 - 0.01);
                verify(placement.rect.x + placement.rect.width
                    <= 1600 - 24 + 0.01);
                verify(placement.rect.y + placement.rect.height
                    <= 1000 - 24 + 0.01);
            });
        });
    }

    function test_screenAnchorModesAreDeterministicAndDistinct() {
        const cards = [canonicalCard("weather", 0.5, 0.5)];
        const topLeft = DesktopCardLayout.solveScreen(
            cards, 1200, 800, "screenTopLeft")[0];
        const bottomRight = DesktopCardLayout.solveScreen(
            cards, 1200, 800, "screenBottomRight")[0];
        const center = DesktopCardLayout.solveScreen(
            cards, 1200, 800, "screenCenter")[0];
        const repeat = DesktopCardLayout.solveScreen(
            cards, 1200, 800, "screenCenter")[0];

        verify(topLeft.rect.x < center.rect.x);
        verify(topLeft.rect.y < center.rect.y);
        verify(bottomRight.rect.x > center.rect.x);
        verify(bottomRight.rect.y > center.rect.y);
        compare(repeat.xNorm, center.xNorm);
        compare(repeat.yNorm, center.yNorm);
    }

    function test_draggedCardIsAuthoritativeDuringCollisionResolution() {
        const cards = [
            { id: "cpu", x: 100, y: 100, width: 152, height: 160 },
            { id: "gpu", x: 100, y: 100, width: 152, height: 160 },
            { id: "memoryUsed", x: 270, y: 100, width: 152, height: 160 },
            { id: "wifi", x: 440, y: 100, width: 152, height: 160 }
        ];
        const resolved = DesktopCardLayout.resolveDraggedCollision(
            cards, "cpu",
            { x: 100, y: 100, width: 152, height: 160 },
            1000, 700);
        const dragged = resolved.find(item => item.id === "cpu");

        verify(dragged !== undefined);
        compare(dragged.x, 100);
        compare(dragged.y, 100);
        verify(DesktopCardLayout.hasNoOverlap(resolved, 12));
    }

    function test_sidebarDropKeepsIncomingCardAndMovesExistingCard() {
        const cards = [
            { id: "cpu", x: 420, y: 260, width: 152, height: 160 },
            { id: "battery", x: 40, y: 40, width: 152, height: 320 }
        ];
        const resolved = DesktopCardLayout.resolveDraggedCollision(
            cards, "battery",
            { x: 420, y: 260, width: 152, height: 320 },
            1400, 900);
        const incoming = resolved.find(item => item.id === "battery");
        const existing = resolved.find(item => item.id === "cpu");

        verify(incoming !== undefined);
        verify(existing !== undefined);
        compare(incoming.x, 420);
        compare(incoming.y, 260);
        verify(existing.x !== 420 || existing.y !== 260);
        verify(DesktopCardLayout.hasNoOverlap(resolved, 12));
    }

    function test_fullCollisionResolverHandlesCascadingAvoidance() {
        const cards = [
            { id: "cpu", x: 300, y: 300, width: 152, height: 160 },
            { id: "gpu", x: 300, y: 300, width: 152, height: 160 },
            { id: "memoryUsed", x: 300, y: 300, width: 152, height: 160 },
            { id: "wifi", x: 300, y: 300, width: 152, height: 160 }
        ];
        const resolved = DesktopCardLayout.resolveAllCollisions(
            cards, "cpu", 1600, 1000);

        compare(resolved.length, cards.length);
        verify(DesktopCardLayout.hasNoOverlap(resolved, 12));
        const cpu = resolved.find(item => item.id === "cpu");
        compare(cpu.x, 300);
        compare(cpu.y, 300);
    }

    function test_collisionSearchUsesWholeAvailableCanvas() {
        const cards = [
            { id: "cpu", x: 760, y: 420, width: 152, height: 160 },
            { id: "gpu", x: 760, y: 420, width: 152, height: 160 }
        ];
        const resolved = DesktopCardLayout.resolveDraggedCollision(
            cards, "cpu",
            { x: 760, y: 420, width: 152, height: 160 },
            2400, 1400);
        const gpu = resolved.find(item => item.id === "gpu");

        verify(gpu !== undefined);
        verify(DesktopCardLayout.hasNoOverlap(resolved, 12));
        verify(gpu.x !== 760 || gpu.y !== 420);
        verify(gpu.x >= 0 && gpu.y >= 0);
        verify(gpu.x + gpu.width <= 2400);
        verify(gpu.y + gpu.height <= 1400);
    }

    function test_collisionResolutionIsDeterministicAndBounded() {
        const cards = [
            { id: "a", x: 0, y: 0, width: 200, height: 180 },
            { id: "b", x: 0, y: 0, width: 180, height: 160 },
            { id: "c", x: 0, y: 0, width: 160, height: 140 }
        ];
        const first = DesktopCardLayout.resolveDraggedCollision(
            cards, "a", { x: 20, y: 20, width: 200, height: 180 },
            1200, 800);
        const second = DesktopCardLayout.resolveDraggedCollision(
            cards, "a", { x: 20, y: 20, width: 200, height: 180 },
            1200, 800);

        compare(JSON.stringify(first), JSON.stringify(second));
        verify(DesktopCardLayout.hasNoOverlap(first, 12));
        first.forEach(function(item) {
            verify(item.x >= -0.01);
            verify(item.y >= -0.01);
            verify(item.x + item.width <= 1200 + 0.01);
            verify(item.y + item.height <= 800 + 0.01);
        });
    }
}
