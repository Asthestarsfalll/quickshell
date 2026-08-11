import QtQuick
import Quickshell
import Quickshell.Wayland
import Clavis.DesktopCards
import qs.Common
import qs.Services
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
        property var analysis: null
        property int analysisGeneration: 0
        property string pendingLayoutFocusId: ""
        readonly property string analysisRequestKey:
            "desktop-cards:" + String(modelData.name)

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
                    || window.desktopIds.length === 0)
                return;
            window.analysis = null;
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

        function cardDescriptors() {
            const result = [];
            window.desktopIds.forEach(function(id) {
                const state = SystemCardService.card(id);
                if (!state || !state.desktop)
                    return;
                const size = SystemCardService.desktopSize(
                    id, window.scene.canvasWidth, window.scene.canvasHeight);
                result.push({
                    id: id,
                    width: size.width,
                    height: size.height,
                    xNorm: state.desktop.xNorm,
                    yNorm: state.desktop.yNorm,
                    mode: state.desktop.mode
                });
            });
            return result;
        }

        function runLayout() {
            if (!window.scene || !window.analysis
                    || window.desktopIds.length === 0)
                return;
            const placements = DesktopCardLayout.solve(
                window.cardDescriptors(),
                window.scene.canvasWidth,
                window.scene.canvasHeight,
                window.analysis,
                window.pendingLayoutFocusId
            );
            window.pendingLayoutFocusId = "";
            SystemCardService.applyDesktopLayout(placements);
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

        Item {
            id: viewport

            anchors.fill: parent
            clip: true

            DesktopCardCanvas {
                id: cardCanvas

                scene: window.scene
                screenName: modelData.name
                analysis: window.analysis
                hostItem: viewport
            }
        }

        Connections {
            target: WallpaperAnalyzer

            function onAnalysisReady(requestKey, generation, result) {
                if (requestKey !== window.analysisRequestKey
                        || generation !== window.analysisGeneration) {
                    return;
                }
                window.analysis = result;
                window.runLayout();
            }
        }

        Connections {
            target: SystemCardService

            function onCardStateChanged() {
                Qt.callLater(window.runLayout);
            }

            function onDesktopLayoutRequested(focusCardId) {
                window.pendingLayoutFocusId = String(focusCardId || "");
                Qt.callLater(window.runLayout);
            }
        }

        onDesktopIdsChanged: window.requestAnalysis()
        onAnalysisKeyChanged: window.requestAnalysis()

        Component.onCompleted: {
            console.log(
                "[DesktopCards] host screen="
                    + String(window.screenKey) + " layer=Bottom"
            );
            WallpaperSceneService.sceneFor(window.screenKey);
            Qt.callLater(window.requestAnalysis);
        }
    }
}
