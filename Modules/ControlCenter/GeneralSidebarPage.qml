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

    ColumnLayout {
        id: contentColumn

        width: Math.min(640, Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin, (root.width - width) / 2)
        y: Metrics.pageMargin

        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("侧边栏")

            SettingsRow {
                Layout.fillWidth: true
                iconName: "side_navigation"
                title: qsTr("保持侧边栏已加载")
                supportingText: qsTr("再次打开更快，但会增加内存占用")

                trailing: StyledSwitch {
                    checked: PersonalizationConfig.keepSidebarsLoaded
                    Accessible.name: qsTr("保持侧边栏已加载")
                    onToggled: PersonalizationConfig.setKeepSidebarsLoaded(checked)
                }
            }
        }

        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("系统卡片")

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Metrics.spacingXS
                rowSpacing: Metrics.spacingXS

                Repeater {
                    model: SystemCardService.cardIds

                    delegate: SettingsRow {
                        required property string modelData

                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        iconName: SystemCardService.cardIcon(modelData)
                        title: SystemCardService.cardName(modelData)
                        supportingText: {
                            const cards = SystemCardService.cards;
                            const state = cards ? cards[modelData] : null;
                            return state && state.container === "desktop"
                                ? qsTr("桌面") : qsTr("侧边栏");
                        }

                        trailing: StyledSwitch {
                            checked: {
                                const cards = SystemCardService.cards;
                                const state = cards
                                    ? cards[modelData] : null;
                                return state ? state.enabled : true;
                            }
                            Accessible.name: SystemCardService.cardName(
                                modelData)
                            onToggled: SystemCardService.setCardEnabled(
                                modelData, checked)
                        }
                    }
                }
            }
        }

        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("桌面卡片排版")

            StyledButtonGroup {
                Layout.fillWidth: true
                model: [
                    { value: "free", label: qsTr("自由拖拽") },
                    { value: "leastBusy", label: qsTr("最空旷处") },
                    { value: "mostBusy", label: qsTr("最密集处") }
                ]
                currentValue: SystemCardService.globalDesktopLayoutMode
                buttonHeight: 40
                horizontalPadding: 14
                onValueSelected: value =>
                    SystemCardService.setGlobalDesktopLayoutMode(value)
            }
        }
    }
}
