import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Widgets.common

PanelWindow {
    id: root

    required property string edge
    readonly property real visualThickness: Sizes.barVisualThickness
    readonly property real outerEdgeMargin: Sizes.barOuterEdgeMargin
    readonly property real surfaceThickness: outerEdgeMargin + visualThickness
    readonly property real exclusiveThickness: outerEdgeMargin + visualThickness

    implicitHeight: surfaceThickness
    color: "transparent"
    exclusiveZone: exclusiveThickness
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "clavis-shell-bar-horizontal"
    WlrLayershell.exclusionMode: ExclusionMode.Normal

    BarAxis {
        id: axis

        edge: root.edge
    }

    anchors {
        left: true
        right: true
        top: axis.isTop
        bottom: axis.isBottom
    }

    Item {
        id: visualBand

        x: 0
        y: axis.isTop ? root.outerEdgeMargin : 0
        width: parent.width
        height: root.visualThickness

        HorizontalBarContent {
            id: content

            anchors.fill: parent
            screen: root.screen
            axis: axis
        }

    }

    CompositorBlurRegion {
        targetWindow: root
        backgroundItem: content.backgroundItems.length > 0 ? content.backgroundItems[0] : null
        additionalBackgroundItems: content.backgroundItems.slice(1)
        radius: 18
    }

    mask: Region {
        Region {
            item: content.leadingInputRegionItem
        }

        Region {
            item: content.trailingInputRegionItem
        }

    }

}
