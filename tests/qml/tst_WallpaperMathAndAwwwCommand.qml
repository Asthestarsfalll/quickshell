import QtQuick 2.15
import QtTest 1.3
import "../../Common/functions/AwwwCommand.js" as AwwwCommand
import "../../Common/functions/WallpaperMath.js" as WallpaperMath

TestCase {
    name: "WallpaperMathAndAwwwCommand"

    function test_coverScaleAndOverflow() {
        const geometry = WallpaperMath.coverGeometry(
            1920, 1080, 1920, 1080, 1.10);
        compare(geometry.coverScale, 1);
        compare(Math.round(geometry.scaledWidth), 2112);
        compare(Math.round(geometry.scaledHeight), 1188);
        compare(Math.round(geometry.overflowX), 192);
        compare(Math.round(geometry.overflowY), 108);
    }

    function test_tiledColumnProgress() {
        compare(WallpaperMath.tiledColumnProgress(0, 6), 0.5);
        compare(WallpaperMath.tiledColumnProgress(1, 6), 0);
        compare(WallpaperMath.tiledColumnProgress(2, 6), 0.2);
        compare(WallpaperMath.tiledColumnProgress(6, 6), 1);
        compare(WallpaperMath.tiledColumnProgress(12, 6), 1);
    }

    function test_workspaceProgressIsPerOutputList() {
        compare(WallpaperMath.workspaceProgress([
            { isActive: true }
        ]), 0.5);
        compare(WallpaperMath.workspaceProgress([
            { isActive: true },
            { isActive: false },
            { isActive: false }
        ]), 0);
        compare(WallpaperMath.workspaceProgress([
            { isActive: false },
            { isActive: false },
            { isActive: true }
        ]), 1);
    }

    function test_sidebarDirectionsAndCancellation() {
        const overflow = 200;
        const base = WallpaperMath.horizontalProgress(
            0.5, false, false, 0.1);
        const left = WallpaperMath.horizontalProgress(
            0.5, true, false, 0.1);
        const right = WallpaperMath.horizontalProgress(
            0.5, false, true, 0.1);
        const both = WallpaperMath.horizontalProgress(
            0.5, true, true, 0.1);

        verify(WallpaperMath.wallpaperPosition(overflow, left)
            > WallpaperMath.wallpaperPosition(overflow, base));
        verify(WallpaperMath.wallpaperPosition(overflow, right)
            < WallpaperMath.wallpaperPosition(overflow, base));
        compare(both, base);
    }

    function test_awwwNamespaceLifecycleCommands() {
        compare(JSON.stringify(AwwwCommand.daemon(
            "mock-daemon", "clavis-desktop")), JSON.stringify([
            "mock-daemon", "--layer", "bottom",
            "--namespace", "clavis-desktop", "--no-cache"
        ]));
        compare(JSON.stringify(AwwwCommand.query(
            "mock-awww", "clavis-desktop")), JSON.stringify([
            "mock-awww", "query", "-n", "clavis-desktop"
        ]));
        compare(JSON.stringify(AwwwCommand.stop(
            "mock-awww", "clavis-desktop")), JSON.stringify([
            "mock-awww", "kill", "-n", "clavis-desktop"
        ]));
    }

    function test_awwwImageArgumentsAreArraySafe() {
        const path = "/tmp/wallpaper with spaces;$(touch nope).png";
        const command = AwwwCommand.apply(
            "mock-awww", "clavis-desktop", "DP-1", path, "Fill", {
                type: "wipe",
                fps: 60,
                durationMs: 1250,
                bezierCurve: [0.1, 0.2, 0.3, 0.4, 1, 1],
                angle: 90,
                position: "center",
                wave: "20,20"
            });

        compare(command[0], "mock-awww");
        compare(command[1], "img");
        compare(command[command.length - 1], path);
        compare(command[command.indexOf("-n") + 1],
            "clavis-desktop");
        compare(command[command.indexOf("-o") + 1], "DP-1");
        compare(command[command.indexOf("--transition-angle") + 1],
            "90");
        compare(command[command.indexOf("--transition-duration") + 1],
            "1.250");
        verify(command.indexOf("portal") === -1);
    }

    function test_awwwPureColorUsesClear() {
        const command = AwwwCommand.apply(
            "mock-awww", "clavis-desktop", "HDMI-A-1",
            "#aabbccdd", "Fill", {});
        compare(JSON.stringify(command), JSON.stringify([
            "mock-awww", "clear", "-n", "clavis-desktop",
            "-o", "HDMI-A-1", "aabbccdd"
        ]));
    }

    function test_awwwBezierUsesFourControls() {
        const command = AwwwCommand.apply(
            "mock-awww", "clavis-desktop", "DP-1",
            "/tmp/a.png", "Fill", {
                type: "fade",
                fps: 60,
                durationMs: 1000,
                bezierCurve: [0.43, 1.19, 1, 0.4, 1, 1]
            });
        compare(
            command[command.indexOf("--transition-bezier") + 1],
            "0.43,1.19,1,0.4");

        const clamped = AwwwCommand.apply(
            "mock-awww", "clavis-desktop", "DP-1",
            "/tmp/a.png", "Fill", {
                type: "fade",
                bezierCurve: [-1, 99, 2, -99, 1, 1]
            });
        compare(
            clamped[clamped.indexOf("--transition-bezier") + 1],
            "0,4,1,-4");
    }

    function test_awwwTransitionSpecificArgumentsAndClamps() {
        const wave = AwwwCommand.apply(
            "mock-awww", "clavis-desktop", "DP-1",
            "/tmp/a.png", "Fill", {
                type: "wave",
                fps: 999,
                durationMs: 999999,
                angle: -20,
                wave: "30,10"
            });
        compare(wave[wave.indexOf("--transition-fps") + 1], "240");
        compare(
            wave[wave.indexOf("--transition-duration") + 1],
            "60.000");
        compare(
            wave[wave.indexOf("--transition-angle") + 1], "0");
        compare(
            wave[wave.indexOf("--transition-wave") + 1], "30,10");

        const grow = AwwwCommand.apply(
            "mock-awww", "clavis-desktop", "DP-1",
            "/tmp/a.png", "Fill", {
                type: "grow",
                fps: 1,
                durationMs: 500,
                position: "bottom-right"
            });
        compare(grow[grow.indexOf("--transition-fps") + 1], "10");
        compare(
            grow[grow.indexOf("--transition-pos") + 1],
            "bottom-right");

        const simple = AwwwCommand.apply(
            "mock-awww", "clavis-desktop", "DP-1",
            "/tmp/a.png", "Fill", {
                type: "simple",
                fps: 60,
                durationMs: 1000
            });
        verify(simple.indexOf("--transition-duration") === -1);
        verify(simple.indexOf("--transition-bezier") === -1);
    }

    function test_awwwRejectsDmsOnlyTransitionNames() {
        const command = AwwwCommand.apply(
            "mock-awww", "clavis-desktop", "DP-1",
            "/tmp/a.png", "Fill", {
                type: "portal",
                fps: 60,
                durationMs: 1000
            });
        compare(
            command[command.indexOf("--transition-type") + 1],
            "fade");
        verify(command.indexOf("portal") === -1);
    }
}
