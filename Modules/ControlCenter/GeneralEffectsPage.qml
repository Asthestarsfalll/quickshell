import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root

    clip: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + Metrics.pageMargin * 2

    Component.onCompleted: BlurService.writeEffectsConfig()

    Connections {
        target: BlurService
        function onAvailableChanged() {
            if (BlurService.available)
                BlurService.writeEffectsConfig();
        }
    }

    ColumnLayout {
        id: contentColumn

        width: Math.min(640, Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin, (root.width - width) / 2)
        y: Metrics.pageMargin

        SettingsSection {
            Layout.fillWidth: true
            flat: true
            title: qsTr("背景")
            iconName: "wallpaper"

            GeneralSliderSetting {
                title: qsTr("背景不透明度")
                from: 0
                to: 100
                stepSize: 1
                suffix: "%"
                value: PersonalizationConfig.shellBackgroundOpacity * 100
                onMoved: value => PersonalizationConfig
                    .setShellBackgroundOpacity(value / 100)
            }

            SettingsRow {
                Layout.fillWidth: true
                iconName: "blur_on"
                title: qsTr("背景模糊")

                trailing: StyledSwitch {
                    enabled: BlurService.available
                    checked: PersonalizationConfig.shellBlurEnabled
                    Accessible.name: qsTr("背景模糊")
                    onToggled: PersonalizationConfig.setShellBlurEnabled(checked)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                iconName: "filter_center_focus"
                title: qsTr("仅模糊壁纸")
                supportingText: BlurService.niriIntegrationReady
                    ? qsTr("关闭后会模糊窗口，开销更高")
                    : qsTr("需要先配置 Niri 模糊集成")

                trailing: StyledSwitch {
                    enabled: BlurService.available
                        && BlurService.niriIntegrationReady
                    checked: PersonalizationConfig.shellBlurXray
                    Accessible.name: qsTr("仅模糊壁纸")
                    onToggled: PersonalizationConfig.setShellBlurXray(checked)
                }
            }

            SettingsActionRow {
                Layout.fillWidth: true
                visible: BlurService.available
                    && !BlurService.niriIntegrationReady
                iconName: "settings"
                text: BlurService.integrationBusy
                    ? qsTr("正在配置 Niri 集成…") : qsTr("配置 Niri 集成")
                trailingIconName: "chevron_right"
                enabled: !BlurService.integrationBusy
                onClicked: BlurService.configureNiriIntegration()
            }

            InlineStatusBanner {
                Layout.fillWidth: true
                visible: BlurService.lastError !== ""
                tone: "error"
                message: BlurService.lastError
            }
        }
    }
}
