import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Material as MaterialControls
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

    function exportTitle(id) {
        if (id === "desktop")
            return qsTr("桌面图标、光标与明暗模式");
        for (let index = 0; index < root.templatePrograms.length; index += 1) {
            if (root.templatePrograms[index].id === id)
                return root.templatePrograms[index].title;
        }
        return id;
    }

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
            supportingText: qsTr("Quickshell 配色始终写入 Clavis 数据目录。下列开关只生成独立 profile 资源，不会写入你现有的应用配置；外部环境导出需要另行明确授权。")

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
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: ExternalThemeExportService.lastError !== ""
            tone: ExternalThemeExportService.conflictApplication !== ""
                ? "warning" : "error"
            message: ExternalThemeExportService.lastError
        }

        SettingsRow {
            Layout.fillWidth: true
            visible: ExternalThemeExportService.conflictApplication !== ""
            iconName: "backup"
            title: qsTr("检测到外部配置冲突")
            supportingText: qsTr("只有确认后才会备份原文件并原子替换。")

            trailing: MaterialControls.Button {
                text: qsTr("备份并替换")
                enabled: !ExternalThemeExportService.busy
                Accessible.name: qsTr("备份并替换冲突的外部主题文件")
                onClicked: ExternalThemeExportService.replaceConflict()
            }
        }

        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("外部应用主题导出")
            supportingText: qsTr("默认关闭。每个 adapter 会先检测程序和准确目标路径；冲突不会被静默覆盖，禁用时也会保留用户修改过的文件。Fcitx5 是共享会话服务，并非完全隔离。")

            Repeater {
                model: ExternalThemeExportService.applications

                SettingsRow {
                    id: exportRow
                    required property string modelData

                    readonly property var exportStatus:
                        ExternalThemeExportService.status(modelData)

                    Layout.fillWidth: true
                    iconName: exportStatus.managed ? "verified_user" : "ios_share"
                    title: root.exportTitle(modelData)
                    supportingText: (exportStatus.installed
                        ? ExternalThemeExportService.targetText(modelData)
                        : qsTr("目标程序未安装 · ")
                            + ExternalThemeExportService.targetText(modelData))

                    trailing: MaterialControls.Button {
                        text: exportRow.exportStatus.managed
                            ? qsTr("禁用") : qsTr("导出")
                        enabled: !ExternalThemeExportService.busy
                            && exportRow.exportStatus.installed
                        Accessible.name: exportRow.exportStatus.managed
                            ? qsTr("禁用 %1 外部主题导出").arg(exportRow.title)
                            : qsTr("导出 %1 外部主题").arg(exportRow.title)
                        onClicked: {
                            if (exportRow.exportStatus.managed)
                                ExternalThemeExportService.disable(exportRow.modelData);
                            else
                                ExternalThemeExportService.enable(exportRow.modelData);
                        }
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
