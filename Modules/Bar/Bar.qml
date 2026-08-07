import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.Modules.Bar.Workspaces
import qs.Modules.Bar.ActiveWindow
import qs.Modules.Bar.Tray
import qs.Modules.Bar.PowerButton
import qs.Modules.Bar.SysMonitor
import qs.Modules.Bar.QuickSettings
import qs.Common
import qs.Services
import qs.Widgets.common

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: barWindow
        required property var modelData
        screen: modelData

        readonly property string edge: PersonalizationConfig.barPosition
        readonly property bool isHorizontal: edge === "top" || edge === "bottom"
        readonly property bool isTop: edge === "top"
        readonly property bool isBottom: edge === "bottom"
        readonly property bool isLeft: edge === "left"
        readonly property bool isRight: edge === "right"

        anchors {
            left: barWindow.isHorizontal || barWindow.isLeft
            top: barWindow.isTop || barWindow.isLeft || barWindow.isRight
            right: barWindow.isHorizontal || barWindow.isRight
            bottom: barWindow.isBottom || barWindow.isLeft || barWindow.isRight
        }
        color: "transparent"
        
        property real barHeight: Sizes.barHeight
        property real barWidth: Sizes.verticalBarWidth
        
        // The pill geometry remains inside barHeight. Extra transparent
        // surface space only lets the shadows finish drawing below it.
        implicitWidth: barWindow.isHorizontal
            ? 0 : barWindow.barWidth + Sizes.topBarShadowPadding
        implicitHeight: barWindow.isHorizontal
            ? barWindow.barHeight + Sizes.topBarShadowPadding : 0
        
        exclusiveZone: barWindow.isHorizontal
            ? barWindow.barHeight : barWindow.barWidth
        
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "clavis-shell-bar"
        WlrLayershell.exclusionMode: ExclusionMode.Normal

        mask: Region {
            Region { item: leftInputRegion }
            Region { item: rightInputRegion }
        }

        // --- 内容容器 ---
        Item {
            id: barContent
            // Descendant tooltips discover this context and open toward the
            // usable area instead of beyond the selected screen edge.
            property string popupEdge: barWindow.edge
            
            anchors {
                left: barWindow.isRight ? undefined : parent.left
                right: barWindow.isLeft ? undefined : parent.right
                top: barWindow.isBottom ? undefined : parent.top
                bottom: barWindow.isTop ? undefined : parent.bottom
            }
            width: barWindow.isHorizontal ? parent.width : barWindow.barWidth
            height: barWindow.isHorizontal ? barWindow.barHeight : parent.height

            // --- 左侧组件 ---
            GridLayout {
                id: leftSection
                anchors {
                    left: parent.left
                    leftMargin: barWindow.isHorizontal ? 10 : 0
                    top: barWindow.isHorizontal ? undefined : parent.top
                    topMargin: barWindow.isHorizontal ? 0 : 10
                    bottom: barWindow.isHorizontal ? parent.bottom : undefined
                    horizontalCenter: barWindow.isHorizontal
                        ? undefined : parent.horizontalCenter
                }
                width: implicitWidth
                height: implicitHeight
                rowSpacing: 8
                columnSpacing: 8
                columns: barWindow.isHorizontal ? 3 : 1

                Workspaces {
                    id: workspaces
                    screenName: barWindow.screen.name
                    vertical: !barWindow.isHorizontal
                }
                SidebarButton {
                    id: sidebarButton
                    vertical: !barWindow.isHorizontal
                    edge: barWindow.edge
                }
                ActiveWindow {
                    id: activeWindow
                    vertical: !barWindow.isHorizontal
                    edge: barWindow.edge
                }

            }

            // --- 右侧组件 ---
            GridLayout {
                id: rightSection
                anchors {
                    right: parent.right
                    rightMargin: barWindow.isHorizontal ? 10 : 0
                    bottom: parent.bottom
                    bottomMargin: barWindow.isHorizontal ? 0 : 10
                    horizontalCenter: barWindow.isHorizontal
                        ? undefined : parent.horizontalCenter
                }
                width: implicitWidth
                height: implicitHeight
                rowSpacing: 8
                columnSpacing: 8
                columns: barWindow.isHorizontal ? 3 : 1

                Tray {
                    id: tray
                    screen: barWindow.screen
                    vertical: !barWindow.isHorizontal
                    edge: barWindow.edge
                }
                SysMonitor {
                    id: sysMonitor
                    vertical: !barWindow.isHorizontal
                    edge: barWindow.edge
                    Layout.alignment: Qt.AlignVCenter
                }

                QuickSettings {
                    id: quickSettings
                    screen: barWindow.screen
                    vertical: !barWindow.isHorizontal
                    edge: barWindow.edge
                    Layout.alignment: Qt.AlignVCenter
                }
                
                
            }

            Item {
                id: leftInputRegion
                anchors.left: leftSection.left
                anchors.right: leftSection.right
                anchors.top: leftSection.top
                anchors.bottom: leftSection.bottom
            }

            Item {
                id: rightInputRegion
                anchors.left: rightSection.left
                anchors.right: rightSection.right
                anchors.top: rightSection.top
                anchors.bottom: rightSection.bottom
            }
        }

        CompositorBlurRegion {
            targetWindow: barWindow
            backgroundItem: workspaces
            additionalBackgroundItems: [
                sidebarButton,
                activeWindow,
                tray,
                sysMonitor,
                quickSettings
            ]
            radius: 18
        }
    }
}
