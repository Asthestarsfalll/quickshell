import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Services

Item {
    id: root

    property color fillColor: BlurService.backgroundColor(
        Appearance.colors.colLayer0)
    property real cornerRadius: height / 2
    property real shadowPadding: Sizes.topBarShadowPadding

    Rectangle {
        id: sourceItem

        anchors.fill: parent
        color: root.fillColor
        radius: root.cornerRadius
        visible: false
    }

    MultiEffect {
        anchors.fill: sourceItem
        source: sourceItem
        shadowEnabled: true
        shadowColor: Appearance.applyAlpha(
            Appearance.colors.colShadow, 0.4)
        shadowBlur: 0.8
        shadowVerticalOffset: 3
        shadowHorizontalOffset: 0

        // Make the effect's texture boundary explicit. The top-level bar
        // surface reserves the same bottom extent, so neither layer clips the
        // pill shadow before its alpha falloff reaches zero.
        autoPaddingEnabled: false
        paddingRect: Qt.rect(
            -root.shadowPadding,
            -root.shadowPadding,
            root.shadowPadding * 2,
            root.shadowPadding * 2)
    }
}
