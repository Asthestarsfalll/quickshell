import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Common
import qs.Modules.Sidebars.Left
import qs.Modules.Sidebars.Right
import qs.Services
import qs.Widgets.common

PanelWindow {
    id: root

    readonly property bool developmentRuntime:
        Paths.runtimeMode.startsWith("development")
            && Paths.sourceRoot !== ""
    property bool weatherPreviewActive: false

    function sidebarOpen(side) {
        const normalized = String(side || "").toLowerCase();
        if (normalized === "left")
            return WidgetState.leftSidebarOpen;
        if (normalized === "right")
            return WidgetState.qsOpen;
        return null;
    }

    function setSidebarOpen(side, open) {
        const normalized = String(side || "").toLowerCase();
        if (normalized === "left") {
            WidgetState.leftSidebarOpen = open;
            return open ? "LEFT_OPEN" : "LEFT_CLOSED";
        }
        if (normalized === "right") {
            WidgetState.qsOpen = open;
            return open ? "RIGHT_OPEN" : "RIGHT_CLOSED";
        }
        return "INVALID_SIDE";
    }

    function openWeatherPreview() {
        if (!root.developmentRuntime)
            return "DEVELOPMENT_ONLY";
        if (!developerWeatherSource.item)
            return "MOCK_UNAVAILABLE";

        root.weatherPreviewActive = true;
        WidgetState.qsOpen = false;
        WidgetState.leftSidebarView = "weather";
        WidgetState.leftSidebarOpen = true;
        return "WEATHER_PREVIEW_OPEN";
    }

    readonly property bool anySidebarOpen:
        WidgetState.leftSidebarOpen || WidgetState.qsOpen
    readonly property var fallbackScreen: Brightness.activeScreen
        || (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
    // DPMS cycles can replace the Screen instance while preserving its name.
    property string retainedScreenName: ""
    readonly property var retainedScreen:
        Brightness.getScreenByName(retainedScreenName)

    screen: retainedScreen || fallbackScreen
    visible: retainedScreen !== null || fallbackScreen !== null
    color: "transparent"
    implicitWidth: screen ? screen.width : 1920
    implicitHeight: screen ? screen.height : 1080
    exclusiveZone: 0

    anchors {
        left: true
        top: true
        right: true
        bottom: true
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "clavis-shell-sidebars"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: root.anySidebarOpen
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    IpcHandler {
        target: "sidebar"

        function open(side: string): string {
            return root.setSidebarOpen(side, true);
        }

        function close(side: string): string {
            return root.setSidebarOpen(side, false);
        }

        function toggle(side: string): string {
            const current = root.sidebarOpen(side);
            if (current === null)
                return "INVALID_SIDE";
            return root.setSidebarOpen(side, !current);
        }

        function previewWeather(): string {
            return root.openWeatherPreview();
        }
    }

    // The development source is loaded synchronously before an IPC request so
    // WeatherView never renders a first frame from WeatherPlugin and then swaps
    // to the mock. Release shells neither resolve nor instantiate this file.
    Loader {
        id: developerWeatherSource

        active: root.developmentRuntime
        source: active
            ? Paths.fileUrl(Paths.sourceRoot
                + "/tests/manual/weather_preview/MockWeatherSource.qml")
            : ""
    }

    mask: Region {
        item: root.anySidebarOpen ? interactionRegion : null
    }

    Component.onCompleted: {
        if (root.fallbackScreen)
            root.retainedScreenName = root.fallbackScreen.name;
        if (root.anySidebarOpen)
            Qt.callLater(() => keyGateway.forceActiveFocus());
    }

    onAnySidebarOpenChanged: {
        if (root.anySidebarOpen)
            Qt.callLater(() => keyGateway.forceActiveFocus());
    }

    Connections {
        target: WidgetState

        function onQsScreenNameChanged() {
            const requestedScreen =
                Brightness.getScreenByName(WidgetState.qsScreenName);
            if (requestedScreen)
                root.retainedScreenName = requestedScreen.name;
        }

        function onLeftSidebarOpenChanged() {
            if (WidgetState.leftSidebarOpen && !WidgetState.qsOpen
                    && Brightness.activeScreen)
                root.retainedScreenName = Brightness.activeScreen.name;
        }
    }

    Item {
        id: interactionRegion

        anchors.fill: parent
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.anySidebarOpen
        acceptedButtons: Qt.LeftButton

        onClicked: mouse => {
            if (WidgetState.leftSidebarOpen
                    && !leftSidebar.containsPoint(mouse.x, mouse.y))
                WidgetState.leftSidebarOpen = false;

            if (WidgetState.qsOpen
                    && !rightSidebar.containsPoint(mouse.x, mouse.y))
                WidgetState.qsOpen = false;
        }
    }

    LeftSidebarWindow {
        id: leftSidebar

        anchors.fill: parent
        panelScreen: root.screen
        weatherSourceOverride: root.weatherPreviewActive
            ? developerWeatherSource.item : null

        onPresentationClosed: root.weatherPreviewActive = false
    }

    RightSidebar {
        id: rightSidebar

        anchors.fill: parent
        panelScreen: root.screen
    }

    CompositorBlurRegion {
        targetWindow: root
        backgroundItem: leftSidebar.blurBackgroundItem
        additionalBackgroundItems: [
            rightSidebar.blurBackgroundItem
        ]
    }

    Item {
        id: keyGateway

        anchors.fill: parent
        focus: root.anySidebarOpen

        Keys.onEscapePressed: event => {
            WidgetState.closeAllPopups();
            event.accepted = true;
        }
    }
}
