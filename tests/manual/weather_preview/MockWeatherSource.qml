import QtQuick

QtObject {
    id: root

    property bool loading: false
    property string status: "fresh"
    property double lastUpdated: Date.now()
    property string locationName: qsTr("Clavis 手动天气源")
    property string currentWeatherText: qsTr("晴朗")
    property real currentTemperatureC: 22
    property real currentFeelsLikeC: 21
    property int currentWeatherCode: 0
    property string currentIconName: "clear_day"
    property bool night: false
    property real currentWindSpeedMs: 2
    property real currentWindGustsMs: 4
    property real currentWindDirection: 135
    property real currentRelativeHumidity: 58
    property real currentDewPointC: 13
    property real currentUvIndex: 4
    property real currentVisibilityM: 16000
    property real currentPressureHpa: 1013.2
    property real highTemperatureC: 27
    property real lowTemperatureC: 16
    property var currentAirQuality: ({
        ozone: 42,
        nitrogenDioxide: 14,
        pm10: 18,
        pm25: 8
    })

    property ListModel dailyForecast: ListModel {
        dynamicRoles: true
    }
    readonly property var dailyTrendForecast: dailyForecast
    property ListModel hourlyForecast: ListModel {
        dynamicRoles: true
    }

    function current() {
        return ({ isDaylight: !root.night })
    }

    function refresh() {
        root.loading = true
        root.loading = false
        root.status = "fresh"
        root.lastUpdated = Date.now()
    }

    function rebuildForecasts() {
        const now = Math.floor(Date.now() / 1000)
        dailyForecast.clear()
        for (let offset = -1; offset <= 5; ++offset) {
            dailyForecast.append({
                time: now + offset * 86400,
                sunrise: 0,
                sunset: 0,
                moonrise: 0,
                moonset: 0,
                moonPhaseAngle: 120,
                temperatureMaxC: root.highTemperatureC - Math.abs(offset),
                temperatureMinC: root.lowTemperatureC - Math.abs(offset) * 0.5,
                day: {
                    weatherCode: root.currentWeatherCode,
                    iconName: root.currentIconName,
                    temperatureC: root.highTemperatureC,
                    rainMm: root.currentWeatherCode >= 51 ? 6.4 : 0,
                    snowCm: root.currentWeatherCode >= 71
                        && root.currentWeatherCode <= 86 ? 4.2 : 0,
                    precipitationMm: root.currentWeatherCode >= 51 ? 6.4 : 0
                },
                night: {
                    weatherCode: root.currentWeatherCode,
                    iconName: root.currentIconName,
                    temperatureC: root.lowTemperatureC,
                    rainMm: root.currentWeatherCode >= 51 ? 2.1 : 0,
                    snowCm: root.currentWeatherCode >= 71
                        && root.currentWeatherCode <= 86 ? 1.8 : 0,
                    precipitationMm: root.currentWeatherCode >= 51 ? 2.1 : 0
                }
            })
        }

        hourlyForecast.clear()
        for (let hour = 0; hour < 24; ++hour) {
            hourlyForecast.append({
                time: now + hour * 3600,
                weatherCode: root.currentWeatherCode,
                iconName: root.currentIconName,
                isDaylight: !root.night,
                temperatureC: root.currentTemperatureC + Math.sin(hour / 4) * 3,
                precipitationProbability: root.currentWeatherCode >= 51 ? 76 : 4,
                windSpeedMs: root.currentWindSpeedMs,
                windGustsMs: root.currentWindGustsMs,
                windDirection: root.currentWindDirection
            })
        }
    }

    onCurrentWeatherCodeChanged: rebuildForecasts()
    onCurrentIconNameChanged: rebuildForecasts()
    onNightChanged: rebuildForecasts()
    onCurrentWindSpeedMsChanged: rebuildForecasts()
    onCurrentWindGustsMsChanged: rebuildForecasts()
    onHighTemperatureCChanged: rebuildForecasts()
    onLowTemperatureCChanged: rebuildForecasts()
    Component.onCompleted: rebuildForecasts()
}
