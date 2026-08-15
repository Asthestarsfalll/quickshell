import QtQuick
import QtQuick.Layouts
import qs.Services
import qs.Common
import qs.Components
import qs.Widgets.common

MaterialRippleButton {
    id: root

    property var screen: null
    property bool vertical: false
    readonly property bool active: WidgetState.qsOpen && WidgetState.qsView === "network"
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

    implicitHeight: Sizes.barControlCircleSize
    implicitWidth: root.vertical ? Sizes.barControlCircleSize : (root.pointerHovered ? layout.implicitWidth + 20 : Sizes.barControlCircleSize)
    buttonRadius: height / 2
    buttonRadiusPressed: height / 2
    toggled: root.active
    colBackground: Appearance.colors.colPrimaryContainer
    colBackgroundHover: root.down ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colPrimaryContainerHover
    colBackgroundToggled: Appearance.colors.colPrimaryContainer
    colBackgroundToggledHover: root.down ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colPrimaryContainerHover
    colRipple: Appearance.applyAlpha(Appearance.colors.colOnPrimaryContainer, 0.16)
    colRippleToggled: Appearance.applyAlpha(Appearance.colors.colOnPrimaryContainer, 0.16)
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

    PopupToolTip {
        extraVisibleCondition: root.pointerHovered
        text: NetworkService.connected ? ((NetworkService.activeConnection || qsTr("网络已连接")) + qsTr("\n点击打开网络设置")) : qsTr("网络未连接\n点击打开网络设置")
    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Appearance.animation.expressiveFastEffects.duration
            easing.type: Appearance.animation.expressiveFastEffects.type
            easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
        }

    }

    contentItem: RowLayout {
        id: layout

        anchors.centerIn: parent
        spacing: 6

        MaterialSymbol {
            text: root.networkIcon
            iconSize: 18
            color: Appearance.colors.colOnPrimaryContainer
            fill: root.active ? 1 : 0
        }

        Text {
            text: NetworkService.activeConnection
            visible: root.pointerHovered && !root.vertical
            opacity: visible ? 1 : 0
            font.family: Fonts.ui
            font.pixelSize: 12
            font.bold: true
            color: Appearance.colors.colOnPrimaryContainer
            Layout.alignment: Qt.AlignVCenter

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.animation.expressiveFastEffects.duration
                    easing.type: Appearance.animation.expressiveFastEffects.type
                    easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                }

            }

        }

    }

}
