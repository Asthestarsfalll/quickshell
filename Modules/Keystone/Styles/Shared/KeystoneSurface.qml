import QtQuick
import Qt5Compat.GraphicalEffects 
import Quickshell
import Quickshell.Io  
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import qs.Services
import qs.Common
import qs.Widgets.common

import qs.Modules.Keystone.ClockContent
import qs.Modules.Keystone.MediaContent  
import qs.Modules.Keystone.NotificationContent
import qs.Modules.Keystone.VolumeContent
import qs.Modules.Keystone.LyricsContent 
import qs.Modules.Keystone.Hub
import qs.Modules.Keystone.Tools
import qs.Modules.Keystone.Styles.Recording

Variants {
    id: styleSurface

    signal avatarEditRequested(var screen)

    property bool detached: false
    property int edgeMargin: 0
    property int maxPillRadius: 24
    property bool showAttachedEdgeCurves: !detached

    function invoke(methodName) {
        if (instances.length === 0)
            return "KEYSTONE_UNAVAILABLE";

        const instance = instances[0];
        if (!instance || typeof instance[methodName] !== "function")
            return "KEYSTONE_UNAVAILABLE";
        return instance[methodName]();
    }

    function cancelRecord(): string {
        return invoke("cancelRecord");
    }

    function closeAllOthers(): string {
        return invoke("closeAllOthers");
    }

    function hub(): string {
        return invoke("hub");
    }

    function dashboard(): string {
        return invoke("dashboard");
    }

    function tools(): string {
        return invoke("tools");
    }

    model: Quickshell.screens

    PanelWindow {
        id: keystoneWindow
        required property var modelData
        screen: modelData

        readonly property string edge: PersonalizationConfig.keystonePosition
        readonly property bool horizontalEdge: edge === "top" || edge === "bottom"
        readonly property bool topEdge: edge === "top"
        readonly property bool bottomEdge: edge === "bottom"
        readonly property bool leftEdge: edge === "left"
        readonly property bool rightEdge: edge === "right"

        property int edgeCurveAlong: styleSurface.showAttachedEdgeCurves ? 8 : 0
        property int edgeCurveDepth: styleSurface.showAttachedEdgeCurves ? 14 : 0
        property real edgeCurveSideControl: 0.58
        property real edgeCurveOuterControl: 0.42

        function cancelRecord(): string {
            RecordingService.refresh();
            return "RECORD_CANCELLED";
        }

        function closeAllOthers(): string {
            root.showLyrics = false;
            root.showTools = false;
            root.expanded = false;
            return "OTHERS_CLOSED";
        }

        function hub(): string {
            if (root.showHub) {
                root.showHub = false;
                return "HUB_CLOSED";
            }

            closeAllOthers();
            root.showHub = true;
            return "HUB_OPENED";
        }

        function dashboard(): string {
            if (root.showHub && root.hubTabIndex === 0) {
                root.showHub = false;
                return "DASHBOARD_CLOSED";
            }
            closeAllOthers();
            root.hubTabIndex = 0;
            root.showHub = true;
            return "DASHBOARD_OPENED";
        }

        function tools(): string {
            if (root.showTools) {
                root.showTools = false;
                return "TOOLS_CLOSED";
            }

            closeAllOthers();
            root.showHub = false;
            root.showTools = true;
            return "TOOLS_OPENED";
        }

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        margins { top: 0 }
        
        color: "transparent"
        exclusiveZone: -1
        WlrLayershell.namespace: "clavis-shell-keystone"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        WlrLayershell.keyboardFocus: root.hasClosablePopup
            ? WlrKeyboardFocus.Exclusive 
            : WlrKeyboardFocus.None

        // ============================================================
        // 【物理挖孔层 (Mask Region)】 
        // ============================================================
        Item {
            id: hitBoxRegion
            anchors.top: maskContainer.top
            anchors.bottom: maskContainer.bottom
            anchors.left: maskContainer.left
            width: maskContainer.width
                + (styleSurface.detached
                    ? pillRecordingVisual.interactiveRightExtent
                    : 0)

            state: keystoneWindow.rightEdge ? "right" : "default"
            states: [
                State {
                    name: "default"
                    AnchorChanges {
                        target: hitBoxRegion
                        anchors.left: maskContainer.left
                        anchors.right: undefined
                    }
                },
                State {
                    name: "right"
                    AnchorChanges {
                        target: hitBoxRegion
                        anchors.left: undefined
                        anchors.right: maskContainer.right
                    }
                }
            ]
        }

        mask: Region {
            item: hitBoxRegion
        }

        // ============================================================
        // 【阴影源 (Shadow Source)】 
        // ============================================================
        Item {
            id: shadowSource
            anchors.fill: maskContainer
            visible: false 

            AttachedEdgeCurve {
                id: shadowLeftTopCurve
                visible: styleSurface.showAttachedEdgeCurves
                edge: keystoneWindow.edge
                after: false
                along: keystoneWindow.edgeCurveAlong
                depth: keystoneWindow.edgeCurveDepth
                sideControl: keystoneWindow.edgeCurveSideControl
                edgeControl: keystoneWindow.edgeCurveOuterControl
                fillColor: "black"
                anchors {
                    right: keystoneWindow.horizontalEdge ? rootShadow.left
                        : keystoneWindow.rightEdge ? rootShadow.right : undefined
                    left: keystoneWindow.leftEdge ? rootShadow.left : undefined
                    bottom: !keystoneWindow.horizontalEdge ? rootShadow.top
                        : keystoneWindow.bottomEdge ? rootShadow.bottom : undefined
                    top: keystoneWindow.topEdge ? rootShadow.top : undefined
                }
            }

            Item {
                id: rootShadow
                width: root.width
                height: root.height
                state: keystoneWindow.edge
                states: [
                    State { name: "top"; AnchorChanges { target: rootShadow; anchors.top: shadowSource.top; anchors.bottom: undefined; anchors.left: undefined; anchors.right: undefined; anchors.horizontalCenter: shadowSource.horizontalCenter; anchors.verticalCenter: undefined } },
                    State { name: "bottom"; AnchorChanges { target: rootShadow; anchors.top: undefined; anchors.bottom: shadowSource.bottom; anchors.left: undefined; anchors.right: undefined; anchors.horizontalCenter: shadowSource.horizontalCenter; anchors.verticalCenter: undefined } },
                    State { name: "left"; AnchorChanges { target: rootShadow; anchors.top: undefined; anchors.bottom: undefined; anchors.left: shadowSource.left; anchors.right: undefined; anchors.horizontalCenter: undefined; anchors.verticalCenter: shadowSource.verticalCenter } },
                    State { name: "right"; AnchorChanges { target: rootShadow; anchors.top: undefined; anchors.bottom: undefined; anchors.left: undefined; anchors.right: shadowSource.right; anchors.horizontalCenter: undefined; anchors.verticalCenter: shadowSource.verticalCenter } }
                ]
                
                Rectangle {
                    id: solidShadowBg
                    anchors.fill: parent
                    topLeftRadius: styleSurface.detached || (!keystoneWindow.topEdge && !keystoneWindow.leftEdge) ? root.radius : 0
                    topRightRadius: styleSurface.detached || (!keystoneWindow.topEdge && !keystoneWindow.rightEdge) ? root.radius : 0
                    bottomLeftRadius: styleSurface.detached || (!keystoneWindow.bottomEdge && !keystoneWindow.leftEdge) ? root.radius : 0
                    bottomRightRadius: styleSurface.detached || (!keystoneWindow.bottomEdge && !keystoneWindow.rightEdge) ? root.radius : 0
                    color: "black"
                    visible: false
                }

                Item {
                    id: shadowHoleWrapper
                    anchors.fill: parent
                    visible: false
                    Rectangle {
                        // 【宽度 340，左移至 18 完美对齐右侧卡片】
                        width: 340
                        height: 456
                        anchors.left: parent.horizontalCenter
                        anchors.leftMargin: 48
                        anchors.top: parent.top
                        anchors.topMargin: 132
                        radius: 24
                        color: root.showDashboardHole ? "black" : "transparent"
                    }
                }

                OpacityMask {
                    anchors.fill: parent
                    source: solidShadowBg
                    maskSource: shadowHoleWrapper
                    invert: true
                }
            }

            AttachedEdgeCurve {
                id: shadowRightTopCurve
                visible: styleSurface.showAttachedEdgeCurves
                edge: keystoneWindow.edge
                after: true
                along: keystoneWindow.edgeCurveAlong
                depth: keystoneWindow.edgeCurveDepth
                sideControl: keystoneWindow.edgeCurveSideControl
                edgeControl: keystoneWindow.edgeCurveOuterControl
                fillColor: "black"
                anchors {
                    left: keystoneWindow.leftEdge ? rootShadow.left
                        : (keystoneWindow.horizontalEdge ? rootShadow.right : undefined)
                    right: keystoneWindow.rightEdge ? rootShadow.right : undefined
                    top: keystoneWindow.topEdge ? rootShadow.top
                        : (!keystoneWindow.horizontalEdge ? rootShadow.bottom : undefined)
                    bottom: keystoneWindow.bottomEdge ? rootShadow.bottom : undefined
                }
            }
        }

        DropShadow {
            anchors.fill: shadowSource
            source: shadowSource
            horizontalOffset: keystoneWindow.leftEdge ? 6 : keystoneWindow.rightEdge ? -6 : 0
            verticalOffset: keystoneWindow.topEdge ? 6 : keystoneWindow.bottomEdge ? -6 : 0
            radius: 20
            samples: 32
            color: "#80000000" 
            cached: true
            opacity: root.color.a
                * (styleSurface.detached
                    && root.recordingPresentationActive ? 0 : 1)
        }

        // ============================================================
        // 【视觉 Keystone bangs 本体】 
        // ============================================================
        Item {
            id: maskContainer
            anchors.topMargin: keystoneWindow.topEdge ? styleSurface.edgeMargin : 0
            anchors.bottomMargin: keystoneWindow.bottomEdge ? styleSurface.edgeMargin : 0
            anchors.leftMargin: keystoneWindow.leftEdge ? styleSurface.edgeMargin : 0
            anchors.rightMargin: keystoneWindow.rightEdge ? styleSurface.edgeMargin : 0
            anchors.horizontalCenterOffset: styleSurface.detached
                && keystoneWindow.horizontalEdge && root.recordingPresentationActive
                ? -0.15 * Math.max(0, root.width - root.collapsedW)
                : 0
            width: root.width + (keystoneWindow.horizontalEdge
                ? keystoneWindow.edgeCurveAlong * 2 : 0)
            height: root.height + (!keystoneWindow.horizontalEdge
                ? keystoneWindow.edgeCurveAlong * 2 : 0)
            state: keystoneWindow.edge
            states: [
                State { name: "top"; AnchorChanges { target: maskContainer; anchors.top: keystoneWindow.contentItem.top; anchors.bottom: undefined; anchors.left: undefined; anchors.right: undefined; anchors.horizontalCenter: keystoneWindow.contentItem.horizontalCenter; anchors.verticalCenter: undefined } },
                State { name: "bottom"; AnchorChanges { target: maskContainer; anchors.top: undefined; anchors.bottom: keystoneWindow.contentItem.bottom; anchors.left: undefined; anchors.right: undefined; anchors.horizontalCenter: keystoneWindow.contentItem.horizontalCenter; anchors.verticalCenter: undefined } },
                State { name: "left"; AnchorChanges { target: maskContainer; anchors.top: undefined; anchors.bottom: undefined; anchors.left: keystoneWindow.contentItem.left; anchors.right: undefined; anchors.horizontalCenter: undefined; anchors.verticalCenter: keystoneWindow.contentItem.verticalCenter } },
                State { name: "right"; AnchorChanges { target: maskContainer; anchors.top: undefined; anchors.bottom: undefined; anchors.left: undefined; anchors.right: keystoneWindow.contentItem.right; anchors.horizontalCenter: undefined; anchors.verticalCenter: keystoneWindow.contentItem.verticalCenter } }
            ]

            AttachedEdgeCurve {
                id: leftTopCurve
                visible: styleSurface.showAttachedEdgeCurves
                edge: keystoneWindow.edge
                after: false
                along: keystoneWindow.edgeCurveAlong
                depth: keystoneWindow.edgeCurveDepth
                sideControl: keystoneWindow.edgeCurveSideControl
                edgeControl: keystoneWindow.edgeCurveOuterControl
                fillColor: root.color
                anchors {
                    right: keystoneWindow.horizontalEdge ? root.left
                        : keystoneWindow.rightEdge ? root.right : undefined
                    left: keystoneWindow.leftEdge ? root.left : undefined
                    bottom: !keystoneWindow.horizontalEdge ? root.top
                        : keystoneWindow.bottomEdge ? root.bottom : undefined
                    top: keystoneWindow.topEdge ? root.top : undefined
                }
                Connections {
                    target: root
                    function onColorChanged() {
                        leftTopCurve.requestPaint();
                    }
                }
            }

            Item {
                id: root
                state: keystoneWindow.edge
                states: [
                    State { name: "top"; AnchorChanges { target: root; anchors.top: maskContainer.top; anchors.bottom: undefined; anchors.left: undefined; anchors.right: undefined; anchors.horizontalCenter: maskContainer.horizontalCenter; anchors.verticalCenter: undefined } },
                    State { name: "bottom"; AnchorChanges { target: root; anchors.top: undefined; anchors.bottom: maskContainer.bottom; anchors.left: undefined; anchors.right: undefined; anchors.horizontalCenter: maskContainer.horizontalCenter; anchors.verticalCenter: undefined } },
                    State { name: "left"; AnchorChanges { target: root; anchors.top: undefined; anchors.bottom: undefined; anchors.left: maskContainer.left; anchors.right: undefined; anchors.horizontalCenter: undefined; anchors.verticalCenter: maskContainer.verticalCenter } },
                    State { name: "right"; AnchorChanges { target: root; anchors.top: undefined; anchors.bottom: undefined; anchors.left: undefined; anchors.right: maskContainer.right; anchors.horizontalCenter: undefined; anchors.verticalCenter: maskContainer.verticalCenter } }
                ]

                property bool showLyrics: false 
                property bool expanded: false
                property bool showVolume: false
                property bool showHub: false
                property bool showTools: false 
                property int hubTabIndex: 0
                property bool componentReady: false
                property bool pillStopFusionMinimumActive: false
                readonly property bool backendFinalizing: RecordingService.isFinalizing
                readonly property bool stopPresentationActive: RecordingService.isStopPending
                    || (styleSurface.detached && pillStopFusionMinimumActive)
                readonly property bool isRecording: RecordingService.isRecording
                    && !stopPresentationActive
                readonly property bool isFinalizing: backendFinalizing
                    || stopPresentationActive
                readonly property bool isRecordingMode: isRecording || isFinalizing
                property bool recordingExitActive: false
                readonly property bool recordingPresentationActive: isRecordingMode
                    || recordingExitActive
                    || recordingInfoProgress > 0.01
                    || recordingActionProgress > 0.01
                    || processingContentProgress > 0.01

                readonly property int audioPhaseHidden: 0
                readonly property int audioPhaseExpanded: 1
                readonly property int audioPhaseCollapsing: 2
                property int audioPresentationPhase: audioPhaseHidden
                readonly property bool audioSessionActive: AudioRecordingService.isActive
                readonly property bool audioPresentationActive: audioSessionActive
                    || audioPresentationPhase !== audioPhaseHidden
                readonly property bool audioGeometryActive: audioSessionActive
                    || audioPresentationPhase === audioPhaseExpanded
                readonly property bool contentPresentationActive:
                    recordingPresentationActive || audioPresentationActive

                property bool isLyricsMode: showLyrics && !contentPresentationActive
                property bool isToolsMode: !contentPresentationActive && showTools && !isLyricsMode
                property bool isHubMode: !contentPresentationActive && showHub && !isToolsMode && !isLyricsMode
                property bool isVolumeMode: !contentPresentationActive && showVolume && !expanded && !isHubMode && !isToolsMode && !isLyricsMode
                property bool isNotifMode: !contentPresentationActive && NotificationManager.hasNotifs && !expanded && !showVolume && !isHubMode && !isToolsMode && !isLyricsMode
                property bool isCollapsedMode: !contentPresentationActive && !expanded && !isNotifMode && !isVolumeMode && !isLyricsMode && !isHubMode && !isToolsMode
                property bool isCollapsedHovered: isCollapsedMode && (keystoneMouseArea.containsMouse || collapsedInputArea.containsMouse)
                property bool hasClosablePopup: !contentPresentationActive
                    && (expanded || isLyricsMode || isHubMode || isToolsMode)
                
                property bool showDashboardHole: isHubMode && hubTabIndex === 0

                property int lyricsW: lyricsWidget.implicitWidth; property int lyricsH: 42 
                property int expandedW: 540; property int expandedH: 210
                property int collapsedW: 220; property int collapsedH: 42
                property int recordingBangsW: 220
                property real pillMorphProgress: 0
                property real recordingInfoProgress: 0
                property real recordingActionProgress: 0
                property real processingContentProgress: 0
                readonly property int pillEntryDuration: 1000
                readonly property int pillFusionDuration: 820
                property int pillActiveFusionDuration: pillFusionDuration
                property int toolsW: 480; property int toolsH: 72
                property int notifW: 380; property int notifH: (NotificationManager.popupList.length * 70) + 20
                property int volW: 320; property int volH: 64
                property int audioW: KeystoneMotion.audioRecordingWidth
                property int audioH: KeystoneMotion.audioRecordingHeight
                
                property color color: BlurService.backgroundColor(
                    Appearance.colors.colLayer0)
                clip: true
                z: 100

                readonly property bool sideCompactLayout:
                    !keystoneWindow.horizontalEdge
                    && (isCollapsedMode || isToolsMode || isVolumeMode)

                property real logicalTargetW: recordingPresentationActive
                    ? (styleSurface.detached
                        ? pillRecordingVisual.mainLayoutWidth
                        : recordingBangsW) :
                    audioGeometryActive ? audioW :
                    isToolsMode ? toolsW :
                    isHubMode ? hub.implicitWidth : 
                    isLyricsMode ? lyricsW : 
                    expanded ? expandedW : 
                    isVolumeMode ? volW : 
                    isNotifMode ? notifW : 
                    (collapsedW + (isCollapsedHovered ? 16 : 0))

                property int logicalTargetH: recordingPresentationActive
                    ? collapsedH :
                        audioGeometryActive ? audioH :
                        isToolsMode ? toolsH : 
                        isHubMode ? hub.implicitHeight : 
                        isLyricsMode ? lyricsH : 
                        expanded ? expandedH : 
                        isVolumeMode ? volH : 
                        isNotifMode ? notifH : 
                        (collapsedH + (isCollapsedHovered ? 6 : 0))

                // A side collapsed surface swaps its base dimensions, but its
                // dominant hover delta belongs to the cross axis: width grows
                // inward from the anchored left/right edge. The smaller delta
                // remains on the vertical primary axis. Other modes retain
                // their existing geometry.
                property real targetW: !keystoneWindow.horizontalEdge
                        && isCollapsedMode
                    ? collapsedH + (isCollapsedHovered ? 16 : 0)
                    : sideCompactLayout ? logicalTargetH : logicalTargetW
                property int targetH: !keystoneWindow.horizontalEdge
                        && isCollapsedMode
                    ? collapsedW + (isCollapsedHovered ? 6 : 0)
                    : sideCompactLayout ? logicalTargetW : logicalTargetH
                property int targetR: styleSurface.detached
                    ? Math.min(Math.min(targetW, targetH) / 2,
                        styleSurface.maxPillRadius)
                    : 12

                property int wDuration: KeystoneMotion.expandingDuration
                property int hDuration: KeystoneMotion.expandingDuration
                property int rDuration: KeystoneMotion.radiusDuration
                property var wBezier: KeystoneMotion.expandingBezier
                property var hBezier: KeystoneMotion.expandingBezier
                property var rBezier: KeystoneMotion.radiusBezier

                width: targetW
                height: targetH
                property real radius: targetR

                onAudioSessionActiveChanged: {
                    if (root.audioSessionActive) {
                        root.audioPresentationPhase = root.audioPhaseExpanded;
                        root.expanded = false;
                        root.showLyrics = false;
                        root.showVolume = false;
                        root.showHub = false;
                        root.showTools = false;
                        if (root.componentReady)
                            audioRecordingVisual.beginEntry();
                        return;
                    }

                    if (root.audioPresentationPhase === root.audioPhaseExpanded)
                        audioRecordingVisual.beginExit();
                }

                onIsRecordingChanged: {
                    if (!root.isRecording)
                        return;

                    contentResetTimer.stop();
                    recordingPresentationOut.stop();
                    recordingActionOut.stop();
                    pillRecordingInfoOut.stop();
                    bangsRecordingInfoOut.stop();
                    processingContentIn.stop();
                    bangsProcessingContentIn.stop();
                    root.recordingExitActive = false;
                    recordingContentIn.restart();

                    if (styleSurface.detached) {
                        pillGeometryExit.stop();
                        pillGeometryEntry.restart();
                    }
                }

                onIsFinalizingChanged: {
                    if (!root.isFinalizing)
                        return;

                    recordingContentIn.stop();
                    processingContentIn.stop();
                    bangsProcessingContentIn.stop();
                    recordingActionOut.restart();

                    if (styleSurface.detached) {
                        pillGeometryEntry.stop();
                        root.pillActiveFusionDuration = Math.max(
                            220,
                            Math.round(root.pillFusionDuration * root.pillMorphProgress)
                        );
                        pillRecordingInfoOut.restart();
                        pillGeometryExit.restart();
                    } else {
                        bangsRecordingInfoOut.restart();
                        bangsProcessingContentIn.restart();
                    }
                }

                onBackendFinalizingChanged: {
                    if (root.backendFinalizing
                            && (!styleSurface.detached || root.pillMorphProgress <= 0.01)
                            && root.processingContentProgress < 0.99) {
                        if (styleSurface.detached)
                            processingContentIn.restart();
                        else
                            bangsProcessingContentIn.restart();
                    }
                }

                onIsRecordingModeChanged: {
                    if (root.isRecordingMode)
                        return;

                    root.pillStopFusionMinimumActive = false;
                    pillRecordingInfoOut.stop();
                    bangsRecordingInfoOut.stop();
                    processingContentIn.stop();
                    bangsProcessingContentIn.stop();
                    root.recordingExitActive = true;
                    recordingPresentationOut.restart();
                }

                Component.onCompleted: {
                    root.componentReady = true;
                    recordingContentIn.stop();
                    recordingPresentationOut.stop();
                    recordingActionOut.stop();
                    pillRecordingInfoOut.stop();
                    bangsRecordingInfoOut.stop();
                    processingContentIn.stop();
                    bangsProcessingContentIn.stop();
                    pillGeometryEntry.stop();
                    pillGeometryExit.stop();
                    root.recordingExitActive = false;
                    root.pillMorphProgress = styleSurface.detached && root.isRecording
                        ? 1
                        : 0;
                    root.recordingInfoProgress = root.isRecording ? 1 : 0;
                    root.recordingActionProgress = root.isRecording ? 1 : 0;
                    root.processingContentProgress = root.isFinalizing ? 1 : 0;
                    root.audioPresentationPhase = root.audioSessionActive
                        ? root.audioPhaseExpanded
                        : root.audioPhaseHidden;
                    if (root.audioSessionActive)
                        audioRecordingVisual.beginEntry();
                }

                ParallelAnimation {
                    id: recordingContentIn

                    NumberAnimation {
                        target: root
                        property: "processingContentProgress"
                        to: 0
                        duration: Appearance.animation.expressiveFastEffects.duration
                        easing.type: Appearance.animation.expressiveFastEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                    }
                    SequentialAnimation {
                        PauseAnimation {
                            duration: Appearance.animation.expressiveFastEffects.duration
                        }
                        ParallelAnimation {
                            NumberAnimation {
                                target: root
                                property: "recordingInfoProgress"
                                to: 1
                                duration: Appearance.animation.expressiveSlowEffects.duration
                                easing.type: Appearance.animation.expressiveSlowEffects.type
                                easing.bezierCurve: Appearance.animation.expressiveSlowEffects.bezierCurve
                            }
                            NumberAnimation {
                                target: root
                                property: "recordingActionProgress"
                                to: 1
                                duration: Appearance.animation.expressiveSlowEffects.duration
                                easing.type: Appearance.animation.expressiveSlowEffects.type
                                easing.bezierCurve: Appearance.animation.expressiveSlowEffects.bezierCurve
                            }
                        }
                    }
                }

                NumberAnimation {
                    id: pillGeometryEntry

                    target: root
                    property: "pillMorphProgress"
                    to: 1
                    duration: root.pillEntryDuration
                    easing.type: Easing.Linear
                }

                NumberAnimation {
                    id: recordingActionOut

                    target: root
                    property: "recordingActionProgress"
                    to: 0
                    duration: Appearance.animation.expressiveFastEffects.duration
                    easing.type: Appearance.animation.expressiveFastEffects.type
                    easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                }

                SequentialAnimation {
                    id: pillRecordingInfoOut

                    PauseAnimation {
                        duration: Math.max(
                            0,
                            root.pillActiveFusionDuration
                                - Appearance.animation.expressiveSlowEffects.duration
                        )
                    }
                    NumberAnimation {
                        target: root
                        property: "recordingInfoProgress"
                        to: 0
                        duration: Appearance.animation.expressiveSlowEffects.duration
                        easing.type: Appearance.animation.expressiveSlowEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveSlowEffects.bezierCurve
                    }
                }

                NumberAnimation {
                    id: bangsRecordingInfoOut

                    target: root
                    property: "recordingInfoProgress"
                    to: 0
                    duration: Appearance.animation.emphasizedAccel.duration
                    easing.type: Appearance.animation.emphasizedAccel.type
                    easing.bezierCurve: Appearance.animation.emphasizedAccel.bezierCurve
                }

                NumberAnimation {
                    id: pillGeometryExit

                    target: root
                    property: "pillMorphProgress"
                    to: 0
                    duration: root.pillActiveFusionDuration
                    easing.type: Easing.Linear

                    onFinished: {
                        const shouldShowProcessing = root.backendFinalizing
                            || RecordingService.isStopPending;
                        root.pillStopFusionMinimumActive = false;
                        if (shouldShowProcessing)
                            processingContentIn.restart();
                    }
                }

                NumberAnimation {
                    id: processingContentIn

                    target: root
                    property: "processingContentProgress"
                    to: 1
                    duration: Appearance.animation.expressiveSlowEffects.duration
                    easing.type: Appearance.animation.expressiveSlowEffects.type
                    easing.bezierCurve: Appearance.animation.expressiveSlowEffects.bezierCurve
                }

                SequentialAnimation {
                    id: bangsProcessingContentIn

                    PauseAnimation {
                        duration: Appearance.animation.emphasizedAccel.duration
                    }
                    NumberAnimation {
                        target: root
                        property: "processingContentProgress"
                        to: 1
                        duration: Appearance.animation.expressiveSlowEffects.duration
                        easing.type: Appearance.animation.expressiveSlowEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveSlowEffects.bezierCurve
                    }
                }

                ParallelAnimation {
                    id: recordingPresentationOut

                    NumberAnimation {
                        target: root
                        property: "recordingInfoProgress"
                        to: 0
                        duration: Appearance.animation.emphasizedAccel.duration
                        easing.type: Appearance.animation.emphasizedAccel.type
                        easing.bezierCurve: Appearance.animation.emphasizedAccel.bezierCurve
                    }
                    NumberAnimation {
                        target: root
                        property: "recordingActionProgress"
                        to: 0
                        duration: Appearance.animation.expressiveFastEffects.duration
                        easing.type: Appearance.animation.expressiveFastEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                    }
                    NumberAnimation {
                        target: root
                        property: "processingContentProgress"
                        to: 0
                        duration: Appearance.animation.emphasizedAccel.duration
                        easing.type: Appearance.animation.emphasizedAccel.type
                        easing.bezierCurve: Appearance.animation.emphasizedAccel.bezierCurve
                    }

                    onFinished: {
                        root.recordingExitActive = false;
                        contentResetTimer.restart();
                    }
                }

                Timer {
                    id: contentResetTimer

                    interval: 60
                    onTriggered: {
                        if (root.recordingPresentationActive)
                            return;

                        recordingContentIn.stop();
                        recordingPresentationOut.stop();
                        recordingActionOut.stop();
                        pillRecordingInfoOut.stop();
                        bangsRecordingInfoOut.stop();
                        processingContentIn.stop();
                        bangsProcessingContentIn.stop();
                        pillGeometryEntry.stop();
                        pillGeometryExit.stop();
                        root.pillMorphProgress = 0;
                        root.recordingInfoProgress = 0;
                        root.recordingActionProgress = 0;
                        root.processingContentProgress = 0;
                    }
                }

                Item {
                    id: dashboardBlurCutout

                    width: 340
                    height: 456
                    anchors.left: parent.horizontalCenter
                    anchors.leftMargin: 48
                    anchors.top: parent.top
                    anchors.topMargin: 132
                    visible: root.showDashboardHole
                    property real radius: 24
                }

                Canvas {
                    id: rootSurface

                    anchors.fill: parent
                    antialiasing: true
                    opacity: styleSurface.detached
                        && root.recordingPresentationActive ? 0 : 1

                    readonly property color surfaceColor: root.color
                    readonly property real outerRadius: root.radius
                    readonly property real topLeftRadius:
                        styleSurface.detached || (!keystoneWindow.topEdge
                            && !keystoneWindow.leftEdge) ? outerRadius : 0
                    readonly property real topRightRadius:
                        styleSurface.detached || (!keystoneWindow.topEdge
                            && !keystoneWindow.rightEdge) ? outerRadius : 0
                    readonly property real bottomRightRadius:
                        styleSurface.detached || (!keystoneWindow.bottomEdge
                            && !keystoneWindow.rightEdge) ? outerRadius : 0
                    readonly property real bottomLeftRadius:
                        styleSurface.detached || (!keystoneWindow.bottomEdge
                            && !keystoneWindow.leftEdge) ? outerRadius : 0
                    readonly property bool cutoutVisible:
                        root.showDashboardHole
                    readonly property real cutoutX:
                        dashboardBlurCutout.x
                    readonly property real cutoutY:
                        dashboardBlurCutout.y
                    readonly property real cutoutWidth:
                        dashboardBlurCutout.width
                    readonly property real cutoutHeight:
                        dashboardBlurCutout.height
                    readonly property real cutoutRadius:
                        dashboardBlurCutout.radius

                    function addRoundedRect(
                            context, x, y, width, height,
                            topLeft, topRight,
                            bottomRight, bottomLeft) {
                        const maxRadius = Math.min(
                            width / 2, height / 2);
                        const tl = Math.min(topLeft, maxRadius);
                        const tr = Math.min(topRight, maxRadius);
                        const br = Math.min(bottomRight, maxRadius);
                        const bl = Math.min(bottomLeft, maxRadius);

                        context.beginPath();
                        context.moveTo(x + tl, y);
                        context.lineTo(x + width - tr, y);
                        context.quadraticCurveTo(
                            x + width, y,
                            x + width, y + tr);
                        context.lineTo(
                            x + width, y + height - br);
                        context.quadraticCurveTo(
                            x + width, y + height,
                            x + width - br, y + height);
                        context.lineTo(x + bl, y + height);
                        context.quadraticCurveTo(
                            x, y + height,
                            x, y + height - bl);
                        context.lineTo(x, y + tl);
                        context.quadraticCurveTo(
                            x, y, x + tl, y);
                        context.closePath();
                    }

                    onPaint: {
                        const context = getContext("2d");
                        context.reset();
                        context.clearRect(0, 0, width, height);

                        addRoundedRect(
                            context, 0, 0, width, height,
                            topLeftRadius, topRightRadius,
                            bottomRightRadius, bottomLeftRadius);
                        context.fillStyle = surfaceColor;
                        context.fill();

                        if (cutoutVisible) {
                            context.globalCompositeOperation =
                                "destination-out";
                            addRoundedRect(
                                context,
                                cutoutX, cutoutY,
                                cutoutWidth, cutoutHeight,
                                cutoutRadius, cutoutRadius,
                                cutoutRadius, cutoutRadius);
                            context.fillStyle = "white";
                            context.fill();
                            context.globalCompositeOperation =
                                "source-over";
                        }
                    }

                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onSurfaceColorChanged: requestPaint()
                    onOuterRadiusChanged: requestPaint()
                    onTopLeftRadiusChanged: requestPaint()
                    onTopRightRadiusChanged: requestPaint()
                    onBottomRightRadiusChanged: requestPaint()
                    onBottomLeftRadiusChanged: requestPaint()
                    onCutoutVisibleChanged: requestPaint()
                    onCutoutXChanged: requestPaint()
                    onCutoutYChanged: requestPaint()
                    onCutoutWidthChanged: requestPaint()
                    onCutoutHeightChanged: requestPaint()
                    onCutoutRadiusChanged: requestPaint()
                }

                onTargetWChanged: {
                    if (root.audioPresentationPhase === root.audioPhaseCollapsing) {
                        wDuration = KeystoneMotion.audioCollapseDuration;
                        wBezier = KeystoneMotion.hoverBezier;
                        return;
                    }

                    if (targetW === root.audioW && root.audioGeometryActive) {
                        wDuration = KeystoneMotion.audioExpandDuration;
                        wBezier = KeystoneMotion.hoverBezier;
                        return;
                    }

                    if (root.isHoverWidthMotion(targetW)) {
                        wDuration = KeystoneMotion.hoverDuration;
                        wBezier = KeystoneMotion.hoverBezier;
                        return;
                    }

                    const isExpanding = targetW > width;
                    wDuration = isExpanding ? KeystoneMotion.expandingDuration : KeystoneMotion.shrinkingDuration;
                    wBezier = isExpanding ? KeystoneMotion.expandingBezier : KeystoneMotion.shrinkingBezier;
                }
                onTargetHChanged: {
                    if (root.audioPresentationPhase === root.audioPhaseCollapsing) {
                        hDuration = KeystoneMotion.audioCollapseDuration;
                        hBezier = KeystoneMotion.hoverBezier;
                        return;
                    }

                    if (targetH === root.audioH && root.audioGeometryActive) {
                        hDuration = KeystoneMotion.audioExpandDuration;
                        hBezier = KeystoneMotion.hoverBezier;
                        return;
                    }

                    if (root.isHoverHeightMotion(targetH)) {
                        hDuration = KeystoneMotion.hoverDuration;
                        hBezier = KeystoneMotion.hoverBezier;
                        return;
                    }

                    const isExpanding = targetH > height;
                    hDuration = isExpanding ? KeystoneMotion.expandingDuration : KeystoneMotion.shrinkingDuration;
                    hBezier = isExpanding ? KeystoneMotion.expandingBezier : KeystoneMotion.shrinkingBezier;
                }
                onTargetRChanged: {
                    if (root.isHoverRadiusMotion(targetR)) {
                        rDuration = KeystoneMotion.hoverDuration;
                        rBezier = KeystoneMotion.hoverBezier;
                    } else {
                        rDuration = KeystoneMotion.radiusDuration;
                        rBezier = KeystoneMotion.radiusBezier;
                    }
                }

                function isHoverWidthMotion(nextW) {
                    return isCollapsedMode && Math.abs(nextW - width) <= KeystoneMotion.hoverWidthDelta;
                }

                function isHoverHeightMotion(nextH) {
                    return isCollapsedMode && Math.abs(nextH - height) <= KeystoneMotion.hoverHeightDelta;
                }

                function isHoverRadiusMotion(nextR) {
                    return isCollapsedMode && Math.abs(nextR - radius) <= KeystoneMotion.hoverRadiusDelta;
                }

                Behavior on width {
                    enabled: !(styleSurface.detached && root.recordingPresentationActive)

                    NumberAnimation {
                        duration: root.wDuration
                        easing.type: KeystoneMotion.type
                        easing.bezierCurve: root.wBezier
                    }
                }
                Behavior on height {
                    NumberAnimation {
                        duration: root.hDuration
                        easing.type: KeystoneMotion.type
                        easing.bezierCurve: root.hBezier
                    }
                }
                Behavior on radius {
                    NumberAnimation {
                        duration: root.rDuration
                        easing.type: KeystoneMotion.type
                        easing.bezierCurve: root.rBezier
                    }
                }

                focus: root.hasClosablePopup

                onHasClosablePopupChanged: {
                    if (root.hasClosablePopup)
                        root.forceActiveFocus();
                }

                Keys.onEscapePressed: (event) => {
                    root.closeKeystonePopups();
                    event.accepted = true;
                }

                function closeKeystonePopups() {
                    root.expanded = false;
                    root.showLyrics = false;
                    root.showVolume = false;
                    root.showHub = false;
                    root.showTools = false;
                }

                PwObjectTracker { objects: [ Pipewire.defaultAudioSink, Pipewire.defaultAudioSource ] }
               
                property var audioNode: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
                property var sourceAudioNode: Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio : null
                property string sliderMode: "volume"

                Timer { 
                    id: volHideTimer
                    interval: 2000
                    onTriggered: {
                        if (volumeWidget.isInteractionActive) { restart() } 
                        else { root.showVolume = false }
                    }
                }
            
                Connections {
                    target: root.audioNode; ignoreUnknownSignals: true
                    function onVolumeChanged() { root.triggerSliderOSD("volume") } 
                    function onMutedChanged() { root.triggerSliderOSD("volume") }  
                }

                Connections {
                    target: root.sourceAudioNode; ignoreUnknownSignals: true
                    function onVolumeChanged() { root.triggerSliderOSD("mic") }
                    function onMutedChanged() { root.triggerSliderOSD("mic") }
                }

                Connections {
                    target: Brightness
                    function onBrightnessChanged() { root.triggerSliderOSD("brightness") }
                }

                function triggerSliderOSD(mode) {
                    if (root.contentPresentationActive || root.showHub
                            || root.showTools || root.expanded
                            || root.showLyrics) return
                    root.sliderMode = mode
                    root.showVolume = true; volHideTimer.restart()
                }

                function triggerVolumeOSD() {
                    root.triggerSliderOSD("volume")
                }
                
                property var currentPlayer: null

                Timer {
                    id: stickyTimer
                    interval: 500; repeat: true; triggeredOnStart: true
                    running: Mpris.players.values.length > 0
                    onRunningChanged: { if (!running) root.currentPlayer = null }
                    onTriggered: {
                        var players = Mpris.players.values
                        if (players.length === 0) { root.currentPlayer = null; return }
                        var playingPlayer = null
                        for (let i = 0; i < players.length; i++) { 
                            if (players[i].isPlaying) { playingPlayer = players[i]; break } 
                        }
                        if (playingPlayer) { 
                            if (root.currentPlayer !== playingPlayer) root.currentPlayer = playingPlayer 
                        } else {
                            var currentIsValid = false
                            if (root.currentPlayer) { 
                                for (let i = 0; i < players.length; i++) { 
                                    if (players[i] === root.currentPlayer) { currentIsValid = true; break } 
                                } 
                            }
                            if (!currentIsValid) root.currentPlayer = players[0]
                        }
                    }
                }

                MouseArea {
                    id: keystoneMouseArea  
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true   
                    enabled: !root.contentPresentationActive
                        && !root.isNotifMode
                        && !root.isVolumeMode
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.MiddleButton) {
                            if (root.showHub) root.showHub = false 
                            else if (root.showTools) root.showTools = false 
                            
                            root.showLyrics = !root.showLyrics
                            if (root.showLyrics) root.expanded = false
                        } else {
                            if (root.isLyricsMode || root.isHubMode || root.isToolsMode)
                                return;

                            root.expanded = !root.expanded;
                        }
                    }
                }

                Item {
                    id: staticCanvas
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 1600 
                    height: 1200

                    VolumeContent {
                        id: volumeWidget
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: keystoneWindow.horizontalEdge ? root.volW : root.volH
                        height: keystoneWindow.horizontalEdge ? root.volH : root.volW
                        vertical: !keystoneWindow.horizontalEdge

                        mode: root.sliderMode
                        audioNode: root.sliderMode === "volume" ? root.audioNode : root.sliderMode === "mic" ? root.sourceAudioNode : null
                        externalValue: Brightness.brightnessValue
                        iconName: root.sliderMode === "brightness" ? "brightness_medium" : ""
                        opacity: root.isVolumeMode ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.animation.expressiveEffects.duration
                                easing.type: Appearance.animation.expressiveEffects.type
                                easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                            }
                        }

                        onMoved: value => {
                            if (root.sliderMode === "brightness")
                                Brightness.setBrightness(value);
                        }
                    }
                        
                    NotificationContent { 
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.topMargin: 10
                        width: root.notifW - 20
                        height: root.notifH - 20

                        manager: NotificationManager
                        
                        opacity: root.isNotifMode ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.animation.expressiveEffects.duration
                                easing.type: Appearance.animation.expressiveEffects.type
                                easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                            }
                        }
                    }
                        
                    LyricsContent { 
                        id: lyricsWidget 
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.lyricsW
                        height: root.lyricsH

                        player: root.currentPlayer; active: root.isLyricsMode
                        opacity: root.isLyricsMode ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.animation.expressiveEffects.duration
                                easing.type: Appearance.animation.expressiveEffects.type
                                easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                            }
                        }
                    }
                    
                    MediaContent { 
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.topMargin: 20
                        width: root.expandedW - 40
                        height: root.expandedH - 40

                        opacity: (!root.contentPresentationActive
                            && root.expanded
                            && !root.isLyricsMode
                            && !root.isHubMode) ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.animation.expressiveEffects.duration
                                easing.type: Appearance.animation.expressiveEffects.type
                                easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                            }
                        }
                    }
                        
                    HubContent {
                        id: hub
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: implicitWidth
                        height: implicitHeight
                        
                        player: root.currentPlayer
                        screen: keystoneWindow.screen
                        currentIndex: root.hubTabIndex
                        onCurrentIndexChanged: root.hubTabIndex = currentIndex
                        onCloseRequested: root.showHub = false
                        onAvatarEditRequested: {
                            root.showHub = false
                            styleSurface.avatarEditRequested(keystoneWindow.screen)
                        }

                        opacity: root.isHubMode ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.animation.expressiveEffects.duration
                                easing.type: Appearance.animation.expressiveEffects.type
                                easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                            }
                        }
                    }

                    ToolsContent {
                        id: toolsWidget 
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: keystoneWindow.horizontalEdge
                            ? root.toolsW : root.toolsH
                        height: keystoneWindow.horizontalEdge
                            ? root.toolsH : root.toolsW
                        vertical: !keystoneWindow.horizontalEdge
                        edge: keystoneWindow.edge

                        opacity: root.isToolsMode ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.animation.expressiveEffects.duration
                                easing.type: Appearance.animation.expressiveEffects.type
                                easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                            }
                        }

                        onRequestHideKeystone: { root.showTools = false }
                    }
                }

                MouseArea {
                    id: collapsedInputArea
                    anchors.fill: parent
                    z: 10000
                    enabled: root.isCollapsedMode
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                    onClicked: (mouse) => {
                        if (mouse.button === Qt.MiddleButton) {
                            root.showLyrics = !root.showLyrics;
                            if (root.showLyrics)
                                root.expanded = false;
                        } else if (mouse.button === Qt.LeftButton) {
                            root.expanded = true;
                        }

                        mouse.accepted = true;
                    }
                }
            }

            AudioRecordingVisual {
                id: audioRecordingVisual

                anchors.centerIn: root
                width: root.width
                height: root.height
                sessionActive: root.audioPresentationActive
                recording: AudioRecordingService.isRecording
                stopping: AudioRecordingService.isStopPending
                sourceNodeName: AudioRecordingService.sourceNodeName
                captureSink: AudioRecordingService.captureSink
                elapsedMs: AudioRecordingService.elapsedMs
                visible: root.audioPresentationActive
                    || contentProgress > 0.01
                z: root.z + 3

                onStopRequested: AudioRecordingService.stop()
                onCollapseRequested: {
                    if (!root.audioSessionActive)
                        root.audioPresentationPhase = root.audioPhaseCollapsing;
                }
                onExitFinished: {
                    root.audioPresentationPhase = root.audioSessionActive
                        ? root.audioPhaseExpanded
                        : root.audioPhaseHidden;
                }
            }

            ClockContent {
                id: clockContent

                anchors.top: root.top
                anchors.horizontalCenter: root.horizontalCenter
                width: keystoneWindow.horizontalEdge
                    ? root.collapsedW : root.collapsedH
                height: keystoneWindow.horizontalEdge
                    ? root.collapsedH : root.collapsedW

                player: root.currentPlayer
                edge: keystoneWindow.edge

                opacity: root.isCollapsedMode ? 1 : 0
                scale: 0.96 + 0.04 * opacity
                transform: Translate {
                    y: (1 - clockContent.opacity) * 4
                }
                visible: opacity > 0.01
                z: root.z + 4

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.isCollapsedMode
                            ? Appearance.animation.expressiveSlowEffects.duration
                            : Appearance.animation.expressiveFastEffects.duration
                        easing.type: root.isCollapsedMode
                            ? Appearance.animation.expressiveSlowEffects.type
                            : Appearance.animation.expressiveFastEffects.type
                        easing.bezierCurve: root.isCollapsedMode
                            ? Appearance.animation.expressiveSlowEffects.bezierCurve
                            : Appearance.animation.expressiveFastEffects.bezierCurve
                    }
                }
            }

            PillRecordingVisual {
                id: pillRecordingVisual

                anchors.rightMargin: keystoneWindow.rightEdge ? 0 : -rightOverflow
                anchors.leftMargin: keystoneWindow.rightEdge ? -rightOverflow : 0
                anchors.verticalCenter: root.verticalCenter
                state: keystoneWindow.rightEdge ? "leftward" : "rightward"
                states: [
                    State {
                        name: "rightward"
                        AnchorChanges {
                            target: pillRecordingVisual
                            anchors.left: undefined
                            anchors.right: root.right
                        }
                    },
                    State {
                        name: "leftward"
                        AnchorChanges {
                            target: pillRecordingVisual
                            anchors.left: root.left
                            anchors.right: undefined
                        }
                    }
                ]
                active: styleSurface.detached && root.recordingPresentationActive
                recording: styleSurface.detached && root.isRecording
                finalizing: styleSurface.detached && root.isFinalizing
                recordingType: RecordingService.recordingType
                elapsedMs: RecordingService.elapsedMs
                morphProgress: root.pillMorphProgress
                recordingInfoProgress: root.recordingInfoProgress
                recordingActionProgress: root.recordingActionProgress
                processingContentProgress: root.processingContentProgress
                baseMainWidth: root.collapsedW
                layoutHeight: root.collapsedH
                visible: styleSurface.detached && (active || opacity > 0.01)
                z: root.z + 2

                onStopRequested: {
                    if (!RecordingService.stop())
                        return;

                    root.pillStopFusionMinimumActive = true;
                }
            }

            BangsRecordingVisual {
                id: bangsRecordingVisual

                anchors.centerIn: root
                width: root.width
                height: root.height
                active: !styleSurface.detached && root.recordingPresentationActive
                recording: !styleSurface.detached && root.isRecording
                finalizing: !styleSurface.detached && root.isFinalizing
                recordingType: RecordingService.recordingType
                elapsedMs: RecordingService.elapsedMs
                recordingInfoProgress: root.recordingInfoProgress
                recordingActionProgress: root.recordingActionProgress
                processingContentProgress: root.processingContentProgress
                visible: !styleSurface.detached && (active || opacity > 0.01)
                z: root.z + 2

                onStopRequested: RecordingService.stop()
            }

            AttachedEdgeCurve {
                id: rightTopCurve
                visible: styleSurface.showAttachedEdgeCurves
                edge: keystoneWindow.edge
                after: true
                along: keystoneWindow.edgeCurveAlong
                depth: keystoneWindow.edgeCurveDepth
                sideControl: keystoneWindow.edgeCurveSideControl
                edgeControl: keystoneWindow.edgeCurveOuterControl
                fillColor: root.color
                anchors {
                    left: keystoneWindow.leftEdge ? root.left
                        : (keystoneWindow.horizontalEdge ? root.right : undefined)
                    right: keystoneWindow.rightEdge ? root.right : undefined
                    top: keystoneWindow.topEdge ? root.top
                        : (!keystoneWindow.horizontalEdge ? root.bottom : undefined)
                    bottom: keystoneWindow.bottomEdge ? root.bottom : undefined
                }
                Connections {
                    target: root
                    function onColorChanged() {
                        rightTopCurve.requestPaint();
                    }
                }
            }

            CompositorBlurRegion {
                targetWindow: keystoneWindow
                backgroundItem: root
                subtractedBackgroundItems: [dashboardBlurCutout]
                radius: root.radius
            }
        }

    }
}
