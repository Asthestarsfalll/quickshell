import QtQuick
import qs.Common
import qs.Services
import qs.Widgets.common

Item {
    id: root

    property bool active: true
    property date currentTime: new Date()
    readonly property real faceSize: Math.max(1, Math.min(width, height) * 0.9)
    readonly property real scaleFactor: faceSize / 230
    readonly property int hour24: currentTime.getHours()
    readonly property int hour12: ((hour24 + 11) % 12) + 1
    readonly property int minute: currentTime.getMinutes()
    readonly property int second: currentTime.getSeconds()
    readonly property string periodText: hour24 >= 12 ? "PM" : "AM"
    readonly property string centerHourText: String(UiPreferences.useTwelveHourClock ? hour12 : hour24).padStart(2, "0")
    readonly property string centerMinuteText: String(minute).padStart(2, "0")
    readonly property string borderDateText: Qt.formatDateTime(currentTime, "ddd dd")
    readonly property color faceColor: Appearance.colors.colPrimaryContainer
    readonly property color dialColor: Appearance.mix(Appearance.colors.colSecondary, Appearance.colors.colPrimaryContainer, 0.15)
    readonly property color infoColor: Appearance.mix(Appearance.colors.colPrimary, Appearance.colors.colPrimaryContainer, 0.55)

    Accessible.name: qsTr("曲奇时钟 ") + centerHourText + ":" + centerMinuteText + (UiPreferences.useTwelveHourClock ? " " + periodText : "")

    Timer {
        interval: 1000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: root.currentTime = new Date()
    }

    Item {
        id: rotatingCookie

        anchors.centerIn: parent
        width: root.faceSize
        height: root.faceSize

        RoundedCookieShape {
            anchors.centerIn: parent
            width: root.faceSize + 5 * root.scaleFactor
            height: width
            sides: UiPreferences.sidebarCookieSides
            color: Appearance.colors.colShadow
            opacity: 0.34
        }

        RoundedCookieShape {
            anchors.centerIn: parent
            width: root.faceSize
            height: width
            sides: UiPreferences.sidebarCookieSides
            color: root.faceColor
        }

        RotationAnimation on rotation {
            running: root.active && UiPreferences.sidebarCookieConstantlyRotate
            from: 360
            to: 0
            duration: 30000
            loops: Animation.Infinite
            easing.type: Easing.Linear
        }

    }

    Item {
        id: clockFace

        anchors.centerIn: parent
        width: root.faceSize
        height: root.faceSize

        Repeater {
            model: UiPreferences.sidebarCookieDialStyle === "dots" ? 12 : 0

            delegate: Item {
                required property int index

                anchors.fill: parent
                rotation: 30 * index

                Rectangle {
                    width: 12 * root.scaleFactor
                    height: width
                    radius: width / 2
                    color: root.dialColor

                    anchors {
                        top: parent.top
                        topMargin: 12 * root.scaleFactor
                        horizontalCenter: parent.horizontalCenter
                    }

                }

            }

        }

        Repeater {
            model: UiPreferences.sidebarCookieDialStyle === "full" ? 60 : 0

            delegate: Item {
                required property int index

                anchors.fill: parent
                rotation: 6 * index

                Rectangle {
                    width: (index % 5 === 0 ? 18 : 7) * root.scaleFactor
                    height: (index % 5 === 0 ? 4 : 2) * root.scaleFactor
                    radius: height / 2
                    color: root.dialColor
                    rotation: 90

                    anchors {
                        top: parent.top
                        topMargin: 12 * root.scaleFactor
                        horizontalCenter: parent.horizontalCenter
                    }

                }

            }

        }

        Repeater {
            model: UiPreferences.sidebarCookieDialStyle === "numbers" ? [3, 6, 9, 12] : []

            delegate: Item {
                required property int index
                required property var modelData

                anchors.fill: parent
                rotation: 90 * (index + 1)

                Text {
                    text: modelData
                    color: root.dialColor
                    rotation: -90 * (index + 1)
                    font.family: Fonts.expressive
                    font.pixelSize: 34 * root.scaleFactor
                    font.weight: Font.Black

                    anchors {
                        top: parent.top
                        topMargin: 16 * root.scaleFactor
                        horizontalCenter: parent.horizontalCenter
                    }

                }

            }

        }

        Item {
            anchors.centerIn: parent
            width: 135 * root.scaleFactor
            height: width
            visible: UiPreferences.sidebarCookieHourMarks

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: root.dialColor
            }

            Repeater {
                model: 12

                delegate: Item {
                    required property int index

                    anchors.fill: parent
                    rotation: 30 * index

                    Rectangle {
                        width: 12 * root.scaleFactor
                        height: 4 * root.scaleFactor
                        radius: height / 2
                        color: Appearance.mix(root.infoColor, root.dialColor, 0.5)

                        anchors {
                            left: parent.left
                            leftMargin: 8 * root.scaleFactor
                            verticalCenter: parent.verticalCenter
                        }

                    }

                }

            }

        }

        Column {
            anchors.centerIn: parent
            spacing: -16 * root.scaleFactor
            visible: UiPreferences.sidebarCookieTimeIndicators

            Repeater {
                model: UiPreferences.useTwelveHourClock ? [root.centerHourText, root.centerMinuteText, root.periodText] : [root.centerHourText, root.centerMinuteText]

                delegate: Text {
                    required property int index
                    required property var modelData

                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData
                    color: root.infoColor
                    font.family: Fonts.expressive
                    font.pixelSize: index < 2 ? (UiPreferences.sidebarCookieHourMarks ? 40 : 68) * root.scaleFactor : (UiPreferences.sidebarCookieHourMarks ? 20 : 26) * root.scaleFactor
                    font.weight: Font.Bold
                }

            }

        }

        Item {
            anchors.fill: parent
            visible: UiPreferences.sidebarCookieMinuteHandStyle !== "hide"
            rotation: -90 + 6 * root.minute
            z: 1

            Rectangle {
                readonly property real handWidth: UiPreferences.sidebarCookieMinuteHandStyle === "bold" ? 20 * root.scaleFactor : UiPreferences.sidebarCookieMinuteHandStyle === "medium" ? 12 * root.scaleFactor : 5 * root.scaleFactor

                anchors.verticalCenter: parent.verticalCenter
                x: parent.width / 2 - handWidth / 2 - (UiPreferences.sidebarCookieMinuteHandStyle === "classic" ? 15 * root.scaleFactor : 0)
                width: 95 * root.scaleFactor
                height: handWidth
                radius: UiPreferences.sidebarCookieMinuteHandStyle === "classic" ? 2 * root.scaleFactor : height / 2
                color: Appearance.colors.colTertiary
            }

            Behavior on rotation {
                RotationAnimation {
                    direction: RotationAnimation.Clockwise
                    duration: 300
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animationCurves.emphasized
                }

            }

        }

        Item {
            anchors.fill: parent
            visible: UiPreferences.sidebarCookieHourHandStyle !== "hide"
            rotation: -90 + 30 * (root.hour12 + root.minute / 60)
            z: UiPreferences.sidebarCookieHourHandStyle === "hollow" ? 0 : 2

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: parent.width / 2 - 10 * root.scaleFactor - (UiPreferences.sidebarCookieHourHandStyle === "classic" ? 15 * root.scaleFactor : 0)
                width: 72 * root.scaleFactor
                height: UiPreferences.sidebarCookieHourHandStyle === "classic" ? 8 * root.scaleFactor : 20 * root.scaleFactor
                radius: UiPreferences.sidebarCookieHourHandStyle === "classic" ? 2 * root.scaleFactor : 10 * root.scaleFactor
                color: UiPreferences.sidebarCookieHourHandStyle === "hollow" ? "transparent" : Appearance.colors.colPrimary
                border.width: 4 * root.scaleFactor
                border.color: Appearance.colors.colPrimary
            }

            Behavior on rotation {
                RotationAnimation {
                    direction: RotationAnimation.Clockwise
                    duration: 300
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animationCurves.emphasized
                }

            }

        }

        Item {
            anchors.fill: parent
            visible: UiPreferences.sidebarCookieSecondHandStyle !== "hide"
            rotation: 90 + 6 * root.second
            z: UiPreferences.sidebarCookieSecondHandStyle === "line" ? 2 : 3

            Rectangle {
                width: (UiPreferences.sidebarCookieSecondHandStyle === "dot" ? 20 : 95) * root.scaleFactor
                height: (UiPreferences.sidebarCookieSecondHandStyle === "dot" ? 20 : 2) * root.scaleFactor
                radius: Math.min(width, height) / 2
                color: Appearance.colors.colPrimary

                anchors {
                    left: parent.left
                    leftMargin: (10 + (UiPreferences.sidebarCookieSecondHandStyle === "dot" ? 20 : 0)) * root.scaleFactor
                    verticalCenter: parent.verticalCenter
                }

            }

            Rectangle {
                visible: UiPreferences.sidebarCookieSecondHandStyle === "classic"
                width: 14 * root.scaleFactor
                height: width
                radius: Appearance.rounding.small
                color: Appearance.colors.colPrimary

                anchors {
                    left: parent.left
                    leftMargin: 40 * root.scaleFactor
                    verticalCenter: parent.verticalCenter
                }

            }

            Behavior on rotation {
                enabled: UiPreferences.sidebarCookieConstantlyRotate

                RotationAnimation {
                    direction: RotationAnimation.Clockwise
                    duration: 1000
                    easing.type: Easing.InOutQuad
                }

            }

        }

        Rectangle {
            anchors.centerIn: parent
            width: 6 * root.scaleFactor
            height: width
            radius: width / 2
            visible: UiPreferences.sidebarCookieMinuteHandStyle !== "bold"
            color: UiPreferences.sidebarCookieMinuteHandStyle === "medium" ? root.faceColor : Appearance.colors.colTertiary
            z: 4
        }

        Item {
            anchors.fill: parent
            visible: UiPreferences.sidebarCookieDateStyle === "bubble"

            Item {
                width: 64 * root.scaleFactor
                height: width

                anchors {
                    left: parent.left
                    top: parent.top
                }

                RoundedCookieShape {
                    anchors.centerIn: parent
                    width: parent.width
                    height: width
                    sides: 5
                    innerRadiusRatio: 1
                    color: Appearance.colors.colTertiaryContainer
                }

                Text {
                    anchors.centerIn: parent
                    text: root.currentTime.getDate()
                    color: Appearance.colors.colOnTertiaryContainer
                    font.family: Fonts.expressive
                    font.pixelSize: 30 * root.scaleFactor
                    font.weight: Font.Black
                }

            }

            Item {
                width: 64 * root.scaleFactor
                height: width

                anchors {
                    right: parent.right
                    bottom: parent.bottom
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: width
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colSecondaryContainer
                }

                Text {
                    anchors.centerIn: parent
                    text: Qt.formatDateTime(root.currentTime, "MM")
                    color: Appearance.colors.colOnSecondaryContainer
                    font.family: Fonts.expressive
                    font.pixelSize: 30 * root.scaleFactor
                    font.weight: Font.Black
                }

            }

        }

        Rectangle {
            visible: UiPreferences.sidebarCookieDateStyle === "rect"
            width: 45 * root.scaleFactor
            height: 30 * root.scaleFactor
            radius: Appearance.rounding.small
            color: Appearance.mix(root.infoColor, Appearance.colors.colSecondaryContainerHover, 0.5)

            anchors {
                right: parent.right
                rightMargin: 10 * root.scaleFactor
                verticalCenter: parent.verticalCenter
            }

            Text {
                anchors.centerIn: parent
                text: Qt.formatDateTime(root.currentTime, "dd")
                color: Appearance.colors.colSecondaryHover
                font.family: Fonts.expressive
                font.pixelSize: 20 * root.scaleFactor
                font.weight: Font.Black
            }

        }

        Item {
            anchors.fill: parent
            visible: UiPreferences.sidebarCookieDateStyle === "border"
            rotation: 6 * root.second + 180

            Repeater {
                model: root.borderDateText.length

                delegate: Text {
                    required property int index
                    readonly property real angle: index * 12 * Math.PI / 180 - Math.PI / 2

                    x: parent.width / 2 + 90 * root.scaleFactor * Math.cos(angle) - width / 2
                    y: parent.height / 2 + 90 * root.scaleFactor * Math.sin(angle) - height / 2
                    rotation: angle * 180 / Math.PI + 90
                    text: root.borderDateText.charAt(index)
                    color: root.infoColor
                    font.family: Fonts.expressive
                    font.pixelSize: 24 * root.scaleFactor
                    font.weight: Font.Medium
                }

            }

        }

    }

}
