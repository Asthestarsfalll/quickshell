pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../Common/functions/AwwwCommand.js" as AwwwCommand

Singleton {
    id: root

    readonly property string namespaceName: "clavis-desktop"
    readonly property string awwwCommand:
        Quickshell.env("CLAVIS_AWWW_COMMAND") || "awww"
    readonly property string daemonCommand:
        Quickshell.env("CLAVIS_AWWW_DAEMON_COMMAND")
            || "awww-daemon"

    property bool available: false
    property bool probeComplete: false
    property bool daemonRunning: false
    property bool quickshellSurfaceRequested: true
    property string requestedBackend: "quickshell"
    property string effectiveBackend: "quickshell"
    property string state: "probing"
    property string lastError: ""
    property var readyScreens: ({})
    property var expectedQuickshellScreens: []
    property int surfaceGeneration: 0
    property int queryAttempts: 0
    property string queryPurpose: ""
    property var applyOutputs: []
    property int applyIndex: 0
    property bool activationApply: false
    property bool reapplyPending: false
    property bool stoppingForQuickshell: false
    property bool daemonShutdownRequested: false
    property int shutdownQueryAttempts: 0
    property bool fallbackErrorActive: false

    readonly property bool busy:
        state === "starting"
        || state === "waiting-socket"
        || state === "applying"
        || state === "waiting-quickshell"
        || state === "stopping"
    readonly property bool quickshellDesktopReady:
        root.allQuickshellSurfacesReady()

    function screenNames() {
        const names = [];
        for (let index = 0; index < Quickshell.screens.length;
                index += 1) {
            names.push(String(Quickshell.screens[index].name));
        }
        return names;
    }

    function transitionOptions() {
        return {
            type: PersonalizationConfig.awwwDesktopTransitionType,
            fps: PersonalizationConfig.awwwTransitionFps,
            durationMs: PersonalizationConfig.transitionDurationMs,
            bezierCurve:
                PersonalizationConfig.transitionBezierCurve,
            angle: PersonalizationConfig.awwwTransitionAngle,
            position:
                PersonalizationConfig.awwwTransitionPosition,
            wave: PersonalizationConfig.awwwTransitionWave
        };
    }

    function allQuickshellSurfacesReady() {
        const names = root.expectedQuickshellScreens;
        for (let index = 0; index < names.length; index += 1) {
            if (root.readyScreens[names[index]] !== true)
                return false;
        }
        return names.length > 0;
    }

    function reportQuickshellSurface(screenName, generation, ready,
                                     errorMessage) {
        if (Number(generation) !== root.surfaceGeneration)
            return;

        const name = String(screenName || "");
        if (root.expectedQuickshellScreens.indexOf(name) === -1)
            return;

        const next = {};
        for (let key in root.readyScreens)
            next[key] = root.readyScreens[key];
        next[name] = !!ready;
        root.readyScreens = next;

        if (errorMessage)
            WallpaperService.reportDesktopError(
                name, errorMessage);
        else if (ready)
            WallpaperService.clearDesktopError(name);

        if (root.state === "waiting-quickshell"
                && root.effectiveBackend === "awww"
                && errorMessage) {
            root.failQuickshellActivation(errorMessage);
            return;
        }

        if (root.state === "waiting-quickshell"
                && root.allQuickshellSurfacesReady()) {
            root.finishQuickshellActivation();
        }
    }

    function setRequestedBackend(value) {
        const backend = value === "awww" ? "awww" : "quickshell";
        root.requestedBackend = backend;
        if (backend === "awww") {
            root.daemonShutdownRequested = false;
            root.beginAwwwActivation();
        } else {
            root.beginQuickshellActivation();
        }
    }

    function failAwwwActivation(message) {
        root.lastError = message || qsTr("awww 桌面后端启动失败");
        root.fallbackErrorActive = true;
        root.state = "error";
        root.effectiveBackend = "quickshell";
        root.quickshellSurfaceRequested = true;
        root.activationApply = false;
        root.applyOutputs = [];
        root.applyIndex = 0;
        if (PersonalizationConfig.desktopWallpaperBackend
                !== "quickshell") {
            PersonalizationConfig.setDesktopWallpaperBackend(
                "quickshell");
        }
        if (root.daemonRunning)
            root.stopDaemon(false);
    }

    function beginAwwwActivation() {
        root.fallbackErrorActive = false;
        root.stoppingForQuickshell = false;
        if (!root.probeComplete) {
            root.state = "probing";
            return;
        }
        if (!root.available) {
            root.failAwwwActivation(
                qsTr("未找到 awww 或 awww-daemon，已回退到 Quickshell"));
            return;
        }
        if (root.effectiveBackend === "awww"
                && root.state === "ready") {
            root.scheduleApplyAll(false);
            return;
        }

        root.lastError = "";
        root.state = "starting";
        root.quickshellSurfaceRequested = true;
        root.queryPurpose = "startup";
        root.queryAttempts = 0;
        root.runQuery();
    }

    function beginQuickshellActivation() {
        if (!root.fallbackErrorActive)
            root.lastError = "";
        root.quickshellSurfaceRequested = true;
        root.surfaceGeneration += 1;
        root.expectedQuickshellScreens = root.screenNames();
        root.readyScreens = {};

        if (root.effectiveBackend === "quickshell"
                && !root.daemonRunning) {
            quickshellReadyTimeout.stop();
            root.state = "ready";
            return;
        }

        root.state = "waiting-quickshell";
        if (root.effectiveBackend === "awww")
            quickshellReadyTimeout.restart();
        else
            quickshellReadyTimeout.stop();
        if (root.allQuickshellSurfacesReady())
            root.finishQuickshellActivation();
    }

    function failQuickshellActivation(message) {
        quickshellReadyTimeout.stop();
        root.lastError = message
            || qsTr("Quickshell 桌面壁纸未能就绪，继续使用 awww");
        root.effectiveBackend = "awww";
        root.quickshellSurfaceRequested = false;
        root.state = "ready";
        root.readyScreens = {};
        root.expectedQuickshellScreens = [];
        if (PersonalizationConfig.desktopWallpaperBackend !== "awww")
            PersonalizationConfig.setDesktopWallpaperBackend("awww");
    }

    function finishQuickshellActivation() {
        quickshellReadyTimeout.stop();
        if (root.requestedBackend !== "quickshell")
            return;
        root.effectiveBackend = "quickshell";
        root.expectedQuickshellScreens = root.screenNames();
        root.state = root.daemonRunning ? "stopping" : "ready";
        if (root.daemonRunning)
            root.stopDaemon(true);
        else
            root.stoppingForQuickshell = false;
    }

    function runQuery() {
        if (queryProcess.running
                || root.requestedBackend !== "awww")
            return;
        root.state = "waiting-socket";
        queryProcess.command = AwwwCommand.query(
            root.awwwCommand, root.namespaceName);
        queryProcess.running = true;
    }

    function startDaemon() {
        if (root.requestedBackend !== "awww")
            return;
        if (daemonProcess.running) {
            root.queryAttempts = 0;
            queryRetry.restart();
            return;
        }
        root.state = "starting";
        daemonProcess.command = AwwwCommand.daemon(
            root.daemonCommand, root.namespaceName);
        daemonProcess.running = true;
    }

    function scheduleApplyAll(forActivation) {
        if (root.requestedBackend !== "awww")
            return;
        if (!root.available || !root.daemonRunning)
            return;
        if (!forActivation
                && PersonalizationConfig.desktopWallpaperBackend
                    !== "awww")
            return;
        if (applyProcess.running || root.state === "applying") {
            root.reapplyPending = true;
            return;
        }

        root.applyOutputs = root.screenNames();
        root.applyIndex = 0;
        root.activationApply = !!forActivation;
        root.state = "applying";
        root.applyNext();
    }

    function applyNext() {
        if (root.requestedBackend !== "awww") {
            root.applyOutputs = [];
            root.applyIndex = 0;
            root.activationApply = false;
            root.reapplyPending = false;
            return;
        }

        if (root.applyIndex >= root.applyOutputs.length) {
            const wasActivation = root.activationApply;
            root.applyOutputs = [];
            root.applyIndex = 0;
            root.activationApply = false;
            root.lastError = "";

            if (wasActivation) {
                root.effectiveBackend = "awww";
                root.quickshellSurfaceRequested = false;
                root.state = "ready";
            } else {
                root.state = root.effectiveBackend === "awww"
                    ? "ready" : root.state;
            }

            if (root.reapplyPending) {
                root.reapplyPending = false;
                Qt.callLater(() => root.scheduleApplyAll(false));
            }
            return;
        }

        const output = root.applyOutputs[root.applyIndex];
        const source = WallpaperService.wallpaperForScreen(output);
        if (!source) {
            root.lastError =
                qsTr("没有可应用到 %1 的桌面壁纸").arg(output);
            if (root.activationApply)
                root.failAwwwActivation(root.lastError);
            else {
                root.applyIndex += 1;
                root.applyNext();
            }
            return;
        }

        applyProcess.outputName = output;
        applyProcess.command = AwwwCommand.apply(
            root.awwwCommand,
            root.namespaceName,
            output,
            source,
            WallpaperService.fillModeForScreen(output),
            root.transitionOptions());
        applyProcess.running = true;
    }

    function stopDaemon(forQuickshell) {
        if (stopProcess.running) {
            root.stoppingForQuickshell =
                root.stoppingForQuickshell || !!forQuickshell;
            return;
        }
        root.stoppingForQuickshell = !!forQuickshell;
        root.daemonShutdownRequested = true;
        root.shutdownQueryAttempts = 0;
        stopProcess.command = AwwwCommand.stop(
            root.awwwCommand, root.namespaceName);
        stopProcess.running = true;
    }

    function runShutdownQuery() {
        if (shutdownQueryProcess.running
                || root.requestedBackend !== "quickshell")
            return;
        shutdownQueryProcess.command = AwwwCommand.query(
            root.awwwCommand, root.namespaceName);
        shutdownQueryProcess.running = true;
    }

    function supportsDuration(transitionType) {
        return AwwwCommand.supportsDuration(transitionType);
    }

    function supportsBezier(transitionType) {
        return AwwwCommand.supportsBezier(transitionType);
    }

    Component.onCompleted: {
        probeClient.running = true;
    }

    Connections {
        target: PersonalizationConfig

        function onDesktopWallpaperBackendChanged() {
            root.setRequestedBackend(
                PersonalizationConfig.desktopWallpaperBackend);
        }
    }

    Connections {
        target: WallpaperService

        function onRevisionChanged() {
            if (PersonalizationConfig.desktopWallpaperBackend
                    === "awww"
                    && (root.effectiveBackend === "awww"
                    || root.state === "applying")) {
                root.scheduleApplyAll(false);
            }
        }

        function onSettingsRevisionChanged() {
            if (PersonalizationConfig.desktopWallpaperBackend
                    === "awww"
                    && root.effectiveBackend === "awww")
                root.scheduleApplyAll(false);
        }
    }

    Connections {
        target: Quickshell

        function onScreensChanged() {
            root.readyScreens = {};
            root.surfaceGeneration += 1;
            root.expectedQuickshellScreens = root.screenNames();
            if (root.state === "waiting-quickshell")
                quickshellReadyTimeout.restart();
            if (root.effectiveBackend === "awww")
                root.scheduleApplyAll(false);
        }
    }

    Process {
        id: probeClient
        command: ["which", root.awwwCommand]
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.available = false;
                root.probeComplete = true;
                root.setRequestedBackend(
                    PersonalizationConfig.desktopWallpaperBackend);
                return;
            }
            probeDaemon.running = true;
        }
    }

    Process {
        id: probeDaemon
        command: ["which", root.daemonCommand]
        onExited: exitCode => {
            root.available = exitCode === 0;
            root.probeComplete = true;
            root.setRequestedBackend(
                PersonalizationConfig.desktopWallpaperBackend);
        }
    }

    Process {
        id: daemonProcess

        onRunningChanged: {
            if (running) {
                root.daemonRunning = true;
                root.queryAttempts = 0;
                queryRetry.restart();
            }
        }

        onExited: exitCode => {
            root.daemonRunning = false;
            if (root.daemonShutdownRequested
                    || root.requestedBackend === "quickshell"
                    || root.state === "stopping"
                    || root.effectiveBackend === "quickshell") {
                if (root.requestedBackend === "quickshell"
                        && !root.fallbackErrorActive)
                    root.lastError = "";
                return;
            }

            // The child process is not the source of truth: awww may exit
            // because an already-running namespace owns the socket. Verify
            // the namespace before treating this as a backend failure.
            root.queryPurpose = "verify-daemon-exit";
            root.queryAttempts = 0;
            queryRetry.restart();
        }
    }

    Process {
        id: queryProcess

        onExited: exitCode => {
            if (root.requestedBackend !== "awww")
                return;
            if (exitCode === 0) {
                root.daemonRunning = true;
                root.queryAttempts = 0;
                root.scheduleApplyAll(true);
                return;
            }

            if (root.queryPurpose === "startup"
                    && !daemonProcess.running
                    && root.queryAttempts === 0) {
                root.queryAttempts += 1;
                root.startDaemon();
                return;
            }

            root.queryAttempts += 1;
            if (root.queryAttempts >= 20) {
                root.failAwwwActivation(
                    qsTr("awww namespace clavis-desktop 未在超时前就绪"));
                return;
            }
            queryRetry.restart();
        }
    }

    Timer {
        id: queryRetry
        interval: 100
        repeat: false
        onTriggered: root.runQuery()
    }

    Timer {
        id: quickshellReadyTimeout

        interval: 15000
        repeat: false
        onTriggered: root.failQuickshellActivation(
            qsTr("Quickshell 桌面壁纸未在超时前就绪，继续使用 awww"))
    }

    Process {
        id: applyProcess

        property string outputName: ""

        onExited: exitCode => {
            if (root.requestedBackend !== "awww") {
                root.applyOutputs = [];
                root.applyIndex = 0;
                root.activationApply = false;
                root.reapplyPending = false;
                return;
            }
            if (exitCode !== 0) {
                const message =
                    qsTr("awww 无法为 %1 应用桌面壁纸，退出码 %2")
                        .arg(outputName).arg(exitCode);
                root.lastError = message;
                WallpaperService.reportDesktopError(
                    outputName, message);
                if (root.activationApply) {
                    root.failAwwwActivation(message);
                    return;
                }
            } else {
                WallpaperService.clearDesktopError(outputName);
            }

            root.applyIndex += 1;
            root.applyNext();
        }
    }

    Process {
        id: stopProcess

        onExited: {
            // The kill client only confirms that the request was sent.
            // Namespace disappearance is confirmed separately via query.
            root.shutdownQueryAttempts = 0;
            shutdownQueryRetry.restart();
        }
    }

    Process {
        id: shutdownQueryProcess

        onExited: exitCode => {
            if (root.requestedBackend !== "quickshell")
                return;

            if (exitCode !== 0) {
                root.daemonRunning = false;
                root.daemonShutdownRequested = false;
                root.stoppingForQuickshell = false;
                if (!root.fallbackErrorActive)
                    root.lastError = "";
                root.state = "ready";
                return;
            }

            root.daemonRunning = true;
            root.shutdownQueryAttempts += 1;
            if (root.shutdownQueryAttempts >= 20) {
                root.daemonShutdownRequested = false;
                root.stoppingForQuickshell = false;
                root.lastError = qsTr(
                    "clavis-desktop awww namespace 未在超时前停止");
                root.state = "ready";
                return;
            }
            shutdownQueryRetry.restart();
        }
    }

    Timer {
        id: shutdownQueryRetry

        interval: 100
        repeat: false
        onTriggered: root.runShutdownQuery()
    }
}
