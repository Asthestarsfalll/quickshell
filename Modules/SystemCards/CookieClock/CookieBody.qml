import QtQuick
import Qt5Compat.GraphicalEffects
import qs.Common

Item {
    id: root

    property bool active: true
    property bool constantlyRotate: false
    property int sides: 14
    property color faceColor: Appearance.colors.colPrimaryContainer

    anchors.fill: parent

    CookieFace {
        id: shadowSource

        sides: root.sides
        fillColor: "white"
        visible: false
    }

    DropShadow {
        anchors.fill: shadowSource
        source: shadowSource
        horizontalOffset: 0
        verticalOffset: 4
        radius: 10
        samples: 21
        color: Appearance.colors.colShadow
        cached: false
    }

    CookieFace {
        sides: root.sides
        fillColor: root.faceColor
    }

    RotationAnimation on rotation {
        running: root.active && root.constantlyRotate
        from: 360
        to: 0
        duration: 30000
        loops: Animation.Infinite
        easing.type: Easing.Linear
    }

}
