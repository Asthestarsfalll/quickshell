pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

Singleton {
    id: root

    // Structured weather data belongs to `key weather`; the native map
    // provider remains Clavis.WeatherMap because it owns image/tile work.
    property string commandName: {
        const configured = String(Quickshell.env("CLAVIS_KEY") || "").trim()
        return configured !== "" ? configured : Paths.stableKey
    }
    property bool loading: false
    property bool hasValidData: _valid
    property bool hasManualLocation: _manualLatitude !== null
        && _manualLongitude !== null
    property string status: "idle"
    property string errorMessage: ""
    property string locationName: ""
    property real latitude: _number(_snapshot.latitude)
    property real longitude: _number(_snapshot.longitude)
    property string lastUpdated: String(_snapshot.lastUpdated || "")
    property string nextRefreshAt: String(_snapshot.nextRefreshAt || "")

    property var _snapshot: ({})
    property var _current: ({})
    property bool _valid: false
    property var _manualLatitude: null
    property var _manualLongitude: null
    property string _manualName: ""
    property string _output: ""
    property string _errorOutput: ""
    property int _exitCode: -1
    property bool _exited: false
    property bool _stdoutFinished: false

    readonly property real currentTemperatureC: _number(_current.temperatureC)
    readonly property real currentFeelsLikeC: _number(_current.feelsLikeC)
    readonly property int currentWeatherCode: _integer(_current.weatherCode, -1)
    readonly property string currentWeatherText: String(_current.weatherText || "")
    readonly property string currentIconName: String(_current.iconName || "cloud")
    readonly property real currentWindSpeedMs: _number(_current.windSpeedMs)
    readonly property real currentWindDirection: _number(_current.windDirection)
    readonly property real currentWindGustsMs: _number(_current.windGustsMs)
    readonly property real currentUvIndex: _number(_current.uvIndex)
    readonly property real currentRelativeHumidity: _number(_current.relativeHumidity)
    readonly property real currentDewPointC: _number(_current.dewPointC)
    readonly property real currentPressureHpa: _number(_current.pressureHpa)
    readonly property real currentCloudCover: _number(_current.cloudCover)
    readonly property real currentVisibilityM: _number(_current.visibilityM)
    readonly property var currentAirQuality: _current.airQuality || ({})

    property var hourlyForecast: WeatherListModel {}
    property var dailyForecast: WeatherListModel {}
    property var dailyTrendForecast: WeatherListModel {}
    property var minutelyForecast: WeatherListModel {}

    signal dataChanged()

    function _number(value) {
        const number = Number(value)
        return isFinite(number) ? number : NaN
    }

    function _integer(value, fallback) {
        const number = Number(value)
        return isFinite(number) ? Math.round(number) : fallback
    }

    function _command() {
        const command = [root.commandName, "weather", "--json"]
        const fixture = String(Quickshell.env("CLAVIS_WEATHER_FIXTURE") || "").trim()
        if (fixture !== "")
            command.push("--fixture", fixture)
        if (root._manualLatitude !== null && root._manualLongitude !== null) {
            command.push("--latitude", String(root._manualLatitude))
            command.push("--longitude", String(root._manualLongitude))
            if (root._manualName !== "")
                command.push("--name", root._manualName)
        }
        return command
    }

    function refresh() {
        if (weatherProcess.running)
            return false
        root.loading = true
        root.errorMessage = ""
        root._output = ""
        root._errorOutput = ""
        root._exitCode = -1
        root._exited = false
        root._stdoutFinished = false
        weatherProcess.command = root._command()
        weatherProcess.running = true
        return true
    }

    function _finish() {
        if (!root._exited || !root._stdoutFinished)
            return
        root.loading = false

        let response = null
        try {
            const text = String(root._output || "").trim()
            if (text !== "")
                response = JSON.parse(text)
        } catch (exception) {
            response = null
        }

        if (root._exitCode !== 0 || !response || typeof response !== "object") {
            root.status = root._valid ? "stale" : "error"
            root.errorMessage = String(root._errorOutput || "").trim()
                || qsTr("天气数据不可用")
            root.dataChanged()
            return
        }

        root._snapshot = response
        root._current = response.current || ({})
        root._valid = response.valid === true
        root.status = String(response.status || (root._valid ? "fresh" : "error"))
        root.errorMessage = String(response.errorMessage || "")
        root.locationName = String(response.locationName || "")
        root.hourlyForecast.replace(response.hourly)
        root.dailyForecast.replace(response.daily)
        root.dailyTrendForecast.replace(response.dailyTrend || response.daily)
        root.minutelyForecast.replace(response.minutely)
        root.dataChanged()
    }

    function current() {
        return root._current
    }

    function setManualLocation(latitudeValue, longitudeValue, name) {
        const latitudeNumber = Number(latitudeValue)
        const longitudeNumber = Number(longitudeValue)
        if (!isFinite(latitudeNumber) || !isFinite(longitudeNumber))
            return false
        root._manualLatitude = latitudeNumber
        root._manualLongitude = longitudeNumber
        root._manualName = String(name || "")
        root.refresh()
        return true
    }

    function clearManualLocation() {
        root._manualLatitude = null
        root._manualLongitude = null
        root._manualName = ""
        root.refresh()
    }

    Process {
        id: weatherProcess

        stdout: StdioCollector {
            onStreamFinished: {
                root._output = this.text
                root._stdoutFinished = true
                root._finish()
            }
        }

        stderr: StdioCollector {
            onStreamFinished: root._errorOutput = this.text
        }

        onExited: exitCode => {
            root._exitCode = exitCode
            root._exited = true
            root._finish()
        }
    }

    Timer {
        interval: 30 * 60 * 1000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
