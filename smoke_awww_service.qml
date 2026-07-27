//@ pragma UseQApplication

import QtQuick
import Quickshell
import qs.Modules.Wallpaper
import qs.Services

ShellRoot {
    id: root

    property int phase: 0
    property var savedConfig: ({})
    property string failure: ""
    readonly property bool expectApplyFailure:
        Quickshell.env("CLAVIS_AWWW_MOCK_FAIL_APPLY") === "1"

    WallpaperBackground {}

    function verify(condition, message) {
        if (!condition)
            throw new Error(message);
    }

    function finish(passed, message) {
        if (savedConfig.wallpaper !== undefined) {
            PersonalizationConfig.loadFromObject(savedConfig);
            PersonalizationConfig.loading = false;
        }
        console.log(passed
            ? "AWWW_SERVICE_SMOKE_PASS"
            : "AWWW_SERVICE_SMOKE_FAIL", message || "");
        Qt.callLater(Qt.quit);
    }

    Timer {
        interval: 25
        repeat: true
        running: true

        onTriggered: {
            try {
                if (!PersonalizationConfig.storeReady
                        || !AwwwWallpaperService.probeComplete)
                    return;

                if (root.phase === 0) {
                    root.savedConfig = JSON.parse(JSON.stringify(
                        PersonalizationConfig.toJson()));
                    PersonalizationConfig.loading = true;
                    PersonalizationConfig.desktopWallpaperBackend =
                        "awww";
                    root.phase = 1;
                    return;
                }

                if (root.phase === 1
                        && root.expectApplyFailure
                        && AwwwWallpaperService.effectiveBackend
                            === "quickshell"
                        && !AwwwWallpaperService.daemonRunning
                        && AwwwWallpaperService.lastError !== "") {
                    root.verify(
                        PersonalizationConfig
                            .desktopWallpaperBackend
                            === "quickshell",
                        "failed activation did not restore config");
                    root.verify(
                        AwwwWallpaperService
                            .quickshellSurfaceRequested,
                        "failed activation unloaded Quickshell");
                    stop();
                    root.finish(true, "expected apply failure");
                    return;
                }

                if (root.phase === 1
                        && !root.expectApplyFailure
                        && AwwwWallpaperService.effectiveBackend
                            === "awww"
                        && AwwwWallpaperService.state === "ready") {
                    root.verify(
                        AwwwWallpaperService.daemonRunning,
                        "mock daemon is not running");
                    root.verify(
                        !AwwwWallpaperService
                            .quickshellSurfaceRequested,
                        "Quickshell desktop was not unloaded");
                    PersonalizationConfig
                        .desktopWallpaperBackend = "quickshell";
                    root.phase = 2;
                    return;
                }

                if (root.phase === 2
                        && AwwwWallpaperService.effectiveBackend
                            === "quickshell"
                        && AwwwWallpaperService.state === "ready"
                        && !AwwwWallpaperService.daemonRunning) {
                    root.verify(
                        AwwwWallpaperService
                            .quickshellSurfaceRequested,
                        "Quickshell desktop was not reloaded");
                    root.verify(
                        AwwwWallpaperService.lastError === "",
                        "normal daemon shutdown was reported as an error");
                    PersonalizationConfig
                        .desktopWallpaperBackend = "awww";
                    root.phase = 3;
                    return;
                }

                if (root.phase === 3
                        && AwwwWallpaperService.effectiveBackend
                            === "awww"
                        && AwwwWallpaperService.state === "ready") {
                    root.verify(
                        !AwwwWallpaperService
                            .quickshellSurfaceRequested,
                        "second awww activation kept Quickshell loaded");
                    PersonalizationConfig
                        .desktopWallpaperBackend = "quickshell";
                    root.phase = 4;
                    return;
                }

                if (root.phase === 4
                        && AwwwWallpaperService.effectiveBackend
                            === "quickshell"
                        && AwwwWallpaperService.state === "ready"
                        && !AwwwWallpaperService.daemonRunning) {
                    root.verify(
                        AwwwWallpaperService.lastError === "",
                        "repeated hot switch left a daemon error");
                    stop();
                    root.finish(true, "");
                }
            } catch (error) {
                stop();
                root.finish(false, error);
            }
        }
    }

    Timer {
        interval: 10000
        repeat: false
        running: true
        onTriggered: {
            root.finish(false,
                "timeout phase=" + root.phase
                    + " requested="
                    + AwwwWallpaperService.requestedBackend
                    + " effective="
                    + AwwwWallpaperService.effectiveBackend
                    + " state=" + AwwwWallpaperService.state
                    + " daemon="
                    + AwwwWallpaperService.daemonRunning
                    + " error="
                    + AwwwWallpaperService.lastError);
        }
    }
}
