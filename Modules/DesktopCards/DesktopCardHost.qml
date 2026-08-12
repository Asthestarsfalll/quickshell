import QtQuick
import Quickshell
import Quickshell.Wayland
import Clavis.DesktopCards
import qs.Common
import qs.Services
import qs.Widgets.common
import qs.Modules.SystemCards
import "./DesktopCardLayout.js" as DesktopCardLayout

Variants {
    id: variants

    model: Quickshell.screens

    PanelWindow {
        id: window

        required property var modelData
        screen: modelData
        visible: true
        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "clavis-desktop-cards"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        readonly property string screenKey: String(modelData.name)
        // Read the cache from a binding.  sceneFor() mutates the cache, so
        // calling it from this binding creates a self-invalidating binding
        // loop and can leave the canvas with a null/one-pixel scene.
        readonly property var scene:
            WallpaperSceneService.scenes[window.screenKey] || null
        readonly property var screenNames: cardCanvas.screenNames
        readonly property var desktopIds:
            {
                // Read the state property directly so this binding is
                // invalidated even when the filtering helper itself is a JS
                // function call.
                const cards = SystemCardService.cards;
                return cards
                    ? SystemCardService.desktopIdsForScreen(
                        modelData.name, window.screenNames)
                    : [];
            }
        readonly property string analysisKey:
            scene ? scene.analysisKey : ""
        readonly property string layoutMode:
            SystemCardService.globalDesktopLayoutMode
        property string lastLayoutMode: ""
        property var analysis: null
        property int analysisGeneration: 0
        property string requestedAnalysisKey: ""
        property bool automaticLayoutScheduled: false
        readonly property string analysisRequestKey:
            "desktop-cards:" + String(modelData.name)
        readonly property bool ownsPresentationDrag:
            SystemCardDragSession.presentationActive
            && SystemCardDragSession.screenName === window.screenKey

        Binding {
            when: window.scene !== null
            target: window.scene
            property: "screenWidth"
            value: window.width
        }
        Binding {
            when: window.scene !== null
            target: window.scene
            property: "screenHeight"
            value: window.height
        }

        function requestAnalysis() {
            if (!window.scene || window.analysisKey === ""
                    || !SystemCardService.isWallpaperLayoutMode(
                        window.layoutMode)
                    || window.desktopIds.length === 0
                    || !window.scene.analysisGeometryReady)
                return;
            if (window.requestedAnalysisKey === window.analysisKey)
                return;
            window.analysis = null;
            window.requestedAnalysisKey = window.analysisKey;
            window.analysisGeneration += 1;
            WallpaperAnalyzer.request(
                window.analysisRequestKey,
                window.analysisGeneration,
                window.scene.sourcePath,
                Math.round(window.scene.canvasWidth),
                Math.round(window.scene.canvasHeight),
                window.scene.panoramaSelected
                    ? "panorama" : window.scene.fillModeName,
                Math.round(window.scene.imagePixelWidth),
                Math.round(window.scene.imagePixelHeight)
            );
        }

        function scheduleAutomaticLayout() {
            if (window.automaticLayoutScheduled)
                return;
            window.automaticLayoutScheduled = true;
            Qt.callLater(function() {
                window.automaticLayoutScheduled = false;
                if (SystemCardService.isScreenLayoutMode(
                        window.layoutMode)) {
                    window.runScreenLayout();
                    return;
                }
                if (!SystemCardService.isWallpaperLayoutMode(
                        window.layoutMode))
                    return;
                window.requestAnalysis();
                window.runLayout();
            });
        }

        function cardDescriptors(space) {
            const result = [];
            const coordinateSpace = String(space || "wallpaper");
            window.desktopIds.forEach(function(id) {
                const state = SystemCardService.card(id);
                if (!state || !state.desktop)
                    return;
                const size = SystemCardService.cardSize(id);
                result.push({
                    id: id,
                    width: size.width,
                    height: size.height,
                    xNorm: state.desktop[coordinateSpace].xNorm,
                    yNorm: state.desktop[coordinateSpace].yNorm
                });
            });
            return result;
        }

        function runLayout() {
            const mode = SystemCardService.globalDesktopLayoutMode;
            if (!window.scene || window.desktopIds.length === 0
                    || !SystemCardService.isWallpaperLayoutMode(mode)
                    || !window.analysis)
                return;
            // Do not let a cached analysis result move a newly transferred
            // card before its first frame has been presented at the drop
            // point. This is a handoff barrier, not a visibility gate.
            if (!cardCanvas.allActiveCardsPresented
                    || cardCanvas.screenTransitionActive
                    || cardCanvas.anyCardDragging
                    || SystemCardDragSession.visualHandoffPending)
                return;
            const placements = DesktopCardLayout.solve(
                window.cardDescriptors(),
                window.scene.canvasWidth,
                window.scene.canvasHeight,
                window.analysis,
                mode
            );
            SystemCardService.applyDesktopLayout(placements);
            cardCanvas.startAutomaticTransitions();
        }

        function runScreenLayout() {
            const mode = SystemCardService.globalDesktopLayoutMode;
            if (!SystemCardService.isScreenLayoutMode(mode)
                    || window.desktopIds.length === 0
                    || cardCanvas.screenTransitionActive
                    || cardCanvas.anyCardDragging
                    || !cardCanvas.allActiveCardsPresented
                    || SystemCardDragSession.visualHandoffPending)
                return;
            const placements = DesktopCardLayout.solveScreen(
                window.cardDescriptors("screen"),
                window.width,
                window.height,
                mode
            );
            if (placements.length === 0)
                return;
            const prepared = cardCanvas.prepareScreenLayoutTransition(
                placements);
            SystemCardService.applyDesktopScreenLayout(placements);
            if (prepared)
                cardCanvas.startScreenLayoutTransition();
        }

        mask: Region {
            Region { item: cardCanvas.inputSlot0 }
            Region { item: cardCanvas.inputSlot1 }
            Region { item: cardCanvas.inputSlot2 }
            Region { item: cardCanvas.inputSlot3 }
            Region { item: cardCanvas.inputSlot4 }
            Region { item: cardCanvas.inputSlot5 }
            Region { item: cardCanvas.inputSlot6 }
            Region { item: cardCanvas.inputSlot7 }
            Region { item: cardCanvas.inputSlot8 }
            Region { item: cardCanvas.inputSlot9 }
        }

        // The desktop host is a separate Bottom-layer surface, so it cannot
        // inherit SidebarHostWindow's blur region.  Submit only the live card
        // slots: empty desktop space remains visually and interactively
        // transparent, while each card participates in the same compositor
        // blur managed by BlurService.
        CompositorBlurRegion {
            targetWindow: window
            backgroundItem: cardCanvas.inputSlot0
            additionalBackgroundItems: [
                cardCanvas.inputSlot1,
                cardCanvas.inputSlot2,
                cardCanvas.inputSlot3,
                cardCanvas.inputSlot4,
                cardCanvas.inputSlot5,
                cardCanvas.inputSlot6,
                cardCanvas.inputSlot7,
                cardCanvas.inputSlot8,
                cardCanvas.inputSlot9,
                presentationGhost
            ]
            subtractedBackgroundItems:
                cardCanvas.systemCardBlurExclusionItems.concat(
                    window.ownsPresentationDrag
                        && SystemCardService.cardExcludesHostBlur(
                            SystemCardDragSession.tileId)
                        ? [presentationGhost] : [])
            radius: Appearance.rounding.extraLarge
        }

        Item {
            id: viewport

            anchors.fill: parent
            clip: true

            DesktopCardCanvas {
                id: cardCanvas

                anchors.fill: parent
                scene: window.scene
                screenName: modelData.name
                hostItem: viewport
            }

            // The drag proxy and every DesktopCard are siblings in this
            // output-local Bottom-layer surface. The proxy is a visual
            // renderer for the one logical CardState, not a cloned model.
            Item {
                id: presentationGhost

                x: SystemCardDragSession.ghostX
                y: SystemCardDragSession.ghostY
                width: window.ownsPresentationDrag
                    ? SystemCardDragSession.ghostWidth : 0
                height: window.ownsPresentationDrag
                    ? SystemCardDragSession.ghostHeight : 0
                visible: window.ownsPresentationDrag
                z: 100

                Rectangle {
                    anchors.fill: parent
                    radius: Appearance.rounding.extraLarge
                    visible: ghostContent.shellManagedSurface
                    color: BlurService.opaqueBackgroundColor(
                        Appearance.m3colors.m3surfaceContainerHigh)
                }

                SystemCardContent {
                    id: ghostContent

                    anchors.fill: parent
                    tileId: SystemCardDragSession.tileId
                    active: presentationGhost.visible
                    useShellManagedSurface: true
                }
            }
        }

        Connections {
            target: WallpaperAnalyzer

            function onAnalysisReady(requestKey, generation, result) {
                if (requestKey !== window.analysisRequestKey
                        || generation !== window.analysisGeneration) {
                    return;
                }
                window.analysis = result || ({ valid: false });
                if (!result || !result.valid) {
                    console.warn(
                        "[DesktopCards] analysis failed path="
                            + String(window.scene
                                ? window.scene.sourcePath : "")
                            + " reason="
                            + String(result ? result.errorString
                            : "no-result")
                    );
                    // The solver treats an invalid analysis as a uniform
                    // busy map and still supplies a deterministic,
                    // collision-free wallpaper placement. Analysis failure
                    // must not leave an automatic card in screen space.
                    window.runLayout();
                    return;
                }
                console.log(
                    "[DesktopCards] analysis ready path="
                        + String(window.scene.sourcePath)
                        + " size=" + String(result.analysisWidth)
                        + "x" + String(result.analysisHeight)
                        + " valid=true minBusy="
                        + Number(result.minBusyScore).toFixed(4)
                        + " maxBusy="
                        + Number(result.maxBusyScore).toFixed(4)
                );
                window.runLayout();
            }
        }

        Connections {
            target: SystemCardService

            function onCardStateChanged() {
                Qt.callLater(window.scheduleAutomaticLayout);
            }

            function onDesktopLayoutRequested() {
                window.scheduleAutomaticLayout();
            }
        }

        Connections {
            target: cardCanvas

            function onDelegateReady() {
                Qt.callLater(window.runLayout);
            }

            function onHandoffReady(tileId) {
                if (SystemCardDragSession.completeVisualHandoff(tileId))
                    window.scheduleAutomaticLayout();
            }

            function onScreenTransitionsFinished() {
                window.scheduleAutomaticLayout();
            }
        }

        onDesktopIdsChanged: window.scheduleAutomaticLayout()
        onSceneChanged: {
            if (SystemCardService.isWallpaperLayoutMode(
                    window.layoutMode))
                window.requestAnalysis();
        }
        onAnalysisKeyChanged: {
            if (SystemCardService.isWallpaperLayoutMode(
                    window.layoutMode)) {
                window.requestedAnalysisKey = "";
                window.requestAnalysis();
            }
        }
        onLayoutModeChanged: {
            const oldMode = window.lastLayoutMode;
            const wasWallpaper = SystemCardService.isWallpaperLayoutMode(
                oldMode);
            const isWallpaper = SystemCardService.isWallpaperLayoutMode(
                window.layoutMode);
            if (SystemCardService.isFreeLayoutMode(window.layoutMode)) {
                window.analysis = null;
                window.requestedAnalysisKey = "";
                cardCanvas.promoteCardsToScreen();
            } else if (SystemCardService.isScreenLayoutMode(
                    window.layoutMode)) {
                cardCanvas.promoteCardsToScreen();
                window.scheduleAutomaticLayout();
            } else if (isWallpaper) {
                if (!wasWallpaper) {
                    window.analysis = null;
                    window.requestedAnalysisKey = "";
                }
                window.scheduleAutomaticLayout();
            }
            window.lastLayoutMode = window.layoutMode;
        }

        Component.onCompleted: {
            console.log(
                "[DesktopCards] host screen="
                    + String(window.screenKey) + " layer=Bottom"
            );
            WallpaperSceneService.sceneFor(window.screenKey);
            DesktopPresentationService.registerHost(
                window.screenKey, viewport);
            Qt.callLater(function() {
                window.lastLayoutMode = window.layoutMode;
                if (SystemCardService.isFreeLayoutMode(window.layoutMode)
                        || SystemCardService.isScreenLayoutMode(
                            window.layoutMode))
                    cardCanvas.promoteCardsToScreen();
                window.scheduleAutomaticLayout();
            });
        }

        Component.onDestruction: DesktopPresentationService.unregisterHost(
            window.screenKey, viewport)
    }
}
