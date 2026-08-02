pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Clavis.Niri 1.0
import qs.Common

Singleton {
    id: root

    readonly property string mainConfigPath:
        Paths.xdgConfigHome + "/niri/config.kdl"
    readonly property string clavisConfigDir:
        Paths.xdgConfigHome + "/niri/clavis"
    readonly property string managerPath:
        Paths.systemScriptsDir + "/manage-niri-config.py"
    readonly property string activeConfigPath:
        String(Quickshell.env("NIRI_CONFIG") || root.mainConfigPath)
    readonly property bool mainConfigActive:
        activeConfigPath === mainConfigPath
    readonly property bool canApply: mainConfigActive && !busy
    property var status: ({})
    property string lastError: ""
    property string activeDomain: ""
    property int activeRevision: 0
    property int nextRevision: 0
    property var queuedRequests: ({})
    property bool waitingForConfigLoaded: false
    readonly property bool busy: operation.running
        || restoreProcess.running || waitingForConfigLoaded

    signal statusChangedExternally()
    signal applySucceeded(string domain, int revision)
    signal applyFailed(string domain, int revision, string message)

    function refresh() {
        if (statusProcess.running)
            return
        statusProcess.command = [
            root.managerPath,
            "status",
            "--config", root.mainConfigPath,
            "--clavis-dir", root.clavisConfigDir,
            "--niri", "niri"
        ]
        statusProcess.running = true
    }

    function applyDomain(domain, payload) {
        const revision = ++root.nextRevision
        if (!root.mainConfigActive) {
            const message = qsTr("当前 Niri 会话仍在使用 %1；请重新登录后再保存配置")
                .arg(root.activeConfigPath)
            root.lastError = message
            Qt.callLater(() => root.applyFailed(domain, revision, message))
            return revision
        }
        const pending = Object.assign({}, root.queuedRequests)
        pending[domain] = ({ "revision": revision, "payload": payload })
        root.queuedRequests = pending
        root.startNext()
        return revision
    }

    function startNext() {
        if (root.busy)
            return
        const domains = Object.keys(root.queuedRequests)
        if (domains.length === 0)
            return
        const domain = domains[0]
        const request = root.queuedRequests[domain]
        const remaining = Object.assign({}, root.queuedRequests)
        delete remaining[domain]
        root.queuedRequests = remaining
        root.activeDomain = domain
        root.activeRevision = request.revision
        root.lastError = ""
        operation.command = [
            root.managerPath,
            "apply",
            "--config", root.mainConfigPath,
            "--clavis-dir", root.clavisConfigDir,
            "--domain", domain,
            "--payload-json", JSON.stringify(request.payload),
            "--niri", "niri"
        ]
        operation.running = true
    }

    function failActive(message) {
        const domain = root.activeDomain
        const revision = root.activeRevision
        root.lastError = message
        root.waitingForConfigLoaded = false
        root.activeDomain = ""
        root.activeRevision = 0
        root.applyFailed(domain, revision, message)
        root.refresh()
        Qt.callLater(root.startNext)
    }

    Process {
        id: statusProcess
        stdout: StdioCollector { id: statusOutput }
        stderr: StdioCollector { id: statusError }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.lastError = statusError.text.trim()
                return
            }
            try {
                root.status = JSON.parse(statusOutput.text)
                root.lastError = ""
                root.statusChangedExternally()
            } catch (error) {
                root.lastError = String(error)
            }
        }
    }

    Process {
        id: operation
        stderr: StdioCollector { id: operationError }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.failActive(operationError.text.trim()
                    || qsTr("无法写入 Niri 配置"))
                return
            }
            root.waitingForConfigLoaded = true
        }
    }

    Process {
        id: restoreProcess
        stderr: StdioCollector { id: restoreError }
        onExited: exitCode => {
            const message = exitCode === 0
                ? qsTr("Niri 拒绝新配置，已恢复最近有效片段")
                : (restoreError.text.trim()
                    || qsTr("Niri 拒绝新配置，且自动恢复失败"))
            root.failActive(message)
        }
    }

    Connections {
        target: Niri

        function onConfigLoaded(failed, error) {
            if (!root.waitingForConfigLoaded)
                return
            if (failed) {
                restoreProcess.command = [
                    root.managerPath,
                    "restore",
                    "--config", root.mainConfigPath,
                    "--clavis-dir", root.clavisConfigDir,
                    "--domain", root.activeDomain,
                    "--niri", "niri"
                ]
                root.waitingForConfigLoaded = false
                restoreProcess.running = true
                return
            }
            const domain = root.activeDomain
            const revision = root.activeRevision
            root.waitingForConfigLoaded = false
            root.activeDomain = ""
            root.activeRevision = 0
            root.applySucceeded(domain, revision)
            root.refresh()
            Qt.callLater(root.startNext)
        }
    }

    Component.onCompleted: root.refresh()
}
