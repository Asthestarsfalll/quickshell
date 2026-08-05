pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    signal gammaChangeAttempt()

    readonly property real gammaLowerLimit: 25
    property int gamma: 100

    function clampGamma(value) {
        return Math.round(Math.max(root.gammaLowerLimit, Math.min(100, value)));
    }

    function gammaArgument() {
        return (root.gamma / 100).toFixed(2);
    }

    function stopWlsunset() {
        Quickshell.execDetached(["pkill", "-x", "wlsunset"]);
    }

    function applyGamma() {
        if (root.gamma >= 100) {
            root.stopWlsunset();
            return;
        }

        root.stopWlsunset();
        Quickshell.execDetached([
            "wlsunset",
            "-T", "6501",
            "-t", "6500",
            "-S", "00:00",
            "-s", "00:00",
            "-g", root.gammaArgument()
        ]);
    }

    function setGamma(value) {
        const safeGamma = root.clampGamma(value);
        root.gamma = safeGamma;
        root.gammaChangeAttempt();
        applyGammaTimer.restart();
    }

    Timer {
        id: applyGammaTimer

        interval: 40
        repeat: false
        onTriggered: root.applyGamma()
    }
}
