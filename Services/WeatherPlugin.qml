pragma Singleton

import QtQuick
import Clavis.Weather as NativeWeather

// Compatibility facade for the existing QML service namespace. All weather
// state and network work lives in the in-process Clavis.Weather singleton.
QtObject {
    id: root

    readonly property var backend: NativeWeather.WeatherPlugin
    readonly property bool loading: backend.loading
    readonly property bool hasValidData: backend.hasValidData
    readonly property bool hasManualLocation: backend.hasManualLocation
    readonly property string status: backend.status
    readonly property string errorMessage: backend.errorMessage
    readonly property string locationName: backend.locationName
    readonly property real latitude: backend.latitude
    readonly property real longitude: backend.longitude
    readonly property string lastUpdated: backend.lastUpdated
    readonly property string nextRefreshAt: backend.nextRefreshAt

    readonly property real currentTemperatureC: backend.currentTemperatureC
    readonly property real currentFeelsLikeC: backend.currentFeelsLikeC
    readonly property int currentWeatherCode: backend.currentWeatherCode
    readonly property string currentWeatherText: backend.currentWeatherText
    readonly property string currentIconName: backend.currentIconName
    readonly property real currentWindSpeedMs: backend.currentWindSpeedMs
    readonly property real currentWindDirection: backend.currentWindDirection
    readonly property real currentWindGustsMs: backend.currentWindGustsMs
    readonly property real currentUvIndex: backend.currentUvIndex
    readonly property real currentRelativeHumidity: backend.currentRelativeHumidity
    readonly property real currentDewPointC: backend.currentDewPointC
    readonly property real currentPressureHpa: backend.currentPressureHpa
    readonly property real currentCloudCover: backend.currentCloudCover
    readonly property real currentVisibilityM: backend.currentVisibilityM
    readonly property var currentAirQuality: backend.currentAirQuality

    readonly property var hourlyForecast: backend.hourlyForecast
    readonly property var dailyForecast: backend.dailyForecast
    readonly property var dailyTrendForecast: backend.dailyTrendForecast
    readonly property var minutelyForecast: backend.minutelyForecast

    signal dataChanged()

    function refresh() { return backend.refresh() }
    function setManualLocation(latitudeValue, longitudeValue, name) {
        return backend.setManualLocation(latitudeValue, longitudeValue, name)
    }
    function clearManualLocation() { return backend.clearManualLocation() }
    function current() { return backend.current() }

    readonly property Connections backendConnections: Connections {
        target: root.backend
        function onDataChanged() { root.dataChanged() }
    }
}
