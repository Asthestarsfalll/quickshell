import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services

Item {
    id: backendRoot
    
    function pickColor() { colorPickerProcess.running = false; colorPickerProcess.running = true }
    function takeScreenshot() {
        return RegionSelectionService.begin("screenshot", {})
    }

    function startRecord(mode) {
        RecordingService.start(mode, {
            audio: "none",
            fps: 60
        })
    }

    function stopRecord() {
        RecordingService.stop()
    }

    function startAudio(source) {
        return AudioRecordingService.start(source)
    }

    function stopAudio() {
        return AudioRecordingService.stop()
    }

    Connections {
        target: RegionSelectionService

        function onSelectionAccepted(action, geometry, options) {
            if (action !== "screenshot")
                return

            screenshotProcess.command = [
                "bash",
                Paths.scriptPath("capture", "screenshot_to_clipboard.sh"),
                geometry
            ]
            screenshotProcess.running = true
        }
    }

    Process { id: colorPickerProcess; command: ["hyprpicker", "-a"] }
    Process { id: screenshotProcess }
}
