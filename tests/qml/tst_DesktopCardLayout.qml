import QtQuick 2.15
import QtTest 1.3
import "../../Modules/DesktopCards/DesktopCardLayout.js" as DesktopCardLayout

TestCase {
    name: "DesktopCardLayout"

    function syntheticAnalysis() {
        return {
            busyScore: function(x, y, width, height) {
                // The right half is deliberately busy; this makes the
                // least/most-busy choices observable without image I/O.
                return (Number(x) + Number(width) / 2) >= 500 ? 1 : 0;
            }
        };
    }

    function test_mixedCardsNeverOverlap() {
        const cards = [
            { id: "time", width: 260, height: 180,
                xNorm: 0.03, yNorm: 0.03, mode: "free" },
            { id: "weather", width: 320, height: 200,
                xNorm: 0.05, yNorm: 0.05, mode: "leastBusy" },
            { id: "cpu", width: 220, height: 160,
                xNorm: 0.8, yNorm: 0.1, mode: "mostBusy" },
            { id: "network", width: 280, height: 150,
                xNorm: 0.4, yNorm: 0.6, mode: "leastBusy" }
        ];
        const placements = DesktopCardLayout.solve(
            cards, 1000, 700, syntheticAnalysis());

        compare(placements.length, cards.length);
        verify(DesktopCardLayout.hasNoOverlap(placements, 12));
    }

    function test_autoModesPreferDifferentBusyRegions() {
        const cards = [
            { id: "least", width: 160, height: 140,
                xNorm: 0.5, yNorm: 0.5, mode: "leastBusy" },
            { id: "most", width: 160, height: 140,
                xNorm: 0.5, yNorm: 0.5, mode: "mostBusy" }
        ];
        const placements = DesktopCardLayout.solve(
            cards, 1000, 700, syntheticAnalysis());
        verify(DesktopCardLayout.hasNoOverlap(placements, 12));

        const least = placements.find(item => item.id === "least");
        const most = placements.find(item => item.id === "most");
        verify(least !== undefined);
        verify(most !== undefined);
        verify(least.xNorm < most.xNorm);
    }

    function test_freePositionIsPreferredWhenAvailable() {
        const placements = DesktopCardLayout.solve([
            { id: "free", width: 180, height: 140,
                xNorm: 0.62, yNorm: 0.48, mode: "free" }
        ], 1000, 700, syntheticAnalysis());
        compare(placements.length, 1);
        compare(Math.round(placements[0].xNorm * 100), 62);
        compare(Math.round(placements[0].yNorm * 100), 48);
    }

    function test_focusedModeChangeKeepsOtherCardsFixed() {
        const cards = [
            { id: "fixed", width: 220, height: 160,
                xNorm: 0.05, yNorm: 0.05, mode: "free" },
            { id: "focus", width: 180, height: 140,
                xNorm: 0.32, yNorm: 0.05, mode: "mostBusy" }
        ];
        const placements = DesktopCardLayout.solve(
            cards, 1000, 700, syntheticAnalysis(), "focus");
        const fixed = placements.find(item => item.id === "fixed");
        compare(Math.round(fixed.xNorm * 100), 5);
        compare(Math.round(fixed.yNorm * 100), 5);
        verify(DesktopCardLayout.hasNoOverlap(placements, 12));
    }
}
