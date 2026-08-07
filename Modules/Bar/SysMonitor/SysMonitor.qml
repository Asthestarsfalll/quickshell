import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common 
import qs.Services
import qs.Widgets.common

Item {
    id: root

    property bool vertical: false
    property string edge: "top"
    readonly property real sideRotation: edge === "left" ? -90 : 90
    property bool isHovered: mouseArea.containsMouse
    
    implicitHeight: vertical ? contentLayout.implicitWidth + 24 : 36
    
    implicitWidth: {
        if (vertical)
            return Sizes.verticalBarWidth;
        if (isHovered) {
            return contentLayout.implicitWidth + 24;
        }
        return ramGroup.implicitWidth + 24;
    }

    Behavior on implicitWidth { 
        NumberAnimation { duration: 300; easing.type: Easing.OutQuart } 
    }

    TopBarPillBackground { anchors.fill: parent }

    // （这里原本庞大的 Process 启动子线程和 SplitParser JSON 提取，以及循环调度的 Timer 已被彻底抹去）

    // ================= 布局内容 =================
    GridLayout {
        id: contentLayout
        anchors.centerIn: parent
        rowSpacing: 12
        columnSpacing: 12
        layoutDirection: Qt.RightToLeft
        columns: 4
        rotation: root.vertical ? root.sideRotation : 0

        // --- 1. RAM (常驻) ---
        RowLayout {
            id: ramGroup
            spacing: 4
            Text { 
                text: "" 
                color: Appearance.colors.colSecondary
                font.family: Fonts.nerdFont
                font.pixelSize: 16
            }
            Text { 
                // 同时保全了原始流的传递。并在这里调取新的 ramUsedGB。toFixed(1) 可保留如 14.2G 格式：
                text: root.ramUsedGB.toFixed(1) + "G"
                color: Appearance.colors.colOnSurface
                font.family: Fonts.ui
                font.bold: true
                font.pixelSize: 13
                visible: true
            }
        }

        // --- 2. Disk (展开) ---
        RowLayout {
            id: diskGroup
            spacing: 4
            visible: opacity > 0
            opacity: root.isHovered ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200 } }
            
            Text { 
                text: "" 
                color: Appearance.colors.colPrimary
                font.family: Fonts.nerdFont
                font.pixelSize: 16
            }
            Text { 
                text: Math.round(root.diskUsage) + "%"
                color: Appearance.colors.colOnSurface
                font.family: Fonts.ui
                font.bold: true
                font.pixelSize: 13
                visible: true
            }
        }

        // --- 3. Temp (展开) ---
        RowLayout {
            id: tempGroup
            spacing: 4
            visible: opacity > 0
            opacity: root.isHovered ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200 } }
            
            Text { 
                text: "" 
                color: Appearance.colors.colTertiary
                font.family: Fonts.nerdFont
                font.pixelSize: 16
            }
            Text { 
                text: Math.round(root.coreTemp) + "°C"
                color: Appearance.colors.colOnSurface
                font.family: Fonts.ui
                font.bold: true
                font.pixelSize: 13
                visible: true
            }
        }

        // --- 4. CPU (展开) ---
        RowLayout {
            id: cpuGroup
            spacing: 4
            visible: opacity > 0
            opacity: root.isHovered ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200 } }
            
            Text { 
                text: "" 
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Fonts.nerdFont
                font.pixelSize: 16
            }
            Text { 
                text: Math.round(root.cpuUsage) + "%"
                color: Appearance.colors.colOnSurface
                font.family: Fonts.ui
                font.bold: true
                font.pixelSize: 13
                visible: true
            }
        }
    }

    // ================= 交互区域 =================
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true 
        cursorShape: Qt.PointingHandCursor
        
        onClicked: {
            Quickshell.execDetached(["gnome-system-monitor"]);
        }
    }

    readonly property real ramUsedGB:
        Number(SystemMonitorService.memory.usedBytes) / 1073741824
    readonly property real diskUsage:
        SystemMonitorService.disks.length > 0
            ? Number(SystemMonitorService.disks[0].usagePercent) : NaN
    readonly property real coreTemp:
        Number(SystemMonitorService.cpu.packageTemperatureCelsius)
            || Number(SystemMonitorService.cpu.temperatureCelsius)
    readonly property real cpuUsage:
        Number(SystemMonitorService.cpu.usagePercent)

    Component.onCompleted: SystemMonitorService.acquire()
    Component.onDestruction: SystemMonitorService.release()
}
