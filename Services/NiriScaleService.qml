pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    readonly property string sessionConfigPath:
        Paths.generatedHome + "/niri/session.kdl"
    readonly property string outputsConfigPath:
        Paths.generatedHome + "/niri/outputs.kdl"
    readonly property string activeConfigPath:
        String(Quickshell.env("NIRI_CONFIG") || "")
    readonly property bool runningOnNiri:
        String(Quickshell.env("NIRI_SOCKET") || "") !== ""
    property bool managedIncludeReady: false
    property string lastError: ""
    readonly property bool busy: writeProcess.running
    readonly property bool available: runningOnNiri
        && activeConfigPath === sessionConfigPath
        && managedIncludeReady

    signal writeSucceeded(var requestedScales)
    signal writeFailed(string message)

    function applyScales(scales, expectedOutputs) {
        if (!root.available || root.busy)
            return false
        root.lastError = ""
        writeProcess.requestedScales = scales
        writeProcess.command = [
            Paths.systemScriptsDir + "/manage-niri-outputs.py",
            "--session-config", root.sessionConfigPath,
            "--target", root.outputsConfigPath,
            "--scales-json", JSON.stringify(scales),
            "--expected-json", JSON.stringify(expectedOutputs),
            "--niri", "niri"
        ]
        writeProcess.running = true
        return true
    }

    FileView {
        id: sessionConfig

        path: root.sessionConfigPath
        blockLoading: true
        watchChanges: true

        onLoaded: root.managedIncludeReady =
            sessionConfig.text().indexOf(
                'include optional=true "'
                    + root.outputsConfigPath.replace(/\\/g, "\\\\")
                        .replace(/"/g, '\\"')
                    + '"') >= 0
        onLoadFailed: root.managedIncludeReady = false
        onFileChanged: Qt.callLater(sessionConfig.reload)
    }

    Process {
        id: writeProcess

        property var requestedScales: ({})

        stderr: StdioCollector { id: writeError }

        onExited: exitCode => {
            if (exitCode === 0) {
                root.lastError = ""
                root.writeSucceeded(requestedScales)
            } else {
                root.lastError = writeError.text.trim()
                    || qsTr("无法写入 Niri 输出缩放配置")
                root.writeFailed(root.lastError)
            }
        }
    }
}
