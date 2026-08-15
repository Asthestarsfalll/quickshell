import QtQuick
import QtQuick.Layouts
import qs.Services
import qs.Common
import qs.Components
import qs.Widgets.common

MaterialRippleButton {
    id: root

    property bool vertical: false
    readonly property string temperatureText: WeatherPlugin.hasValidData ? Math.round(UiPreferences.weatherTemperature(WeatherPlugin.currentTemperatureC)) + "°" : "--°"
    readonly property int iconSize: 20
    readonly property int temperatureSize: 12
    readonly property int contentSpacing: 6
    readonly property int iconSlotWidth: 24
    readonly property real temperatureSlotWidth: Math.ceil(temperatureMetrics.width)
    readonly property real contentWidth: iconSlotWidth + contentSpacing + temperatureSlotWidth
    readonly property real buttonWidth: contentWidth + 20
    readonly property int buttonHeight: 28
    readonly property bool active: WidgetState.leftSidebarOpen && WidgetState.leftSidebarView === "weather"

    function toggleView() {
        if (root.active) {
            WidgetState.leftSidebarOpen = false;
            return ;
        }
        WidgetState.leftSidebarView = "weather";
        WidgetState.leftSidebarOpen = true;
    }

    implicitHeight: root.vertical ? Sizes.barWeatherVerticalPillHeight : root.buttonHeight
    implicitWidth: root.vertical ? root.buttonHeight : root.buttonWidth
    buttonRadius: height / 2
    buttonRadiusPressed: height / 2
    toggled: root.active
    colBackground: Appearance.colors.colTertiaryContainer
    colBackgroundHover: root.down ? Appearance.colors.colTertiaryContainerActive : Appearance.colors.colTertiaryContainerHover
    colBackgroundToggled: Appearance.colors.colTertiaryContainer
    colBackgroundToggledHover: root.down ? Appearance.colors.colTertiaryContainerActive : Appearance.colors.colTertiaryContainerHover
    colRipple: Appearance.applyAlpha(Appearance.colors.colOnTertiaryContainer, 0.18)
    colRippleToggled: Appearance.applyAlpha(Appearance.colors.colOnTertiaryContainer, 0.18)
    releaseAction: () => {
        return root.toggleView();
    }

    TextMetrics {
        id: temperatureMetrics

        text: root.temperatureText
        font.family: Fonts.numeric
        font.pixelSize: root.temperatureSize
        font.bold: true
    }

    PopupToolTip {
        extraVisibleCondition: root.pointerHovered
        text: qsTr("天气")
    }

    contentItem: GridLayout {
        anchors.centerIn: parent
        width: root.vertical ? root.buttonHeight : root.contentWidth
        height: root.vertical ? root.height : root.buttonHeight
        rowSpacing: root.vertical ? 2 : 0
        columnSpacing: root.vertical ? 0 : root.contentSpacing
        columns: root.vertical ? 1 : 2

        Item {
            Layout.preferredWidth: root.vertical ? root.buttonHeight : root.iconSlotWidth
            Layout.preferredHeight: root.vertical ? 20 : root.buttonHeight
            Layout.alignment: Qt.AlignCenter

            MaterialSymbol {
                anchors.centerIn: parent
                text: WeatherPlugin.currentIconName || "cloud"
                iconSize: root.iconSize
                color: Appearance.colors.colOnTertiaryContainer
            }

        }

        Item {
            Layout.preferredWidth: root.vertical ? root.buttonHeight : root.temperatureSlotWidth
            Layout.preferredHeight: root.vertical ? 16 : root.buttonHeight
            Layout.alignment: Qt.AlignCenter

            Text {
                anchors.centerIn: parent
                text: root.temperatureText
                font.family: Fonts.numeric
                font.pixelSize: root.temperatureSize
                font.bold: true
                color: Appearance.colors.colOnTertiaryContainer
            }

        }

    }

}
