import QtQuick
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

// Compact media presentation for the 2x2 System Card slot.
Item {
    id: root

    property bool active: true
    property bool opaqueControls: false
    readonly property var player: MediaManager.active
    readonly property bool hasPlayer: player !== null && player !== undefined
    readonly property bool isPlaying: hasPlayer && player.isPlaying
    readonly property string artUrl: hasPlayer && player.trackArtUrl ? player.trackArtUrl : ""
    readonly property real currentPosition: hasPlayer && player === MediaManager.active ? MediaManager.currentPosition : 0
    readonly property real progress: hasPlayer && player.length > 0 ? Math.max(0, Math.min(1, currentPosition / player.length)) : 0

    function controlColor(primaryButton, hovered) {
        let color = primaryButton ? (hovered ? Appearance.colors.colPrimaryHover : Appearance.colors.colPrimary) : (hovered ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colSecondaryContainer);
        if (root.opaqueControls)
            color = Appearance.applyAlpha(color, 1);

        return color;
    }

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("媒体播放器")

    ExpressiveSemicircleProgress {
        id: mediaProgress

        anchors.top: parent.top
        anchors.topMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(244, parent.width - 24)
        height: width
        progress: root.progress
        playing: root.isPlaying
        active: root.active
        foregroundColor: Appearance.colors.colPrimary
        trackColor: Appearance.colors.colSecondaryContainer
        lineWidth: 10
    }

    ExpressiveMediaCover {
        anchors.centerIn: mediaProgress
        width: Math.min(200, mediaProgress.width - 36)
        height: width
        artUrl: root.artUrl
        active: root.active
        playing: root.isPlaying
    }

    Item {
        id: controls

        readonly property real nextBaseWidth: 64
        readonly property real spacing: 6
        readonly property real playBaseWidth: width - nextBaseWidth - spacing

        anchors.bottom: parent.bottom
        anchors.bottomMargin: 22
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(188, parent.width - 32)
        height: 48

        ControlButton {
            id: playPauseButton

            x: 0
            width: controls.playBaseWidth + shapeMorphExpansion - nextButton.shapeMorphExpansion
            height: controls.height
            iconName: root.isPlaying ? "pause" : "play_arrow"
            primaryButton: true
            enabled: root.hasPlayer
            Accessible.name: root.isPlaying ? qsTr("暂停") : qsTr("播放")
            onClicked: {
                if (root.player)
                    root.player.togglePlaying();

            }
        }

        ControlButton {
            id: nextButton

            x: playPauseButton.x + playPauseButton.width + controls.spacing
            width: controls.nextBaseWidth + shapeMorphExpansion - playPauseButton.shapeMorphExpansion
            height: controls.height
            iconName: "skip_next"
            primaryButton: false
            enabled: root.hasPlayer
            Accessible.name: qsTr("下一首")
            onClicked: {
                if (root.player)
                    root.player.next();

            }
        }

        component ControlButton: Item {
            id: control

            required property string iconName
            required property bool primaryButton
            readonly property bool down: buttonPointer.pressed
            property real shapeMorphExpansion: down ? 24 : 0
            property real visualRadius: down || (primaryButton && root.isPlaying) ? 12 : height / 2

            signal clicked()

            Accessible.role: Accessible.Button
            Accessible.onPressAction: {
                if (control.enabled)
                    control.clicked();

            }

            Rectangle {
                anchors.fill: parent
                radius: control.visualRadius
                color: root.controlColor(control.primaryButton, buttonPointer.containsMouse)

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: control.primaryButton ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
                    opacity: control.down ? 0.2 : buttonPointer.containsMouse ? 0.12 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.animation.expressiveEffects.duration
                            easing.type: Appearance.animation.expressiveEffects.type
                            easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                        }

                    }

                }

            }

            MaterialSymbol {
                anchors.centerIn: parent
                text: control.iconName
                iconSize: control.primaryButton ? 29 : 27
                fill: 1
                color: control.primaryButton ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
            }

            MouseArea {
                id: buttonPointer

                anchors.fill: parent
                enabled: control.enabled
                acceptedButtons: Qt.LeftButton
                hoverEnabled: true
                cursorShape: control.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                // Keep the click grab local while stationary, but allow the
                // card's DragHandler to take over once the pointer crosses
                // the platform drag threshold.
                preventStealing: false
                onClicked: control.clicked()
            }

            Behavior on shapeMorphExpansion {
                NumberAnimation {
                    duration: Appearance.animation.expressiveFastSpatial.duration
                    easing.type: Appearance.animation.expressiveFastSpatial.type
                    easing.bezierCurve: Appearance.animation.expressiveFastSpatial.bezierCurve
                }

            }

            Behavior on visualRadius {
                NumberAnimation {
                    duration: Appearance.animation.expressiveDefaultEffects.duration
                    easing.type: Appearance.animation.expressiveDefaultEffects.type
                    easing.bezierCurve: Appearance.animation.expressiveDefaultEffects.bezierCurve
                }

            }

        }

    }

}
