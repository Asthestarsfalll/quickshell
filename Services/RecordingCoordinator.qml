pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // The coordinator only describes Clavis-owned recording sessions.
    readonly property bool ownScreenSessionPresent: RecordingService.isActive
    readonly property bool ownAudioSessionPresent: AudioRecordingService.isActive
    readonly property bool ownSessionPresent: ownScreenSessionPresent
        || ownAudioSessionPresent
    readonly property bool ownRecordingActive: RecordingService.isRecording
        || AudioRecordingService.isRecording
    readonly property bool capturePresent: ownSessionPresent
    readonly property bool captureActive: ownRecordingActive
    readonly property string source: ownScreenSessionPresent
        ? "clavis-screen"
        : (ownAudioSessionPresent ? "clavis-audio" : "none")
    readonly property string state: ownScreenSessionPresent
        ? RecordingService.state
        : (ownAudioSessionPresent ? AudioRecordingService.state : "idle")
    readonly property var ownScreenStatusTexts: ({
        "selecting": qsTr("正在选择录制区域"),
        "starting": qsTr("正在启动录制"),
        "recording": qsTr("正在录制"),
        "finalizing": qsTr("正在处理录制文件")
    })
    readonly property var ownAudioStatusTexts: ({
        "starting": qsTr("正在启动录音"),
        "recording": qsTr("正在录音"),
        "stopping": qsTr("正在停止录音"),
        "finalizing": qsTr("正在完成录音文件")
    })
    readonly property string statusText: ownScreenSessionPresent
        ? (ownScreenStatusTexts[RecordingService.state] || "")
        : (ownAudioSessionPresent
            ? (ownAudioStatusTexts[AudioRecordingService.state] || "")
            : "")
    readonly property bool canStop: RecordingService.isRecording
        || RecordingService.isFinalizing
        || AudioRecordingService.isRecording
}
