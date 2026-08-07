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
            supportingText: qsTr("控制侧边栏关闭后的资源保留策略。")

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
    }
}
