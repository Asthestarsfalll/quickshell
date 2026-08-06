pragma Singleton

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    readonly property string managerPath:
        Paths.systemScriptsDir + "/manage-xdg-autostart.py"
    readonly property string configHome:
        StandardPaths.writableLocation(StandardPaths.ConfigLocation)
    readonly property string autostartDir: root.configHome + "/autostart"

    property var entries: []
    property string lastError: ""
    property string lastMessage: ""
    property string operationName: ""
    property bool preserveOperationError: false
    readonly property bool busy: listProcess.running || operation.running

    signal operationFinished(bool success, string operation)

    function clearStatus() {
        root.lastError = "";
        root.lastMessage = "";
    }

    function refresh() {
        if (listProcess.running || operation.running)
            return;
        listProcess.command = [root.managerPath, "list"];
        listProcess.running = true;
    }

    function applicationCommand(application) {
        if (!application)
            return "";
        return String(application.execString || application.exec || "").trim();
    }

    function addApplication(application) {
        const id = String(application ? application.id || "" : "").trim();
        const name = String(application ? application.name || id : id).trim();
        const command = root.applicationCommand(application);
        if (id === "" || name === "" || command === "") {
            root.lastError = qsTr("所选应用缺少有效的 Desktop Entry 信息");
            return false;
        }
        if (root.busy)
            return false;
        root.clearStatus();
        root.operationName = "add-application";
        operation.command = [root.managerPath, "add-application",
            "--id", id, "--name", name, "--exec", command,
            "--icon", String(application ? application.icon || "" : "")];
        operation.running = true;
        return true;
    }

    function setEnabled(entry, enabled) {
        const id = String(entry ? entry.id || "" : "").trim();
        if (id === "" || root.busy)
            return false;
        root.clearStatus();
        root.operationName = "set-hidden";
        operation.command = [root.managerPath, "set-hidden", "--id", id,
            "--hidden", enabled ? "false" : "true"];
        operation.running = true;
        return true;
    }

    function remove(entry) {
        const id = String(entry ? entry.id || "" : "").trim();
        if (id === "" || root.busy)
            return false;
        root.clearStatus();
        root.operationName = "delete";
        operation.command = [root.managerPath, "delete", "--id", id];
        operation.running = true;
        return true;
    }

    function parseList(text) {
        const result = JSON.parse(text);
        if (result.schemaVersion !== 1)
            throw new Error(qsTr("自启服务返回了不支持的数据版本"));
        return result;
    }

    Process {
        id: listProcess
        stdout: StdioCollector { id: listOutput }
        stderr: StdioCollector { id: listError }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.lastError = listError.text.trim() || qsTr("无法读取用户自启目录");
                root.preserveOperationError = false;
                return;
            }
            try {
                const result = root.parseList(listOutput.text);
                root.entries = Array.isArray(result.entries) ? result.entries : [];
                if (!root.preserveOperationError)
                    root.lastError = "";
                root.preserveOperationError = false;
            } catch (error) {
                root.lastError = String(error);
                root.preserveOperationError = false;
            }
        }
    }

    Process {
        id: operation
        stdout: StdioCollector { id: operationOutput }
        stderr: StdioCollector { id: operationError }

        onExited: exitCode => {
            const completedOperation = root.operationName;
            const success = exitCode === 0;
            if (success) {
                if (completedOperation === "add-application")
                    root.lastMessage = qsTr("应用已添加到开机启动");
                else if (completedOperation === "set-hidden")
                    root.lastMessage = qsTr("自启状态已更新");
                else if (completedOperation === "delete")
                    root.lastMessage = qsTr("自启条目已删除");
                root.lastError = "";
            } else {
                root.lastError = operationError.text.trim()
                    || qsTr("自启操作失败");
            }
            root.preserveOperationError = !success;
            root.operationFinished(success, completedOperation);
            root.operationName = "";
            root.refresh();
        }
    }
}
