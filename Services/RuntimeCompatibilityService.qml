pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import Clavis.Runtime 1.0
import "../Common/functions/RuntimeCompatibility.js" as RuntimeRules

Singleton {
    id: root

    readonly property int requiredCoreProtocol: 1
    readonly property int requiredClipboardProtocol: 2
    readonly property int requiredSysmonProtocol: 1
    readonly property var requiredProtocols: ({
        "core": requiredCoreProtocol,
        "clipboard": requiredClipboardProtocol,
        "sysmon": requiredSysmonProtocol
    })
    readonly property var requiredClipboardFeatures: [
        "clipboard.inspect",
        "clipboard.mime-restore",
        "clipboard.mime-aware-store"
    ]
    readonly property string expectedRelease:
        Quickshell.env("CLAVIS_SHELL_RELEASE") || ""
    readonly property string expectedCommit:
        Quickshell.env("CLAVIS_SHELL_COMMIT") || ""
    readonly property string pluginRelease: ClavisBuildInfo.release
    readonly property string pluginCommit: ClavisBuildInfo.commit
    readonly property string commandName: {
        const configured = String(Quickshell.env("CLAVIS_KEY") || "").trim();
        return configured !== "" ? configured : Paths.stableKey;
    }

    property bool loading: false
    property bool ready: false
    property bool keyAvailable: false
    property string release: ""
    property string commit: ""
    property var protocols: ({})
    property var features: []
    property string errorCode: ""
    property string errorMessage: ""
    property string warningMessage: ""

    property string _output: ""
    property string _errorOutput: ""
    property int _exitCode: -1
    property bool _exited: false
    property bool _stdoutFinished: false

    readonly property bool releaseMatches: expectedRelease === ""
        || release === "" || expectedRelease === release
    readonly property bool commitMatches: expectedCommit === ""
        || commit === "" || expectedCommit === commit
    readonly property bool nativePluginsCompatible:
        RuntimeRules.nativePluginsCompatible(
            expectedRelease, expectedCommit, pluginRelease, pluginCommit)
    readonly property bool coreCompatible:
        nativePluginsCompatible
        && protocolCompatible("core", requiredCoreProtocol)
    readonly property bool clipboardCompatible:
        coreCompatible
        && protocolCompatible("clipboard", requiredClipboardProtocol)
        && hasFeature("clipboard.inspect")
        && hasFeature("clipboard.mime-restore")
        && hasFeature("clipboard.mime-aware-store")
    readonly property bool sysmonCompatible:
        coreCompatible
        && protocolCompatible("sysmon", requiredSysmonProtocol)

    function protocolCompatible(name, requiredVersion) {
        return RuntimeRules.protocolCompatible(
            root.keyAvailable, root.protocols, name, requiredVersion);
    }

    function hasFeature(name) {
        return RuntimeRules.hasFeature(
            root.keyAvailable, root.features, name);
    }

    function refresh() {
        if (versionProcess.running)
            return false;
        root.loading = true;
        root.ready = false;
        root.errorCode = "";
        root.errorMessage = "";
        root.warningMessage = "";
        root._output = "";
        root._errorOutput = "";
        root._exitCode = -1;
        root._exited = false;
        root._stdoutFinished = false;
        versionProcess.command = [root.commandName, "version", "--json"];
        versionProcess.running = true;
        return true;
    }

    function finalizeIfReady() {
        if (!root._exited || !root._stdoutFinished)
            return;
        root.loading = false;
        root.ready = true;
        if (root._exitCode !== 0) {
            root.keyAvailable = false;
            root.errorCode = root._exitCode === 127
                ? "key_not_found" : "key_version_failed";
            root.errorMessage = root._errorOutput.trim()
                || qsTr("无法执行 Clavis key 后端");
            return;
        }

        let response = null;
        try {
            response = JSON.parse(root._output.trim());
        } catch (exception) {
            root.keyAvailable = false;
            root.errorCode = "invalid_version_handshake";
            root.errorMessage = qsTr("key 返回了无效的版本握手");
            return;
        }
        if (!RuntimeRules.isValidHandshake(response)) {
            root.keyAvailable = false;
            root.errorCode = "invalid_version_handshake";
            root.errorMessage = qsTr("key 版本握手缺少必要字段");
            return;
        }

        root.keyAvailable = true;
        root.release = String(response.release || "");
        root.commit = String(response.commit || "");
        root.protocols = response.protocols;
        root.features = response.features;
        const evaluation = RuntimeRules.evaluate(
            response,
            root.expectedRelease,
            root.expectedCommit,
            root.pluginRelease,
            root.pluginCommit,
            root.requiredProtocols,
            root.requiredClipboardFeatures);
        if (evaluation.errorCode === "core_protocol_incompatible") {
            root.errorCode = "core_protocol_incompatible";
            root.errorMessage = qsTr("Shell 与 key 的核心协议不兼容");
        } else if (evaluation.errorCode === "native_plugin_release_mismatch") {
            root.errorCode = "native_plugin_release_mismatch";
            root.errorMessage = qsTr("原生 QML plugin 与 Shell release 不匹配");
        } else if (evaluation.warningCode === "release_mismatch") {
            root.warningMessage = qsTr("Shell 与 key 来自不同 release；当前协议兼容，但建议重启 Clavis 服务");
        }
    }

    Component.onCompleted: root.refresh()

    Process {
        id: versionProcess

        stdout: StdioCollector {
            onStreamFinished: {
                root._output = this.text;
                root._stdoutFinished = true;
                root.finalizeIfReady();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: root._errorOutput = this.text
        }
        onExited: exitCode => {
            root._exitCode = exitCode;
            root._exited = true;
            root.finalizeIfReady();
        }
    }
}
