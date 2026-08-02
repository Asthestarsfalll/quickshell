import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Modules.Sidebars.Left

ShellRoot {
    id: root

    readonly property var resolutions: [
        ({ label: "1080p", width: 1920, height: 1080 }),
        ({ label: "2K", width: 2560, height: 1440 }),
        ({ label: "4K", width: 3840, height: 2160 })
    ]
    readonly property var outputScales: [1, 1.25, 1.5, 2]
    readonly property var scenes: [
        ({ label: qsTr("晴天"), code: 0, icon: "clear_day", night: false, wind: 2, gusts: 4 }),
        ({ label: qsTr("晴夜"), code: 0, icon: "clear_night", night: true, wind: 2, gusts: 4 }),
        ({ label: qsTr("局部多云"), code: 2, icon: "partly_cloudy_day", night: false, wind: 3, gusts: 5 }),
        ({ label: qsTr("阴天 / 雾"), code: 45, icon: "fog_day", night: false, wind: 2, gusts: 3 }),
        ({ label: qsTr("雨"), code: 63, icon: "rain", night: false, wind: 5, gusts: 8 }),
        ({ label: qsTr("雷暴 / 闪电"), code: 95, icon: "thunderstorms_day", night: false, wind: 7, gusts: 12 }),
        ({ label: qsTr("雪"), code: 73, icon: "snow", night: false, wind: 4, gusts: 7 }),
        ({ label: qsTr("大风落叶"), code: 1, icon: "mostly_clear_day", night: false, wind: 10, gusts: 15 })
    ]

    property int resolutionIndex: 0
    property int outputScaleIndex: 0
    property bool keepLoaded: false
    property string initialView: {
        const requested = String(Quickshell.env(
            "CLAVIS_WEATHER_PREVIEW_INITIAL_VIEW") || "weather")
        return ["info", "sys", "weather"].indexOf(requested) >= 0
            ? requested : "weather"
    }
    readonly property var selectedResolution: resolutions[resolutionIndex]
    readonly property real simulatedOutputScale:
        outputScales[outputScaleIndex]
    readonly property int logicalWidth:
        Math.round(selectedResolution.width / simulatedOutputScale)
    readonly property int logicalHeight:
        Math.round(selectedResolution.height / simulatedOutputScale)

    function applyScene(index) {
        const scene = scenes[Math.max(0, Math.min(scenes.length - 1, index))]
        mockWeather.currentWeatherCode = scene.code
        mockWeather.currentIconName = scene.icon
        mockWeather.currentWeatherText = scene.label
        mockWeather.night = scene.night
        mockWeather.currentWindSpeedMs = scene.wind
        mockWeather.currentWindGustsMs = scene.gusts
    }

    MockWeatherSource {
        id: mockWeather
    }

    FloatingWindow {
        id: previewWindow

        visible: true
        title: "clavis-weather-preview"
        implicitWidth: root.logicalWidth
        implicitHeight: root.logicalHeight
        minimumSize: Qt.size(900, 640)
        color: Appearance.colors.colLayer0
        Material.theme: Material.Dark
        Material.accent: Appearance.colors.colPrimary
        onClosed: Qt.quit()

        Component.onCompleted: {
            WidgetState.leftSidebarView = root.initialView
            WidgetState.leftSidebarOpen = true
            root.applyScene(0)
        }

        LeftSidebarWindow {
            id: sidebar

            anchors.fill: parent
            panelScreen: previewWindow.screen
            keepLoaded: root.keepLoaded
            weatherSourceOverride: mockWeather
        }

        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Appearance.spacing.large
            width: Math.min(420, parent.width - 620)
            radius: Appearance.rounding.large
            color: Appearance.colors.colSurfaceContainer
            border.width: 1
            border.color: Appearance.colors.colOutlineVariant

            ScrollView {
                anchors.fill: parent
                anchors.margins: Appearance.spacing.large
                clip: true

                ColumnLayout {
                    width: Math.max(320, parent.width)
                    spacing: Appearance.spacing.medium

                    Label {
                        text: qsTr("天气侧边栏手动预览")
                        color: Appearance.colors.colOnSurface
                        font.family: Sizes.fontFamily
                        font.pixelSize: Sizes.typeHeadlineSmall
                        font.weight: Font.DemiBold
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Button {
                            text: WidgetState.leftSidebarOpen
                                ? qsTr("关闭侧边栏") : qsTr("打开侧边栏")
                            onClicked: WidgetState.leftSidebarOpen
                                = !WidgetState.leftSidebarOpen
                        }

                        CheckBox {
                            text: qsTr("保留已加载页面")
                            checked: root.keepLoaded
                            onToggled: root.keepLoaded = checked
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Repeater {
                            model: ["info", "sys", "weather"]
                            Button {
                                required property string modelData
                                text: modelData
                                highlighted: WidgetState.leftSidebarView
                                    === modelData
                                onClicked: WidgetState.leftSidebarView = modelData
                            }
                        }
                    }

                    Label { text: qsTr("天气场景") }
                    ComboBox {
                        Layout.fillWidth: true
                        model: root.scenes.map(scene => scene.label)
                        onActivated: index => root.applyScene(index)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "weatherCode" }
                        SpinBox {
                            from: -1
                            to: 99
                            value: mockWeather.currentWeatherCode
                            onValueModified:
                                mockWeather.currentWeatherCode = value
                        }
                    }

                    TextField {
                        Layout.fillWidth: true
                        placeholderText: "iconName"
                        text: mockWeather.currentIconName
                        onEditingFinished:
                            mockWeather.currentIconName = text.trim()
                    }

                    CheckBox {
                        text: qsTr("夜间")
                        checked: mockWeather.night
                        onToggled: mockWeather.night = checked
                    }

                    Label {
                        text: qsTr("持续风速 %1 m/s").arg(
                            mockWeather.currentWindSpeedMs.toFixed(1))
                    }
                    Slider {
                        Layout.fillWidth: true
                        from: 0
                        to: 20
                        stepSize: 0.5
                        value: mockWeather.currentWindSpeedMs
                        onMoved: mockWeather.currentWindSpeedMs = value
                    }

                    Label {
                        text: qsTr("阵风 %1 m/s").arg(
                            mockWeather.currentWindGustsMs.toFixed(1))
                    }
                    Slider {
                        Layout.fillWidth: true
                        from: 0
                        to: 30
                        stepSize: 0.5
                        value: mockWeather.currentWindGustsMs
                        onMoved: mockWeather.currentWindGustsMs = value
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        ComboBox {
                            Layout.fillWidth: true
                            model: root.resolutions.map(item => item.label)
                            currentIndex: root.resolutionIndex
                            onActivated: index => root.resolutionIndex = index
                        }
                        ComboBox {
                            Layout.fillWidth: true
                            model: root.outputScales.map(value => value.toFixed(2) + "×")
                            currentIndex: root.outputScaleIndex
                            onActivated: index => root.outputScaleIndex = index
                        }
                    }

                    Label {
                        text: qsTr("逻辑窗口 %1 × %2；Qt DPR %3")
                            .arg(root.logicalWidth)
                            .arg(root.logicalHeight)
                            .arg(previewWindow.screen
                                ? previewWindow.screen.devicePixelRatio.toFixed(2)
                                : "--")
                        wrapMode: Text.WordWrap
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: metricsColumn.implicitHeight
                            + Appearance.spacing.large * 2
                        radius: Appearance.rounding.normal
                        color: Appearance.colors.colSurfaceContainerHigh

                        Column {
                            id: metricsColumn
                            anchors.fill: parent
                            anchors.margins: Appearance.spacing.large
                            spacing: Appearance.spacing.small

                            readonly property var weatherView: sidebar.weatherView

                            Label {
                                text: qsTr("页面实例：%1")
                                    .arg(sidebar.instantiatedViewCount)
                            }
                            Label {
                                text: qsTr("动画运行：%1")
                                    .arg(metricsColumn.weatherView
                                        && metricsColumn.weatherView.weatherAnimationActive
                                        ? qsTr("是") : qsTr("否"))
                            }
                            Label {
                                text: qsTr("场景：%1")
                                    .arg(metricsColumn.weatherView
                                        ? metricsColumn.weatherView.weatherSceneType
                                        : qsTr("未实例化"))
                            }
                            Label {
                                text: qsTr("目标：%1 FPS / %2 ms")
                                    .arg(metricsColumn.weatherView
                                        ? metricsColumn.weatherView.weatherTargetFps : 0)
                                    .arg(metricsColumn.weatherView
                                        ? metricsColumn.weatherView.weatherFrameInterval : 0)
                            }
                            Label {
                                text: qsTr("模拟帧：%1；Canvas 绘制：%2")
                                    .arg(metricsColumn.weatherView
                                        ? metricsColumn.weatherView.weatherSimulationFrameCount : 0)
                                    .arg(metricsColumn.weatherView
                                        ? metricsColumn.weatherView.weatherPaintCount : 0)
                            }
                        }
                    }
                }
            }
        }
    }
}
