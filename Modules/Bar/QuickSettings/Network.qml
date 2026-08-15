import QtQuick
import qs.Services
import qs.Common
import qs.Components
import qs.Widgets.common

Item {
    id: root

    property var screen: null
    property bool vertical: false
    readonly property bool active: WidgetState.qsOpen && WidgetState.qsView === "network"
    readonly property bool expanded: !root.vertical && button.pointerHovered
    readonly property real baseSize: Sizes.barControlCircleSize
    readonly property real targetWidth: root.vertical ? (button.pointerHovered ? 34 : root.baseSize) : (root.expanded ? Math.max(root.baseSize, 18 + 6 + ssidMetrics.width + 20) : root.baseSize)
    readonly property real targetHeight: root.vertical && button.pointerHovered ? 34 : root.baseSize
    property real animatedWidth: root.targetWidth
    property real animatedHeight: root.targetHeight
    readonly property string networkIcon: {
        if (NetworkService.activeConnectionType === "ETHERNET")
            return "settings_ethernet";

        if (!NetworkService.connected)
            return "wifi_off";

        const strength = Number(NetworkService.signalStrength || 0);
        if (strength >= 80)
            return "signal_wifi_4_bar";

        if (strength >= 60)
            return "network_wifi_3_bar";

        if (strength >= 40)
            return "network_wifi_2_bar";

        if (strength >= 20)
            return "network_wifi_1_bar";

        return "signal_wifi_0_bar";
    }

    implicitWidth: root.animatedWidth
    implicitHeight: root.animatedHeight

    TextMetrics {
        id: ssidMetrics

        text: NetworkService.activeConnection
        font.family: Fonts.ui
        font.pixelSize: 12
        font.bold: true
    }

    BarRippleButton {
        id: button

        anchors.fill: parent
        buttonRadius: height / 2
        containerColor: Appearance.colors.colPrimaryContainer
        rippleColor: Appearance.colors.colOnPrimaryContainer
        releaseAction: () => {
            if (root.screen && root.screen.name)
                WidgetState.qsScreenName = root.screen.name;

            if (root.active) {
                WidgetState.qsOpen = false;
            } else {
                WidgetState.qsView = "network";
                WidgetState.qsOpen = true;
            }
        }

        contentItem: Item {
            anchors.fill: parent

            Row {
                anchors.centerIn: parent
                spacing: ssidSlot.width > 0 ? 6 : 0

                MaterialSymbol {
                    width: 18
                    height: parent.height
                    text: root.networkIcon
                    iconSize: 18
                    fill: 0
                    color: Appearance.colors.colOnPrimaryContainer
                }

                Item {
                    id: ssidSlot

                    width: root.expanded ? ssidMetrics.width : 0
                    height: parent.height
                    clip: true

                    Text {
                        anchors.centerIn: parent
                        width: ssidMetrics.width
                        text: NetworkService.activeConnection
                        opacity: root.expanded ? 1 : 0
                        font.family: Fonts.ui
                        font.pixelSize: 12
                        font.bold: true
                        color: Appearance.colors.colOnPrimaryContainer

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.animation.expressiveFastEffects.duration
                                easing.type: Appearance.animation.expressiveFastEffects.type
                                easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                            }

                        }

                    }

                    Behavior on width {
                        NumberAnimation {
                            duration: Appearance.animation.expressiveFastEffects.duration
                            easing.type: Appearance.animation.expressiveFastEffects.type
                            easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                        }

                    }

                }

            }

        }

    }

    PopupToolTip {
        extraVisibleCondition: button.pointerHovered
        text: NetworkService.connected ? ((NetworkService.activeConnection || qsTr("网络已连接")) + qsTr("\n点击打开网络设置")) : qsTr("网络未连接\n点击打开网络设置")
    }

    Behavior on animatedWidth {
        NumberAnimation {
            duration: Appearance.animation.expressiveFastEffects.duration
            easing.type: Appearance.animation.expressiveFastEffects.type
            easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
        }

    }

    Behavior on animatedHeight {
        NumberAnimation {
            duration: Appearance.animation.expressiveFastEffects.duration
            easing.type: Appearance.animation.expressiveFastEffects.type
            easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
        }

    }

}
