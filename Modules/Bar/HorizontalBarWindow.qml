import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Widgets.common

PanelWindow {
    id: root

    required property string edge
    readonly property real visualThickness: Sizes.barVisualThickness
    readonly property real outerEdgeMargin:
        axis.isTop ? 0 : Sizes.barOuterEdgeMargin
    readonly property real shadowBuffer: Sizes.barShadowBuffer
    readonly property real surfaceThickness:
        outerEdgeMargin + visualThickness + shadowBuffer
    readonly property real exclusiveThickness:
        outerEdgeMargin + visualThickness

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
    implicitHeight: surfaceThickness
    color: "transparent"
    exclusiveZone: exclusiveThickness

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "clavis-shell-bar-horizontal"
    WlrLayershell.exclusionMode: ExclusionMode.Normal

    Item {
        id: visualBand
        x: 0
        y: axis.isTop ? 0 : root.shadowBuffer
        width: parent.width
        height: root.visualThickness

        HorizontalBarContent {
            id: content
            anchors.fill: parent
            screen: root.screen
            axis: axis
        }
    }

    mask: Region {
        item: content.inputRegionItem
    }

    CompositorBlurRegion {
        targetWindow: root
        backgroundItem: content.workspacesItem
        additionalBackgroundItems: [
            content.sidebarButtonItem,
            content.activeWindowItem,
            content.trayItem,
            content.sysMonitorItem,
            content.quickSettingsItem
        ]
        radius: 18
    }
}
