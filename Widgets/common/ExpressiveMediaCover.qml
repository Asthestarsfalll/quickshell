import QtQuick
import Qt5Compat.GraphicalEffects
import M3Shapes
import qs.Common
import qs.Components
import qs.Services

// Preserves the former Dashboard Hole cover treatment for the System media
// card. Adapted from Caelestia Shell's CoverArt (GPL-3.0).
Item {
    id: root

    property string artUrl: ""
    property bool active: true
    property bool playing: false
    property real coverRotation: 360
    property real fallbackIconSize: 56
    property real loadingIconSize: 48

    Item {
        id: shapeWrapper

        anchors.fill: parent
        layer.enabled: true

        MaterialShape {
            anchors.centerIn: parent
            implicitSize: parent.width
            shape: MaterialShape.Cookie12Sided
            color: "white"
            rotation: root.coverRotation
        }

    }

    MaterialShape {
        anchors.centerIn: parent
        implicitSize: parent.width
        shape: MaterialShape.Cookie12Sided
        color: BlurService.solidBackgroundColor(
            Appearance.colors.colSurfaceContainerHighest)
        rotation: root.coverRotation
    }

    Image {
        id: coverImage

        anchors.fill: parent
        source: root.artUrl
        sourceSize: Qt.size(width * 2, height * 2)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        visible: false
    }

    OpacityMask {
        anchors.fill: parent
        source: coverImage
        maskSource: shapeWrapper
        cached: false
        opacity: coverImage.status === Image.Ready ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.expressiveDefaultEffects.duration
                easing.type: Appearance.animation.expressiveDefaultEffects.type
                easing.bezierCurve: Appearance.animation.expressiveDefaultEffects.bezierCurve
            }

        }

    }

    MaterialSymbol {
        anchors.centerIn: parent
        visible: coverImage.status === Image.Null || coverImage.status === Image.Error
        text: coverImage.status === Image.Error ? "broken_image" : "art_track"
        iconSize: root.fallbackIconSize
        fill: 1
        color: Appearance.colors.colOnSurfaceVariant
    }

    MaterialSymbol {
        id: loadingIcon

        anchors.centerIn: parent
        visible: coverImage.status === Image.Loading
        text: "progress_activity"
        iconSize: root.loadingIconSize
        color: Appearance.colors.colPrimary

        NumberAnimation on rotation {
            from: 0
            to: 360
            duration: 1200
            easing.type: Easing.Linear
            loops: Animation.Infinite
            running: loadingIcon.visible && root.active
        }

    }

    NumberAnimation on coverRotation {
        from: 360
        to: 0
        duration: 23500
        easing.type: Easing.Linear
        loops: Animation.Infinite
        running: true
        paused: !root.active || !root.playing
    }

}
