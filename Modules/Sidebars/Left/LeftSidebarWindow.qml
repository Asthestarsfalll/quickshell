import QtQuick
import qs.Common

Item {
    id: root

    property var panelScreen: null
    property int sidebarWidth: 540
    property int gap: 24
    readonly property int sidebarY: Sizes.barHeight + gap
    readonly property real closedSlideOffset: -(sidebarWidth + gap)
    readonly property int enterDuration: Animations.durations.large
    readonly property int exitDuration: Animations.durations.large
    readonly property int qsTargetHeight:
        Math.max(0, height - sidebarY - gap)
    readonly property bool panelActive: WidgetState.leftSidebarOpen
        || Math.abs(animController.slideOffset - closedSlideOffset) > 0.5

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

    Rectangle {
        id: panelSurface

        visible: root.panelActive
        x: animController.slideOffset + root.gap
        y: root.sidebarY
        width: root.sidebarWidth
        height: root.qsTargetHeight
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
            active: true
            sourceComponent: leftSidebarContentComponent
        }
    }

    Component {
        id: leftSidebarContentComponent

        LeftSidebarContent {
            anchors.fill: parent
            screenName: root.panelScreen ? root.panelScreen.name : ""
        }
    }
}
