import QtQuick
import QtTest

import Clavis.Cava
import Clavis.Lyrics
import Clavis.Weather
import Clavis.WeatherMap

TestCase {
    name: "ClavisPluginImports"

    function test_nativeModulesAreLoaded() {
        verify(typeof AudioLevelProvider !== "undefined")
        verify(typeof CavaProvider !== "undefined")
        verify(typeof Lyrics !== "undefined")
        verify(typeof WeatherPlugin !== "undefined")
        verify(typeof WeatherMapPlugin !== "undefined")
    }
}
