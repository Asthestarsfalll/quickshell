pragma Singleton

import QtQuick
import "functions/MetricsMath.js" as MetricsMath

QtObject {
    id: root

    // Clavis UI density is independent from Niri output scale and Qt's
    // Wayland buffer scale. Components consume these logical-pixel values and
    // must never multiply them by devicePixelRatio or an output scale.
    property real uiScale: 1.0

    function scaled(value) {
        return MetricsMath.scaled(value, root.uiScale)
    }

    readonly property real spacingXXS: scaled(2)
    readonly property real spacingXS: scaled(4)
    readonly property real spacingS: scaled(8)
    readonly property real spacingM: scaled(12)
    readonly property real spacingL: scaled(16)
    readonly property real spacingXL: scaled(24)

    readonly property real iconS: scaled(16)
    readonly property real iconM: scaled(24)
    readonly property real iconL: scaled(32)

    readonly property real controlHeightS: scaled(32)
    readonly property real controlHeightM: scaled(40)
    readonly property real controlHeightL: scaled(48)
    readonly property real controlHeightXL: scaled(56)
    readonly property real touchTarget: scaled(48)

    readonly property real cornerXS: scaled(4)
    readonly property real cornerS: scaled(12)
    readonly property real cornerM: scaled(17)
    readonly property real cornerL: scaled(23)
    readonly property real cornerXL: scaled(28)

    readonly property real cardPadding: spacingL
    readonly property real pageMargin: spacingXL
    readonly property real popupMargin: spacingL
    readonly property real dividerWidth: scaled(1)
    readonly property real sidebarWidthCompact: scaled(420)
    readonly property real sidebarWidthComfortable: scaled(540)
    readonly property real barHeight: scaled(44)
    readonly property real avatarS: scaled(32)
    readonly property real avatarM: scaled(48)
    readonly property real avatarL: scaled(64)
}
