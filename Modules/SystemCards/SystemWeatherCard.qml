import QtQuick
import M3Shapes
import qs.Common
import qs.Components
import qs.Services

Item {
    id: root

    readonly property bool dataAvailable: WeatherPlugin.hasValidData
    readonly property string temperature: root.dataAvailable && isFinite(Number(WeatherPlugin.currentTemperatureC)) ? Math.round(UiPreferences.weatherTemperature(WeatherPlugin.currentTemperatureC)) + "°" : "--°"
    readonly property string weatherIcon: root.dataAvailable && String(WeatherPlugin.currentIconName || "").length > 0 ? WeatherPlugin.currentIconName : "cloud"

    Accessible.name: qsTr("天气，") + root.temperature + "，" + (root.dataAvailable ? WeatherPlugin.currentWeatherText : qsTr("天气不可用"))

    MaterialShape {
        id: weatherPill

        readonly property real contentInset: Appearance.spacing.large

        anchors.centerIn: parent
        width: Math.max(0, Math.min(parent.width, parent.height) - Appearance.spacing.large * 2)
        height: width
        shape: MaterialShape.Pill
        color: Appearance.colors.colPrimaryContainer
        animationDuration: Appearance.animation.expressiveSlowSpatial.duration
        animationEasing: Appearance.animation.expressiveSlowSpatial.type

        Text {
            text: root.temperature
            color: Appearance.colors.colPrimary
            renderType: Text.NativeRendering

            anchors {
                top: parent.top
                right: parent.right
                topMargin: weatherPill.contentInset
                rightMargin: weatherPill.contentInset
            }

            font {
                family: Fonts.expressive
                pixelSize: Math.min(80, weatherPill.height * 0.34)
                weight: Font.Medium
            }

        }

        MaterialSymbol {
            text: root.weatherIcon
            iconSize: Math.min(80, weatherPill.height * 0.34)
            fill: 0
            color: Appearance.colors.colOnPrimaryContainer

            anchors {
                left: parent.left
                bottom: parent.bottom
                leftMargin: weatherPill.contentInset
                bottomMargin: weatherPill.contentInset
            }

        }

    }

}
