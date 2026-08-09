pragma Singleton

import QtQuick
import Quickshell
import qs.Services

Singleton {
    id: root

    readonly property var system: SystemMonitorService.system
    readonly property string accountName: system.systemUser || "user"
    readonly property string hostName: system.hostName || "host"
    readonly property string accountIdentity: accountName + "@" + hostName
    readonly property string wmName: system.wmName || "unknown"
    readonly property string shellName: system.shellName || "unknown"
    readonly property string kernelRelease: system.kernel || "unknown"
    readonly property string chassis: system.chassis || qsTr("电脑")
    readonly property string osAgeText: system.osAgeText || ""
    readonly property string distroId: system.distroId || "linux"
    readonly property string distroName: system.osName || "Linux"
    readonly property real uptimeSeconds: Math.max(0, Number(system.uptimeSeconds) || 0)
    readonly property string uptimeText: formatUptime(uptimeSeconds)

    Component.onCompleted: SystemMonitorService.acquire()

    function formatUptime(value) {
        const total = Math.max(0, Math.floor(Number(value) || 0));
        const days = Math.floor(total / 86400);
        const hours = Math.floor((total % 86400) / 3600);
        const minutes = Math.floor((total % 3600) / 60);
        if (days > 0)
            return qsTr("%1 天 %2 小时").arg(days).arg(hours);
        if (hours > 0)
            return qsTr("%1 小时 %2 分钟").arg(hours).arg(minutes);
        return qsTr("%1 分钟").arg(minutes);
    }
}
