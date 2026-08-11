import QtQuick 2.15
import QtTest 1.3
import "../../Modules/SystemCards/SystemCardState.js" as CardState

TestCase {
    name: "SystemCardState"

    function test_legacyMissingStateDefaultsEveryCardToSidebar() {
        const state = CardState.normalize({});
        compare(state.version, 1);
        compare(Object.keys(state.cards).length, 10);
        compare(CardState.activeSidebarIds(state).length, 10);
        compare(CardState.activeDesktopIds(state).length, 0);
        compare(state.cards.cpu.enabled, true);
        compare(state.cards.cpu.container, "sidebar");
    }

    function test_containerTransferIsSingleOwner() {
        let state = CardState.normalize({});
        state = CardState.setContainer(
            state, "cpu", "desktop", "DP-2", 0.25, 0.4);

        compare(CardState.activeSidebarIds(state).indexOf("cpu"), -1);
        compare(CardState.activeDesktopIds(state).indexOf("cpu") >= 0, true);
        compare(state.cards.cpu.screenName, "DP-2");
        compare(state.cards.cpu.desktop.xNorm, 0.25);
        compare(state.cards.cpu.desktop.yNorm, 0.4);

        state = CardState.setContainer(state, "cpu", "sidebar", "");
        compare(CardState.activeDesktopIds(state).indexOf("cpu"), -1);
        compare(CardState.activeSidebarIds(state).indexOf("cpu") >= 0, true);
    }

    function test_disabledCardKeepsItsContainerAndPosition() {
        let state = CardState.normalize({});
        state = CardState.setContainer(
            state, "weather", "desktop", "DP-1", 0.8, 0.2);
        state = CardState.setEnabled(state, "weather", false);

        compare(state.cards.weather.enabled, false);
        compare(state.cards.weather.container, "desktop");
        compare(state.cards.weather.screenName, "DP-1");
        compare(state.cards.weather.desktop.xNorm, 0.8);
        compare(state.cards.weather.desktop.yNorm, 0.2);
        compare(CardState.activeDesktopIds(state).indexOf("weather"), -1);

        state = CardState.setEnabled(state, "weather", true);
        compare(CardState.activeDesktopIds(state).indexOf("weather") >= 0,
            true);
    }

    function test_globalModeChangesDesktopCardsOnly() {
        let state = CardState.normalize({
            globalDesktopLayoutMode: "free"
        });
        state = CardState.setContainer(state, "cpu", "desktop", "DP-1");
        state = CardState.setContainer(state, "gpu", "desktop", "DP-1");
        state = CardState.setGlobalMode(state, "leastBusy");

        compare(state.globalDesktopLayoutMode, "leastBusy");
        compare(state.cards.cpu.desktop.mode, "leastBusy");
        compare(state.cards.gpu.desktop.mode, "leastBusy");
        compare(state.cards.time.desktop.mode, "free");
    }

    function test_missingOutputUsesDeterministicFallback() {
        let state = CardState.normalize({});
        state = CardState.setContainer(state, "cpu", "desktop", "DP-9");

        compare(CardState.resolvedScreenName(
            state, "cpu", ["DP-2", "DP-1"]), "DP-1");
        compare(CardState.resolvedScreenName(
            state, "cpu", []), "DP-9");
    }

    function test_serializedStateRoundTripsAsJson() {
        let state = CardState.normalize({});
        state = CardState.setContainer(
            state, "calendar", "desktop", "DP-2", 0.1, 0.9);
        state = CardState.setDesktopMode(state, "calendar", "mostBusy");
        state = CardState.setEnabled(state, "battery", false);

        const encoded = JSON.stringify(CardState.serialize(state));
        const restored = CardState.normalize(JSON.parse(encoded));
        compare(restored.version, 1);
        compare(restored.cards.calendar.container, "desktop");
        compare(restored.cards.calendar.desktop.mode, "mostBusy");
        compare(restored.cards.battery.enabled, false);
        compare(CardState.activeSidebarIds(restored).indexOf("battery"), -1);
    }

    function test_monitorOwnershipFollowsDesktopCardsNotViewport() {
        let state = CardState.normalize({});
        state = CardState.setContainer(state, "cpu", "desktop", "DP-1");
        verify(CardState.requiresMonitor(state, "cpu"));
        verify(!CardState.requiresMonitor(state, "time"));

        state = CardState.setEnabled(state, "cpu", false);
        verify(!CardState.requiresMonitor(state, "cpu"));
        state = CardState.setEnabled(state, "cpu", true);
        state = CardState.setContainer(state, "cpu", "sidebar", "");
        verify(!CardState.requiresMonitor(state, "cpu"));
    }
}
