import QtQuick 2.15
import QtTest 1.3
import "../../Common/functions/RuntimeCompatibility.js" as RuntimeRules

TestCase {
    name: "RuntimeCompatibility"

    readonly property var requiredProtocols: ({
        "core": 1,
        "clipboard": 2,
        "sysmon": 1
    })
    readonly property var clipboardFeatures: [
        "clipboard.inspect",
        "clipboard.mime-restore",
        "clipboard.mime-aware-store"
    ]

    function handshake(release, protocols, features) {
        return {
            "product": "clavis-key",
            "release": release,
            "commit": "abc123",
            "protocols": protocols || {
                "core": 1, "clipboard": 2, "sysmon": 1
            },
            "features": features || clipboardFeatures.concat([
                "sysmon.rapl-status"
            ])
        };
    }

    function evaluate(response, expectedRelease, pluginRelease) {
        return RuntimeRules.evaluate(
            response,
            expectedRelease || "2026.07.31",
            "abc123",
            pluginRelease || "2026.07.31",
            "abc123",
            requiredProtocols,
            clipboardFeatures);
    }

    function test_sameReleaseIsFullyCompatible() {
        const result = evaluate(handshake("2026.07.31"));
        verify(result.keyAvailable);
        verify(result.coreCompatible);
        verify(result.clipboardCompatible);
        verify(result.sysmonCompatible);
        compare(result.errorCode, "");
        compare(result.warningCode, "");
    }

    function test_differentDateWithCompatibleProtocolsOnlyWarns() {
        const result = evaluate(handshake("2026.08.01"));
        verify(result.coreCompatible);
        verify(result.clipboardCompatible);
        compare(result.errorCode, "");
        compare(result.warningCode, "release_mismatch");
    }

    function test_clipboardProtocolMismatchDisablesOnlyClipboard() {
        const result = evaluate(handshake(
            "2026.07.31", { "core": 1, "clipboard": 1, "sysmon": 1 }));
        verify(result.coreCompatible);
        verify(!result.clipboardCompatible);
        verify(result.sysmonCompatible);
        compare(result.errorCode, "");
    }

    function test_missingOptionalCapabilityDegradesWithoutDisablingSysmon() {
        const result = evaluate(handshake(
            "2026.07.31", undefined, clipboardFeatures));
        verify(result.coreCompatible);
        verify(result.clipboardCompatible);
        verify(result.sysmonCompatible);
        verify(!RuntimeRules.hasFeature(
            true, clipboardFeatures, "sysmon.rapl-status"));
    }

    function test_missingRequiredClipboardFeatureDisablesClipboard() {
        const result = evaluate(handshake("2026.07.31", undefined, [
            "clipboard.inspect", "clipboard.mime-restore"
        ]));
        verify(result.coreCompatible);
        verify(!result.clipboardCompatible);
        verify(result.sysmonCompatible);
    }

    function test_nativePluginMismatchIsFatalForBackendModules() {
        const result = evaluate(
            handshake("2026.07.31"), "2026.07.31", "2026.07.30");
        verify(!result.coreCompatible);
        verify(!result.clipboardCompatible);
        verify(!result.sysmonCompatible);
        compare(result.errorCode, "native_plugin_release_mismatch");
    }

    function test_missingOrInvalidKeyHandshakeFailsClosed() {
        const result = evaluate(null);
        verify(!result.keyAvailable);
        verify(!result.coreCompatible);
        compare(result.errorCode, "invalid_version_handshake");
    }

    function test_ipcCommandAlwaysUsesStableKey() {
        compare(
            RuntimeRules.ipcCommand(
                "/home/test/.local/bin/key", "wallpaper",
                ["setFolder", "/home/test/Pictures"]),
            [
                "/home/test/.local/bin/key", "ipc", "call",
                "wallpaper", "setFolder", "/home/test/Pictures"
            ]
        );
    }
}
