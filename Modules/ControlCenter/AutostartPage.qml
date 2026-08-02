import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root

    clip: true
    contentWidth: width
    contentHeight: contentColumn.y + contentColumn.implicitHeight
        + Metrics.pageMargin
    readonly property real pageContentWidth: Metrics.scaled(680)

    ColumnLayout {
        id: contentColumn
        width: Math.min(root.pageContentWidth,
            Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin, (root.width - width) / 2)
        y: Metrics.pageMargin
        spacing: Metrics.spacingL

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: AutostartService.lastError !== ""
            tone: "error"
            message: AutostartService.lastError
        }

        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("XDG 开机启动")
            supportingText: qsTr("系统级 Desktop Entry 保持只读；启停会在用户目录创建覆盖文件。路径和实际 Exec 始终可见。")

            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingS
                ComboBox {
                    id: applicationBox
                    Layout.fillWidth: true
                    model: AutostartService.applications
                    textRole: "name"
                    valueRole: "id"
                }
                DialogActionButton {
                    text: qsTr("添加已安装应用")
                    enabled: !AutostartService.busy
                        && applicationBox.currentIndex >= 0
                    onClicked: AutostartService.addApplication(
                        applicationBox.currentValue)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingS
                MaterialTextField {
                    id: idField
                    Layout.preferredWidth: Metrics.scaled(150)
                    placeholderText: qsTr("条目 ID")
                }
                MaterialTextField {
                    id: nameField
                    Layout.preferredWidth: Metrics.scaled(150)
                    placeholderText: qsTr("名称")
                }
                MaterialTextField {
                    id: commandField
                    Layout.fillWidth: true
                    placeholderText: qsTr("命令和参数")
                }
                DialogActionButton {
                    text: qsTr("添加")
                    enabled: !AutostartService.busy
                        && idField.text.trim() !== ""
                        && nameField.text.trim() !== ""
                        && commandField.text.trim() !== ""
                    onClicked: AutostartService.addCustom(
                        idField.text, nameField.text, commandField.text)
                }
            }

            Repeater {
                model: AutostartService.entries
                delegate: SettingsRow {
                    id: entryRow
                    required property var modelData
                    Layout.fillWidth: true
                    iconName: modelData.user ? "person" : "computer"
                    title: modelData.name
                    supportingText: modelData.exec + "\n" + modelData.path
                    trailing: RowLayout {
                        spacing: Metrics.spacingS
                        StyledSwitch {
                            checked: !entryRow.modelData.hidden
                            enabled: !AutostartService.busy
                            onToggled: AutostartService.setEnabled(
                                entryRow.modelData.id, checked)
                        }
                        DialogActionButton {
                            text: qsTr("删除")
                            visible: entryRow.modelData.user
                            enabled: !AutostartService.busy
                            onClicked: AutostartService.remove(
                                entryRow.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
