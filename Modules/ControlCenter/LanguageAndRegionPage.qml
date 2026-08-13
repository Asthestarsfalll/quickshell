import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root

    clip: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + Metrics.pageMargin * 2

    ColumnLayout {
        id: contentColumn

        width: Math.min(640, Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin, (root.width - width) / 2)
        y: Metrics.pageMargin
        spacing: Metrics.spacingXL

        SettingsSection {
            Layout.fillWidth: true
            flat: true
            title: qsTr("语言")
            iconName: "translate"

            SettingsRow {
                Layout.fillWidth: true
                iconName: "language"
                title: qsTr("界面语言")
                supportingText: qsTr("用于 Clavis Quickshell 界面的显示语言")

                trailing: SearchSelectMenuField {
                    Layout.preferredWidth: 190
                    options: I18nService.supportedLanguages
                    value: UiPreferences.language
                    placeholder: qsTr("选择语言")
                    textRole: "label"
                    valueRole: "code"
                    closeOnAccept: true
                    onAccepted: (value) => {
                        return UiPreferences.setLanguage(value);
                    }
                }

            }

        }

        SettingsSection {
            Layout.fillWidth: true
            flat: true
            title: qsTr("天气")
            iconName: "map"

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 150

                ColumnLayout {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - Metrics.spacingL * 2, 420)
                    spacing: Metrics.spacingXS

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: "map"
                        iconSize: 44
                        fill: 0
                        color: Appearance.colors.colOutline
                    }

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("天气位置地图即将推出")
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: Typography.titleSmall.family
                        font.pixelSize: Typography.titleSmall.pixelSize
                        font.weight: Typography.titleSmall.weight
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("后续可在地图上选择天气位置")
                        color: Appearance.colors.colOutline
                        font.family: Typography.bodySmall.family
                        font.pixelSize: Typography.bodySmall.pixelSize
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }

                }

            }

        }

        SettingsSection {
            Layout.fillWidth: true
            flat: true
            title: qsTr("单位")
            iconName: "thermostat"

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("天气温度")
                supportingText: qsTr("侧边栏、灵动岛与锁屏天气的温度单位")

                trailing: StyledButtonGroup {
                    model: [({
                        "value": "celsius",
                        "label": "°C"
                    }), ({
                        "value": "fahrenheit",
                        "label": "°F"
                    })]
                    currentValue: UiPreferences.weatherTemperatureUnit
                    buttonMinWidth: 56
                    onValueSelected: (value) => {
                        return UiPreferences.setWeatherTemperatureUnit(value);
                    }
                }

            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("硬件温度")
                supportingText: qsTr("CPU、GPU 与系统监测组件的温度单位")

                trailing: StyledButtonGroup {
                    model: [({
                        "value": "celsius",
                        "label": "°C"
                    }), ({
                        "value": "fahrenheit",
                        "label": "°F"
                    })]
                    currentValue: UiPreferences.systemTemperatureUnit
                    buttonMinWidth: 56
                    onValueSelected: (value) => {
                        return UiPreferences.setSystemTemperatureUnit(value);
                    }
                }

            }

        }

        SettingsSection {
            Layout.fillWidth: true
            flat: true
            title: qsTr("时间与日期")
            iconName: "schedule"

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("时钟格式")
                supportingText: qsTr("用于灵动岛、侧边栏与锁屏时钟")

                trailing: StyledButtonGroup {
                    model: [({
                        "value": "24",
                        "label": qsTr("24 小时")
                    }), ({
                        "value": "12",
                        "label": qsTr("12 小时")
                    })]
                    currentValue: UiPreferences.useTwelveHourClock ? "12" : "24"
                    buttonMinWidth: 78
                    onValueSelected: (value) => {
                        return UiPreferences.setUseTwelveHourClock(value === "12");
                    }
                }

            }

        }

    }

}
