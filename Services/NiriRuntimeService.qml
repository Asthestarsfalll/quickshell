pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Clavis.Niri 1.0

Singleton {
    id: root

    readonly property bool available: Niri.connected
    readonly property string socketPath: Niri.socketPath
    readonly property var outputs: Niri.outputs
    property var queue: []
    property var activeRequest: null
    property string lastError: ""
    readonly property bool busy: outputProcess.running || confirmProcess.running

    signal outputApplied(string outputName, var config)
    signal outputFailed(string outputName, string message)
    signal reloadFinished(bool success, string message)

    function reloadConfig() {
        if (reloadProcess.running)
            return false
        reloadProcess.command = ["niri", "msg", "action", "load-config-file"]
        reloadProcess.running = true
        return true
    }

    function applyOutput(outputName, config) {
        const next = root.queue.slice()
        next.push(({ "name": outputName, "config": config }))
        root.queue = next
        root.startNext()
    }

    function commandFor(request) {
        const config = request.config
        if (config.scale !== undefined)
            return ["niri", "msg", "output", request.name,
                "scale", String(config.scale)]
        if (config.disabled !== undefined)
            return ["niri", "msg", "output", request.name,
                config.disabled ? "off" : "on"]
        if (config.mode !== undefined)
            return ["niri", "msg", "output", request.name,
                "mode", String(config.mode)]
        if (config.transform !== undefined)
            return ["niri", "msg", "output", request.name,
                "transform", String(config.transform)]
        if (config.position !== undefined)
            return ["niri", "msg", "output", request.name,
                "position", "set", String(config.position.x),
                String(config.position.y)]
        if (config.vrr !== undefined)
            return ["niri", "msg", "output", request.name,
                "vrr", config.vrr ? "on" : "off"]
        return []
    }

    function startNext() {
        if (root.busy || root.queue.length === 0)
            return
        const next = root.queue.slice()
        const request = next.shift()
        root.queue = next
        const command = root.commandFor(request)
        if (command.length === 0) {
            root.outputFailed(request.name, qsTr("不支持的输出修改"))
            Qt.callLater(root.startNext)
            return
        }
        root.activeRequest = request
        outputProcess.command = command
        outputProcess.running = true
    }

    function modeString(output) {
        const index = Number(output.current_mode)
        const modes = output.modes || []
        if (index < 0 || index >= modes.length)
            return ""
        const mode = modes[index]
        return "%1x%2@%3".arg(mode.width).arg(mode.height)
            .arg((Number(mode.refresh_rate) / 1000).toFixed(3))
    }

    function confirmed(output, config) {
        const logical = output.logical || ({})
        if (config.scale !== undefined
                && Math.abs(Number(logical.scale) - Number(config.scale)) > 0.001)
            return false
        if (config.disabled !== undefined
                && (Number(output.current_mode) < 0) !== !!config.disabled)
            return false
        if (config.mode !== undefined
                && root.modeString(output) !== String(config.mode))
            return false
        if (config.transform !== undefined
                && String(logical.transform) !== String(config.transform))
            return false
        if (config.position !== undefined
                && (Number(logical.x) !== Number(config.position.x)
                    || Number(logical.y) !== Number(config.position.y)))
            return false
        if (config.vrr !== undefined
                && !!output.vrr_enabled !== !!config.vrr)
            return false
        return true
    }

    Process {
        id: outputProcess
        stderr: StdioCollector { id: outputError }
        onExited: exitCode => {
            const request = root.activeRequest
            if (exitCode === 0) {
                confirmProcess.command = ["niri", "msg", "-j", "outputs"]
                confirmProcess.running = true
            } else {
                root.activeRequest = null
                root.lastError = outputError.text.trim()
                    || qsTr("Niri 拒绝输出修改")
                root.outputFailed(request.name, root.lastError)
                Qt.callLater(root.startNext)
            }
        }
    }

    Process {
        id: confirmProcess
        stdout: StdioCollector { id: confirmOutput }
        stderr: StdioCollector { id: confirmError }
        onExited: exitCode => {
            const request = root.activeRequest
            root.activeRequest = null
            try {
                const outputs = exitCode === 0
                    ? JSON.parse(confirmOutput.text) : ({})
                const output = outputs[request.name]
                if (!output)
                    throw new Error(qsTr("保存前输出已断开"))
                if (!root.confirmed(output, request.config))
                    throw new Error(qsTr("Niri 返回的实际输出状态与预览不一致"))
                root.lastError = ""
                root.outputApplied(request.name, request.config)
            } catch (error) {
                root.lastError = confirmError.text.trim() || String(error)
                root.outputFailed(request.name, root.lastError)
            }
            Qt.callLater(root.startNext)
        }
    }

    Process {
        id: reloadProcess
        stderr: StdioCollector { id: reloadError }
        onExited: exitCode => root.reloadFinished(exitCode === 0,
            exitCode === 0 ? "" : (reloadError.text.trim()
                || qsTr("无法重新加载 Niri 配置")))
    }
}
