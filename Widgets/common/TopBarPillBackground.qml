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

        // Let MultiEffect derive the source texture padding from its blur.
        // A manually expanded paddingRect caused the source itself to vanish
        // on the Qt version used by Clavis. The PanelWindow still reserves
        // shadowPadding below the visual bar for the resulting shadow.
        autoPaddingEnabled: true
    }
}
