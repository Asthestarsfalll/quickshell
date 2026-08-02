pragma Singleton

import QtQuick
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    readonly property string managerPath:
        Paths.systemScriptsDir + "/manage-xdg-autostart.py"
    property var entries: []
    property var applications: []
    property string lastError: ""
    readonly property bool busy: listProcess.running
        || applicationsProcess.running || operation.running

    signal changed()

    function refresh() {
        if (listProcess.running)
            return
        listProcess.command = [root.managerPath, "list"]
        listProcess.running = true
    }

    function addCustom(identifier, name, command) {
        operation.command = [root.managerPath, "add-custom",
            "--id", identifier, "--name", name, "--command", command]
        operation.running = true
    }

    function addApplication(identifier) {
        operation.command = [root.managerPath, "add-application",
            "--id", identifier]
        operation.running = true
    }

    function setEnabled(identifier, enabled) {
        operation.command = [root.managerPath, "set-hidden",
            "--id", identifier, "--hidden", enabled ? "false" : "true"]
        operation.running = true
    }

    function remove(identifier) {
        operation.command = [root.managerPath, "delete", "--id", identifier]
        operation.running = true
    }

    Process {
        id: listProcess
        stdout: StdioCollector { id: listOutput }
        stderr: StdioCollector { id: listError }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.lastError = listError.text.trim()
                return
            }
            try {
                root.entries = JSON.parse(listOutput.text).entries || []
                root.lastError = ""
            } catch (error) {
                root.lastError = String(error)
            }
        }
    }

    Process {
        id: applicationsProcess
        command: [root.managerPath, "applications"]
        stdout: StdioCollector { id: applicationsOutput }
        stderr: StdioCollector { id: applicationsError }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.lastError = applicationsError.text.trim()
                return
            }
            try {
                root.applications = JSON.parse(
                    applicationsOutput.text).applications || []
            } catch (error) {
                root.lastError = String(error)
            }
        }
    }

    Process {
        id: operation
        stderr: StdioCollector { id: operationError }
        onExited: exitCode => {
            root.lastError = exitCode === 0 ? "" : operationError.text.trim()
            root.refresh()
            if (exitCode === 0)
                root.changed()
        }
    }

    Component.onCompleted: {
        root.refresh()
        applicationsProcess.running = true
    }
}
