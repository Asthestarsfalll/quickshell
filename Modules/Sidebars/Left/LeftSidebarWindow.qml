import QtQuick
import qs.Common
import qs.Services

Item {
    id: root

    signal presentationClosed()

    property var panelScreen: null
    property real sidebarWidth: Metrics.sidebarWidthComfortable
    property int gap: 24
    readonly property alias blurBackgroundItem: blurRegionAnchor
    // The host window already starts inside layer-shell's usable geometry.
    readonly property int sidebarY: gap
    readonly property real closedSlideOffset: -(sidebarWidth + gap)
    readonly property int enterDuration: Animations.durations.sidebarEnter
    readonly property int exitDuration: Animations.durations.sidebarExit
    readonly property int qsTargetHeight:
        Math.max(0, height - sidebarY - gap)
    property bool panelPresented: false
    property bool contentRetained: false
    property bool blurActive: false
    property bool contentActive: false
    property bool keepLoaded:
        PersonalizationConfig.keepSidebarsLoaded
    property var weatherSourceOverride: null
    readonly property bool panelVisuallyPresent:
        WidgetState.leftSidebarOpen || panelPresented
    readonly property string activeView: WidgetState.leftSidebarView
    readonly property int instantiatedViewCount:
        sidebarContentLoader.item
            ? sidebarContentLoader.item.instantiatedViewCount : 0
    readonly property var weatherView:
        sidebarContentLoader.item
            ? sidebarContentLoader.item.weatherView : null
    readonly property var systemCardBlurExclusionItems:
        root.blurActive && root.activeView === "sys"
            && sidebarContentLoader.item
            ? sidebarContentLoader.item.systemCardBlurExclusionItems : []

    function beginPresentation() {
        panelPresented = true
        contentRetained = true
        blurActive = false
        contentActive = false
    }

    function finishOpening() {
        if (!WidgetState.leftSidebarOpen)
            return

        blurActive = true
        contentActive = true
    }

    function finishClosing() {
        if (WidgetState.leftSidebarOpen)
            return

        // Hide the already off-screen surface before releasing its layout tree.
        panelPresented = false
        blurActive = false
        contentActive = false
        if (!root.keepLoaded)
            contentRetained = false
        root.presentationClosed()
    }

    Component.onCompleted: {
        panelPresented = WidgetState.leftSidebarOpen
        blurActive = WidgetState.leftSidebarOpen
        contentActive = WidgetState.leftSidebarOpen
        contentRetained = WidgetState.leftSidebarOpen
            || root.keepLoaded
    }

    Connections {
        target: WidgetState

        function onLeftSidebarOpenChanged() {
            if (WidgetState.leftSidebarOpen)
                root.beginPresentation()
            else {
                root.blurActive = false
                root.contentActive = false
            }
        }
    }

    onKeepLoadedChanged: {
        if (root.keepLoaded) {
            root.contentRetained = true
        } else if (!WidgetState.leftSidebarOpen
                && !root.panelPresented) {
            root.contentRetained = false
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

        state: WidgetState.leftSidebarOpen ? "open" : "closed"

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
                id: openTransition
                to: "open"

                SequentialAnimation {
                    NumberAnimation {
                        target: animController
                        property: "slideOffset"
                        duration: root.enterDuration
                        easing.type: Easing.OutBack
                        easing.overshoot: 0.3
                    }

                    ScriptAction {
                        script: root.finishOpening()
                    }
                }
            },
            Transition {
                id: closeTransition
                to: "closed"

                SequentialAnimation {
                    NumberAnimation {
                        target: animController
                        property: "slideOffset"
                        duration: root.exitDuration
                        easing.type: Easing.InBack
                        easing.overshoot: 0.18
                    }

                    ScriptAction {
                        script: root.finishClosing()
                    }
                }
            }
        ]
    }

    Rectangle {
        id: panelSurface

        visible: root.panelVisuallyPresent
        x: animController.slideOffset + root.gap
        y: root.sidebarY
        width: root.sidebarWidth
        height: root.qsTargetHeight
        color: BlurService.backgroundColor(
            Appearance.colors.colLayer0)
        radius: Appearance.rounding.large
    }

    // Keep the compositor blur region out of the per-frame slide path. This
    // item becomes visible only after the panel reaches its resting position.
    Item {
        id: blurRegionAnchor

        visible: root.blurActive
        x: panelSurface.x
        y: panelSurface.y
        width: panelSurface.width
        height: panelSurface.height
        property real radius: panelSurface.radius
    }

    Item {
        id: sidebarContentFrame

        visible: root.panelVisuallyPresent
        x: panelSurface.x
        y: panelSurface.y
        width: panelSurface.width
        height: panelSurface.height
        clip: true

        Loader {
            id: sidebarContentLoader

            anchors.fill: parent
            active: root.keepLoaded
                || WidgetState.leftSidebarOpen
                || root.contentRetained
            sourceComponent: leftSidebarContentComponent
        }
    }

    Component {
        id: leftSidebarContentComponent

        LeftSidebarContent {
            anchors.fill: parent
            screenName: root.panelScreen ? root.panelScreen.name : ""
            weatherSourceOverride: root.weatherSourceOverride
            foreground: root.contentActive
            presentationActive: root.contentActive
        }
    }
}
