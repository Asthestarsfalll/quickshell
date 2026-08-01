import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root

    clip: true
    contentWidth: width
    contentHeight: contentColumn.y + contentColumn.implicitHeight + 24

    readonly property real pageContentWidth: 600
    readonly property var templatePrograms: [
        ({
            "id": "btop",
            "title": "btop",
            "icon": "monitoring"
        }),
        ({
            "id": "cava",
            "title": "Cava",
            "icon": "graphic_eq"
        }),
        ({
            "id": "kitty",
            "title": "Kitty",
            "icon": "terminal"
        }),
        ({
            "id": "fcitx5",
            "title": "Fcitx5",
            "icon": "keyboard"
        }),
        ({
            "id": "niri",
            "title": "Niri",
            "icon": "window"
        }),
        ({
            "id": "yazi",
            "title": "Yazi",
            "icon": "folder"
        }),
        ({
            "id": "zsh_prompt",
            "title": "Zsh prompt",
            "icon": "code"
        })
    ]

    ColumnLayout {
        id: contentColumn

        width: Math.min(root.pageContentWidth,
            Math.max(0, root.width - 48))
        x: Math.max(24, (root.width - width) / 2)
        y: 28
        spacing: Appearance.spacing.medium

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: ThemeService.generating
            message: qsTr("正在生成 Clavis 与当前 Clavis profile 的 Matugen 配色…")
            iconName: "progress_activity"
        }

        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("Clavis Profile 配色")
            supportingText: qsTr("Quickshell 配色始终写入 Clavis 数据目录。下列开关只生成当前 profile 使用的资源；输出路径可在 Matugen 配置中编辑。")

            Repeater {
                model: root.templatePrograms

                SettingsRow {
                    required property var modelData

                    Layout.fillWidth: true
                    iconName: modelData.icon
                    title: modelData.title
                    supportingText:
                        PersonalizationConfig
                            .isMatugenTemplateEnabled(modelData.id)
                        ? qsTr("生成到 Clavis profile，不修改现有配置")
                        : qsTr("不生成该 profile 资源；已有资源会保留")

                    trailing: StyledSwitch {
                        enabled: !ThemeService.generating
                        checked: PersonalizationConfig
                            .isMatugenTemplateEnabled(modelData.id)
                        Accessible.name:
                            qsTr("启用 %1 Matugen 模板")
                                .arg(modelData.title)
                        onToggled:
                            ThemeService.setMatugenTemplateEnabled(
                                modelData.id, checked)
                    }
                }
            }

            SettingsActionRow {
                Layout.fillWidth: true
                text: qsTr("编辑 Matugen 配置")
                iconName: "edit_note"
                trailingIconName: "open_in_new"
                enabled: !ThemeService.generating
                Accessible.name: qsTr("使用默认编辑器打开 Matugen 配置")
                onClicked: ThemeService.openMatugenConfig()
            }

            SettingsActionRow {
                Layout.fillWidth: true
                text: qsTr("重新生成配色")
                iconName: "refresh"
                trailingIconName: ""
                enabled: !ThemeService.generating
                Accessible.name: qsTr("根据 Matugen 配置重新生成配色")
                onClicked: ThemeService.regenerateFromCurrentWallpaper()
            }
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: ThemeService.lastGenerationError !== ""
            tone: "error"
            message: ThemeService.lastGenerationError
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: ThemeService.lastGenerationMessage !== ""
                && ThemeService.lastGenerationError === ""
            message: ThemeService.lastGenerationMessage
            iconName: "check_circle"
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
        }
    }
}
