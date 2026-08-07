import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets.common

StyledFlickable {
    id: root

    signal sectionRequested(string section)

    clip: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + Metrics.pageMargin * 2

    ColumnLayout {
        id: contentColumn

        width: Math.min(640, Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin, (root.width - width) / 2)
        y: Metrics.pageMargin
        spacing: Metrics.spacingL

        Text {
            Layout.fillWidth: true
            text: qsTr("通用")
            color: Appearance.colors.colOnSurface
            font.family: Fonts.ui
            font.pixelSize: Typography.headlineSmall.pixelSize
            font.weight: Font.DemiBold
        }

        Text {
            Layout.fillWidth: true
            text: qsTr("调整 Shell 的常用行为与用户级启动应用。")
            color: Appearance.colors.colOnSurfaceVariant
            font.family: Fonts.ui
            font.pixelSize: Typography.bodyMedium.pixelSize
            wrapMode: Text.Wrap
        }

        MaterialCard {
            Layout.fillWidth: true
            title: qsTr("设置")
            iconName: "settings"

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "dock_to_bottom"
                text: qsTr("条栏")
                trailingIconName: "chevron_right"
                onClicked: root.sectionRequested("bar")
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "side_navigation"
                text: qsTr("侧边栏")
                trailingIconName: "chevron_right"
                onClicked: root.sectionRequested("sidebar")
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "blur_on"
                text: qsTr("透明与模糊")
                trailingIconName: "chevron_right"
                onClicked: root.sectionRequested("effects")
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "swipe"
                text: qsTr("滚动交互")
                trailingIconName: "chevron_right"
                onClicked: root.sectionRequested("scrolling")
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "rocket_launch"
                text: qsTr("开机启动")
                trailingIconName: "chevron_right"
                onClicked: root.sectionRequested("autostart")
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "apps"
                text: qsTr("默认应用")
                description: qsTr("浏览器、文件管理器和媒体播放器等")
                trailingIconName: "chevron_right"
                onClicked: root.sectionRequested("default-apps")
            }
        }
    }
}
