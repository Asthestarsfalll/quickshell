import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Modules.Sidebars.Left

ShellRoot {
    id: root

    // ---- Manual test values -------------------------------------------------
    // Edit these values, save the file, and let Quickshell reload the preview.

    // WMO weather code examples: 0 clear, 2 partly cloudy, 45 fog,
    // 63 rain, 73 snow, 95 thunderstorm/lightning.
    property int previewWeatherCode: 0

    // Icon-name classification is also accepted. Useful values include:
    // clear_day, clear_night, partly_cloudy_day, fog_day, rain,
    // thunderstorms_day, snow, mostly_clear_day.
    property string previewIconName: "clear_day"
    property string previewWeatherText: qsTr("晴朗")

    // true selects the night palette and pauses/resumes the matching icon.
    property bool previewNight: false

    // Set sustained/gust wind to at least 8 m/s in a clear/partly/overcast
    // scene to exercise the 30 FPS windy-leaf scene.
    property real previewWindSpeedMs: 2
    property real previewWindGustsMs: 4

    property real previewTemperatureC: 22
    property real previewFeelsLikeC: 21
    property real previewHighC: 27
    property real previewLowC: 16

    // false: only the active view exists and the whole tree unloads after the
    // close animation. true: visited views remain allocated but stop animating.
    property bool previewKeepSidebarsLoaded: false

    // Allowed values: "info", "sys", "weather".
    property string previewInitialView: "weather"

    // Leave empty to use the first connected output, or set an exact Niri/
    // Quickshell output name such as "DP-1".
    property string previewScreenName: ""

    // -------------------------------------------------------------------------

    property bool previewVisible: true
    property bool previewClosing: false

    function acceptsScreen(screen) {
        if (!screen)
            return false
        if (root.previewScreenName !== "")
            return screen.name === root.previewScreenName
        return Quickshell.screens.length > 0
            && Quickshell.screens[0] === screen
    }

    function closePreview() {
        if (root.previewClosing)
            return
        root.previewClosing = true
        WidgetState.leftSidebarOpen = false
    }

    Component.onCompleted: {
        WidgetState.leftSidebarView = ["info", "sys", "weather"]
            .indexOf(root.previewInitialView) >= 0
            ? root.previewInitialView : "weather"
        WidgetState.leftSidebarOpen = true
    }

    MockWeatherSource {
        id: mockWeather

        currentWeatherCode: root.previewWeatherCode
        currentIconName: root.previewIconName
        currentWeatherText: root.previewWeatherText
        night: root.previewNight
        currentWindSpeedMs: root.previewWindSpeedMs
        currentWindGustsMs: root.previewWindGustsMs
        currentTemperatureC: root.previewTemperatureC
        currentFeelsLikeC: root.previewFeelsLikeC
        highTemperatureC: root.previewHighC
        lowTemperatureC: root.previewLowC
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: overlayWindow

            required property var modelData

            screen: modelData
            visible: root.previewVisible
                && root.acceptsScreen(modelData)
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "clavis-weather-preview"

            Rectangle {
                anchors.fill: parent
                color: Appearance.applyAlpha(
                    Appearance.colors.colScrim, 0.42)

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.closePreview()
                }
            }

            LeftSidebarWindow {
                id: sidebar

                z: 1
                anchors.fill: parent
                panelScreen: overlayWindow.screen
                keepLoaded: root.previewKeepSidebarsLoaded
                weatherSourceOverride: mockWeather

                onPanelVisuallyPresentChanged: {
                    if (!panelVisuallyPresent && root.previewClosing) {
                        root.previewVisible = false
                        Qt.callLater(Qt.quit)
                    }
                }
            }

            Button {
                z: 2
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Appearance.spacing.large
                implicitWidth: 156
                implicitHeight: 52
                text: qsTr("关闭天气测试")
                font.family: Sizes.fontFamily
                font.pixelSize: Sizes.typeLabelLarge
                font.weight: Font.Bold
                onClicked: root.closePreview()

                background: Rectangle {
                    radius: Appearance.rounding.full
                    color: parent.down ? "#9f0712"
                        : parent.hovered ? "#e32636" : "#c1121f"
                    border.width: 2
                    border.color: "white"
                }

                contentItem: Text {
                    text: parent.text
                    color: "white"
                    font: parent.font
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}
