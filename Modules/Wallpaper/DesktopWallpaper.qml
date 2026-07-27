import QtQuick
import Quickshell
import Quickshell.Wayland
import Clavis.Niri 1.0
import qs.Common
import qs.Services
import "../../Common/functions/WallpaperMath.js" as WallpaperMath

Variants {
    id: variants

    model: Quickshell.screens

    PanelWindow {
        id: wallpaperWindow

        required property var modelData

        screen: modelData
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "clavis-wallpaper"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        mask: Region {
            item: Item {}
        }

        Item {
            id: root

            anchors.fill: parent
            clip: true

            property int serviceRevision: WallpaperService.revision
            property int settingsRevision:
                WallpaperService.settingsRevision
            property int backendSurfaceGeneration:
                AwwwWallpaperService.surfaceGeneration
            property var outputWorkspaces: []
            property var activeWorkspace: ({})

            readonly property string targetSource:
                serviceRevision >= 0
                    ? WallpaperService
                        .wallpaperForScreen(modelData.name)
                    : ""
            readonly property string targetFillModeName:
                settingsRevision >= 0
                    ? WallpaperService
                        .fillModeForScreen(modelData.name)
                    : "Fill"
            readonly property int targetFillMode:
                WallpaperService.qtFillMode(targetFillModeName)
            readonly property real targetShaderFillMode:
                WallpaperService.shaderFillMode(targetFillModeName)
            readonly property int tiledColumnCount:
                Number(activeWorkspace.tiledColumnCount || 0)
            readonly property bool hasHorizontalDriver:
                PersonalizationConfig.parallaxFollowTiledColumns
                || PersonalizationConfig.parallaxFollowSidebars
            readonly property bool hasVerticalDriver:
                PersonalizationConfig.parallaxVerticalEnabled
                && PersonalizationConfig.parallaxFollowWorkspaces
            readonly property bool parallaxRequested:
                hasHorizontalDriver || hasVerticalDriver
            readonly property bool parallaxSupported:
                targetFillMode === Image.PreserveAspectCrop
                && !WallpaperService.isColorSource(targetSource)
                && imageMetadata.status === Image.Ready
                && imageMetadata.sourceSize.width > 1
                && imageMetadata.sourceSize.height > 1
            readonly property bool manualParallaxActive:
                parallaxRequested && parallaxSupported
            readonly property real preferredScale:
                manualParallaxActive
                    ? PersonalizationConfig.parallaxPreferredScale : 1
            readonly property real coverScale: manualParallaxActive
                ? WallpaperMath.coverGeometry(
                    width, height,
                    imageMetadata.sourceSize.width,
                    imageMetadata.sourceSize.height,
                    preferredScale).coverScale
                : 1
            readonly property real effectiveScale:
                coverScale * preferredScale
            readonly property real scaledWidth: manualParallaxActive
                ? imageMetadata.sourceSize.width * effectiveScale : width
            readonly property real scaledHeight: manualParallaxActive
                ? imageMetadata.sourceSize.height * effectiveScale : height
            readonly property real overflowX:
                Math.max(0, scaledWidth - width)
            readonly property real overflowY:
                Math.max(0, scaledHeight - height)
            readonly property real tiledProgress: {
                if (!PersonalizationConfig
                        .parallaxFollowTiledColumns)
                    return 0.5;
                return WallpaperMath.tiledColumnProgress(
                    tiledColumnCount,
                    PersonalizationConfig.parallaxTiledColumnSpan);
            }
            readonly property bool leftSidebarOnThisScreen:
                WidgetState.leftSidebarOpen
                && Brightness.activeScreen
                && Brightness.activeScreen.name === modelData.name
            readonly property string rightSidebarScreenName:
                WidgetState.qsScreenName !== ""
                    ? WidgetState.qsScreenName
                    : (Brightness.activeScreen
                        ? Brightness.activeScreen.name : "")
            readonly property bool rightSidebarOnThisScreen:
                WidgetState.qsOpen
                && rightSidebarScreenName === modelData.name
            readonly property real sidebarStep:
                PersonalizationConfig.parallaxPreferredScale
                / Math.max(2,
                    PersonalizationConfig.parallaxTiledColumnSpan)
                / 2
            readonly property real horizontalProgress: {
                return WallpaperMath.horizontalProgress(
                    tiledProgress,
                    PersonalizationConfig.parallaxFollowSidebars
                        && leftSidebarOnThisScreen,
                    PersonalizationConfig.parallaxFollowSidebars
                        && rightSidebarOnThisScreen,
                    sidebarStep);
            }
            readonly property real verticalProgress: {
                if (!PersonalizationConfig.parallaxVerticalEnabled
                        || !PersonalizationConfig
                            .parallaxFollowWorkspaces)
                    return 0.5;
                return WallpaperMath.workspaceProgress(
                    outputWorkspaces);
            }

            function clamp01(value) {
                return WallpaperMath.clamp01(value);
            }

            function reportSurface() {
                AwwwWallpaperService.reportQuickshellSurface(
                    modelData.name,
                    root.backendSurfaceGeneration,
                    renderer.ready,
                    renderer.lastError);
            }

            function refreshNiriState() {
                root.outputWorkspaces =
                    Niri.workspacesForOutput(modelData.name);
                root.activeWorkspace =
                    Niri.activeWorkspaceForOutput(modelData.name);
            }

            onBackendSurfaceGenerationChanged:
                Qt.callLater(root.reportSurface)
            onTargetSourceChanged: Qt.callLater(root.reportSurface)
            Component.onCompleted: {
                root.refreshNiriState();
                Qt.callLater(root.reportSurface)
            }

            Connections {
                target: Niri

                function onWorkspacesChanged() {
                    root.refreshNiriState();
                }

                function onWindowsChanged() {
                    root.refreshNiriState();
                }

                function onOutputsChanged() {
                    root.refreshNiriState();
                }
            }

            Image {
                id: imageMetadata

                visible: false
                source: root.parallaxRequested
                    && root.targetSource !== ""
                    && !WallpaperService
                        .isColorSource(root.targetSource)
                    ? Paths.fileUrl(root.targetSource) : ""
                asynchronous: true
                cache: true
            }

            WallpaperTransitionSurface {
                id: renderer

                x: root.overflowX > 0
                    ? WallpaperMath.wallpaperPosition(
                        root.overflowX, root.horizontalProgress)
                    : (root.width - width) / 2
                y: root.overflowY > 0
                    ? WallpaperMath.wallpaperPosition(
                        root.overflowY, root.verticalProgress)
                    : (root.height - height) / 2
                width: Math.max(1, root.scaledWidth)
                height: Math.max(1, root.scaledHeight)
                sourcePath: root.targetSource
                imageFillMode: root.targetFillMode
                shaderFillMode: root.targetShaderFillMode
                transitionType:
                    PersonalizationConfig.wallpaperTransitionType
                includedTransitions:
                    PersonalizationConfig.includedTransitions
                transitionDurationMs:
                    PersonalizationConfig.transitionDurationMs
                transitionEasingMode:
                    PersonalizationConfig.transitionEasingMode
                transitionBezierCurve:
                    PersonalizationConfig.transitionBezierCurve
                textureWidth: Math.min(
                    Math.max(1, Math.round(root.width)), 8192)
                textureHeight: Math.min(
                    Math.max(1, Math.round(root.height)), 8192)

                onReadyChanged: root.reportSurface()
                onLastErrorChanged: root.reportSurface()
                onLoadFailed: (source, message) => {
                    WallpaperService.reportDesktopError(
                        modelData.name, message);
                }

                Behavior on x {
                    NumberAnimation {
                        duration: Appearance.animation
                            .wallpaperParallax.duration
                        easing.type: Appearance.animation
                            .wallpaperParallax.type
                    }
                }

                Behavior on y {
                    NumberAnimation {
                        duration: Appearance.animation
                            .wallpaperParallax.duration
                        easing.type: Appearance.animation
                            .wallpaperParallax.type
                    }
                }
            }
        }
    }
}
