import QtQuick
import qs.Common
import qs.Services

Item {
    id: root

    property var panelScreen: null
    property int sidebarWidth: 420
    property int gap: 24
    property int qsTargetHeight: 640
    readonly property int sidebarY: Sizes.barHeight + gap
    readonly property real closedSlideOffset: sidebarWidth + gap
    readonly property int enterDuration: Animations.durations.large
    readonly property int exitDuration: Animations.durations.large
    readonly property bool panelActive: WidgetState.qsOpen
        || Math.abs(animController.slideOffset - closedSlideOffset) > 0.5
    property bool contentLoaderActive: true
    property bool closingPresentationLatched: false

    function ensureContentLoaded() {
        deferredUnload.stop();
        root.contentLoaderActive = true;
        root.closingPresentationLatched = false;
    }

    function releaseContent(preserveClosingPresentation) {
        deferredUnload.stop();

        if (WidgetState.qsOpen
                || root.panelActive
                || PersonalizationConfig.keepSidebarsLoaded) {
            root.ensureContentLoaded();
            return;
        }

        if (preserveClosingPresentation && root.contentLoaderActive) {
            root.closingPresentationLatched = true;
            deferredUnload.start();
            return;
        }

        root.closingPresentationLatched = false;
        root.contentLoaderActive = false;
    }

    onPanelActiveChanged: {
        if (root.panelActive)
            root.ensureContentLoaded();
        else
            root.releaseContent(true);
    }

    Component.onCompleted: {
        if (WidgetState.qsOpen
                || PersonalizationConfig.keepSidebarsLoaded)
            root.ensureContentLoaded();
        else
            root.releaseContent(false);
    }

    Connections {
        target: PersonalizationConfig

        function onKeepSidebarsLoadedChanged() {
            if (PersonalizationConfig.keepSidebarsLoaded)
                root.ensureContentLoaded();
            else
                root.releaseContent(false);
        }
    }

    Connections {
        target: WidgetState

        function onQsOpenChanged() {
            if (WidgetState.qsOpen)
                root.ensureContentLoaded();
        }
    }

    function containsPoint(hostX, hostY) {
        const localPosition =
            sidebarContentFrame.mapFromItem(root, hostX, hostY);
        return localPosition.x >= 0
            && localPosition.x <= sidebarContentFrame.width
            && localPosition.y >= 0
            && localPosition.y <= sidebarContentFrame.height;
    }

    Item {
        id: animController

        property real slideOffset: root.closedSlideOffset

        state: WidgetState.qsOpen ? "open" : "closed"

        states: [
            State {
                name: "open"

                PropertyChanges {
                    target: animController
                    slideOffset: 0
                }
            },
            State {
                name: "closed"

                PropertyChanges {
                    target: animController
                    slideOffset: root.closedSlideOffset
                }
            }
        ]

        transitions: [
            Transition {
                to: "open"

                NumberAnimation {
                    target: animController
                    property: "slideOffset"
                    duration: root.enterDuration
                    easing.type: Easing.OutBack
                    easing.overshoot: 0.3
                }
            },
            Transition {
                to: "closed"

                NumberAnimation {
                    target: animController
                    property: "slideOffset"
                    duration: root.exitDuration
                    easing.type: Easing.InBack
                    easing.overshoot: 0.18
                }
            }
        ]
    }

    Timer {
        id: deferredUnload

        interval: 0
        repeat: false
        onTriggered: {
            if (!WidgetState.qsOpen
                    && !root.panelActive
                    && !PersonalizationConfig.keepSidebarsLoaded) {
                root.contentLoaderActive = false;
            }
            root.closingPresentationLatched = false;
        }
    }

    Rectangle {
        id: panelSurface

        visible: root.panelActive
        x: root.width - root.sidebarWidth - root.gap
            + animController.slideOffset
        y: root.sidebarY
        width: root.sidebarWidth
        height: Math.min(root.qsTargetHeight,
            Math.max(0, root.height - root.sidebarY - root.gap))
        color: Appearance.colors.colLayer0
        radius: Appearance.rounding.large
    }

    Item {
        id: sidebarContentFrame

        visible: root.panelActive
        x: panelSurface.x
        y: panelSurface.y
        width: panelSurface.width
        height: panelSurface.height
        clip: true

        Loader {
            anchors.fill: parent
            active: root.contentLoaderActive
            sourceComponent: quickSettingsComponent
        }
    }

    Component {
        id: quickSettingsComponent

        QuickSettings {
            anchors.fill: parent
            screen: root.panelScreen
            foreground: WidgetState.qsOpen
            presentationActive: root.panelActive
                || root.closingPresentationLatched
        }
    }
}
