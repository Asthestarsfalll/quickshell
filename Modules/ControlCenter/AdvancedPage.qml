import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root

    Component.onCompleted: ThemeService.detectMatugenTargets()

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
            "title": qsTr("Fcitx5"),
            "icon": "keyboard"
        }),
        ({
            "id": "zsh",
            "title": qsTr("Zsh Prompt"),
            "icon": "terminal"
        }),
        ({
            "id": "keytop",
            "title": qsTr("Keytop"),
            "icon": "monitoring"
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
            message: qsTr("正在为已启用的程序生成 Matugen 配色…")
            iconName: "progress_activity"
        }

        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("Matugen 模板生成")

            Repeater {
                model: root.templatePrograms

                SettingsRow {
                    required property var modelData
                    readonly property bool providerAvailable:
                        ThemeService.matugenTargetAvailable(modelData.id)

                    Layout.fillWidth: true
                    iconName: modelData.icon
                    title: modelData.title
                    supportingText: !providerAvailable
                        ? qsTr("未安装或配置模板不可用") : ""

                    trailing: StyledSwitch {
                        enabled: !ThemeService.generating && providerAvailable
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

        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
        }
    }
}
