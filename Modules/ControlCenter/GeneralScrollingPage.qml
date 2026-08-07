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
            title: qsTr("滚动交互")

            SettingsRow {
                Layout.fillWidth: true
                iconName: "swipe"
                title: qsTr("平滑滚轮")

                trailing: StyledSwitch {
                    checked: PersonalizationConfig.scrollSmoothEnabled
                    Accessible.name: qsTr("平滑滚轮")
                    onToggled: PersonalizationConfig.setScrollSmoothEnabled(checked)
                }
            }

            GeneralSliderSetting {
                title: qsTr("鼠标滚轮速度")
                from: 10
                to: 240
                stepSize: 5
                value: PersonalizationConfig.scrollMouseFactor
                onMoved: value => PersonalizationConfig
                    .setScrollMouseFactor(value)
            }

            GeneralSliderSetting {
                title: qsTr("触摸板滚动速度")
                from: 10
                to: 300
                stepSize: 5
                value: PersonalizationConfig.scrollTouchpadFactor
                onMoved: value => PersonalizationConfig
                    .setScrollTouchpadFactor(value)
            }

            GeneralSliderSetting {
                title: qsTr("滚轮识别阈值")
                description: qsTr("angleDelta 大于该值时按鼠标滚轮处理")
                from: 60
                to: 240
                stepSize: 10
                value: PersonalizationConfig.scrollMouseDeltaThreshold
                onMoved: value => PersonalizationConfig
                    .setScrollMouseDeltaThreshold(value)
            }
        }
    }
}
