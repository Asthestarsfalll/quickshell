pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property var applications: [
        "btop", "cava", "desktop", "kitty", "fcitx5", "niri", "yazi",
        "zsh_prompt"
    ]
    property string commandName: RuntimeCompatibilityService.commandName
    property var statuses: ({})
    property bool busy: false
    property string activeApplication: ""
    property string conflictApplication: ""
    property string lastMessage: ""
    property string lastError: ""

    property var _statusQueue: []
    property string _statusOutput: ""
    property bool _statusExited: false
    property bool _statusStdoutFinished: false
    property int _statusExitCode: -1

    property string _actionOutput: ""
    property string _actionError: ""
    property bool _actionExited: false
    property bool _actionStdoutFinished: false
    property int _actionExitCode: -1

    function status(application) {
        return root.statuses[String(application)] || ({
            "installed": false,
            "managed": false,
            "files": []
        });
    }

    function targetText(application) {
        const value = root.status(application);
        if (!Array.isArray(value.files) || value.files.length === 0)
            return qsTr("正在检测导出路径…");
        return value.files.map(file => String(file.target || "")).join(" · ");
    }

    function refresh() {
        if (statusProcess.running)
            return;
        root._statusQueue = root.applications.slice();
        root.startNextStatus();
    }

    function refreshOne(application) {
        const id = String(application);
        if (root._statusQueue.indexOf(id) < 0)
            root._statusQueue = root._statusQueue.concat([id]);
        root.startNextStatus();
    }

    function startNextStatus() {
        if (statusProcess.running || root._statusQueue.length === 0)
            return;
        const queue = root._statusQueue.slice();
        root.activeApplication = String(queue.shift());
        root._statusQueue = queue;
        root._statusOutput = "";
        root._statusExited = false;
        root._statusStdoutFinished = false;
        root._statusExitCode = -1;
        statusProcess.command = [
            root.commandName, "export", root.activeApplication,
            "--status", "--json"
        ];
        statusProcess.running = true;
    }

    function finalizeStatus() {
        if (!root._statusExited || !root._statusStdoutFinished)
            return;
        if (root._statusExitCode === 0) {
            try {
                const parsed = JSON.parse(root._statusOutput.trim());
                const next = Object.assign({}, root.statuses);
                next[root.activeApplication] = parsed;
                root.statuses = next;
            } catch (exception) {
                root.lastError = qsTr("无法解析外部导出状态");
            }
        }
        root.activeApplication = "";
        Qt.callLater(root.startNextStatus);
    }

    function runAction(application, disable, replace) {
        if (actionProcess.running || root.busy)
            return false;
        root.busy = true;
        root.activeApplication = String(application);
        root.lastError = "";
        root.lastMessage = "";
        root.conflictApplication = "";
        root._actionOutput = "";
        root._actionError = "";
        root._actionExited = false;
        root._actionStdoutFinished = false;
        root._actionExitCode = -1;
        const command = [
            root.commandName, "export", root.activeApplication, "--json"
        ];
        if (disable)
            command.push("--disable");
        else if (replace)
            command.push("--replace");
        if (root.activeApplication === "desktop" && !disable) {
            command.push("--icon-theme", ThemeService.effectiveIconTheme());
            command.push("--cursor-theme", ThemeService.effectiveCursorTheme());
            command.push("--cursor-size", String(PersonalizationConfig.cursorSize));
            command.push("--color-scheme",
                PersonalizationConfig.themeMode === "dark"
                    ? "prefer-dark" : "default");
        }
        actionProcess.command = command;
        actionProcess.running = true;
        return true;
    }

    function enable(application) {
        return root.runAction(application, false, false);
    }

    function replaceConflict() {
        if (root.conflictApplication === "")
            return false;
        return root.runAction(root.conflictApplication, false, true);
    }

    function disable(application) {
        return root.runAction(application, true, false);
    }

    function finalizeAction() {
        if (!root._actionExited || !root._actionStdoutFinished)
            return;
        const application = root.activeApplication;
        root.busy = false;
        root.activeApplication = "";
        if (root._actionExitCode === 0) {
            root.lastMessage = qsTr("外部主题导出状态已更新");
            root.refreshOne(application);
            return;
        }
        root.lastError = root._actionError.trim()
            || qsTr("外部主题导出失败");
        if (root.lastError.indexOf("export conflict") >= 0)
            root.conflictApplication = application;
    }

    Component.onCompleted: root.refresh()

    Process {
        id: statusProcess
        stdout: StdioCollector {
            onStreamFinished: {
                root._statusOutput = this.text;
                root._statusStdoutFinished = true;
                root.finalizeStatus();
            }
        }
        onExited: exitCode => {
            root._statusExitCode = exitCode;
            root._statusExited = true;
            root.finalizeStatus();
        }
    }

    Process {
        id: actionProcess
        stdout: StdioCollector {
            onStreamFinished: {
                root._actionOutput = this.text;
                root._actionStdoutFinished = true;
                root.finalizeAction();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: root._actionError = this.text
        }
        onExited: exitCode => {
            root._actionExitCode = exitCode;
            root._actionExited = true;
            root.finalizeAction();
        }
    }
}
