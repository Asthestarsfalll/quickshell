import QtQuick 2.15
import QtTest 1.3
import "../../Common/functions/AwwwCommand.js" as AwwwCommand
import "../../Common/functions/WallpaperMath.js" as WallpaperMath

TestCase {
    name: "WallpaperMathAndAwwwCommand"

    function transitionCommand(type, overrides) {
        const settings = {
            type: type,
            fps: 60,
            step: 90,
            durationMs: 1200,
            bezierCurve: [0.22, 1, 0.36, 1, 1, 1],
            angle: 45,
            position: "center",
            wave: "20,20"
        };
        const extra = overrides || {};
        for (let key in extra)
            settings[key] = extra[key];
        return AwwwCommand.apply(
            "mock-awww", "clavis-desktop", "eDP-1",
            "/tmp/a.png", "Fill", settings);
    }

    function verifyContains(command, argument) {
        verify(command.indexOf(argument) !== -1,
            "missing argument " + argument + " in "
                + JSON.stringify(command));
    }

    function verifyOmits(command, argument) {
        verify(command.indexOf(argument) === -1,
            "unexpected argument " + argument + " in "
                + JSON.stringify(command));
    }

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
                step: 90,
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
        compare(command[command.indexOf("--transition-step") + 1],
            "90");
        compare(command[command.indexOf("--transition-bezier") + 1],
            "0.1,0.2,0.3,0.4");
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

    function test_awwwTransitionCapabilities() {
        verify(!AwwwCommand.supportsDuration("none"));
        verify(!AwwwCommand.supportsDuration("simple"));
        verify(AwwwCommand.supportsDuration("fade"));
        verify(AwwwCommand.supportsDuration("grow"));
        verify(!AwwwCommand.supportsBezier("none"));
        verify(!AwwwCommand.supportsBezier("simple"));
        verify(AwwwCommand.supportsBezier("wipe"));
        verify(AwwwCommand.supportsBezier("random"));
        verify(!AwwwCommand.supportsStep("none"));
        verify(AwwwCommand.supportsStep("simple"));
        verify(AwwwCommand.supportsStep("outer"));
    }

    function test_awwwNoneArguments() {
        const command = transitionCommand("none");
        verifyOmits(command, "--transition-fps");
        verifyOmits(command, "--transition-step");
        verifyOmits(command, "--transition-duration");
        verifyOmits(command, "--transition-bezier");
    }

    function test_awwwSimpleArguments() {
        const command = transitionCommand("simple");
        verifyContains(command, "--transition-fps");
        verifyContains(command, "--transition-step");
        verifyOmits(command, "--transition-duration");
        verifyOmits(command, "--transition-bezier");
    }

    function test_awwwFadeArguments() {
        const command = transitionCommand("fade");
        verifyContains(command, "--transition-fps");
        verifyContains(command, "--transition-step");
        verifyContains(command, "--transition-duration");
        verifyContains(command, "--transition-bezier");
    }

    function test_awwwGrowArguments() {
        const command = transitionCommand("grow", {
            position: "bottom-right"
        });
        verifyContains(command, "--transition-step");
        verifyContains(command, "--transition-duration");
        verifyContains(command, "--transition-bezier");
        verifyContains(command, "--transition-pos");
        compare(command[command.indexOf("--transition-pos") + 1],
            "bottom-right");
    }

    function test_awwwWipeArguments() {
        const command = transitionCommand("wipe");
        verifyContains(command, "--transition-step");
        verifyContains(command, "--transition-duration");
        verifyContains(command, "--transition-bezier");
        verifyContains(command, "--transition-angle");
    }

    function test_awwwWaveArgumentsAndClamps() {
        const wave = transitionCommand("wave", {
            fps: 999,
            step: 999,
            durationMs: 999999,
            angle: -20,
            wave: "30,10"
        });
        compare(wave[wave.indexOf("--transition-fps") + 1], "240");
        compare(wave[wave.indexOf("--transition-step") + 1], "255");
        compare(
            wave[wave.indexOf("--transition-duration") + 1],
            "60.000");
        verifyContains(wave, "--transition-bezier");
        compare(
            wave[wave.indexOf("--transition-angle") + 1], "0");
        compare(
            wave[wave.indexOf("--transition-wave") + 1], "30,10");
    }

    function test_awwwOuterAndRandomArguments() {
        const types = ["outer", "random"];
        for (let index = 0; index < types.length; index += 1) {
            const command = transitionCommand(types[index]);
            verifyContains(command, "--transition-step");
            verifyContains(command, "--transition-duration");
            verifyContains(command, "--transition-bezier");
        }
        verifyContains(transitionCommand("outer"),
            "--transition-pos");
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
