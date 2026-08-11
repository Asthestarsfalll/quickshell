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
}
