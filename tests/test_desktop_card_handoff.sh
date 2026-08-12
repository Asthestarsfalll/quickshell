#!/bin/sh

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_dir"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

require_text() {
    grep -Fq -- "$2" "$1" || fail "$1 does not contain: $2"
}

reject_text() {
    if grep -Fq -- "$2" "$1"; then
        fail "$1 unexpectedly contains: $2"
    fi
}

session=Services/SystemCardDragSession.qml
presentation_service=Services/DesktopPresentationService.qml
system_view=Modules/Sidebars/Left/SystemView.qml
grid_tile=Modules/Sidebars/Left/system/SystemGridTile.qml
sidebar_host=Modules/Sidebars/SidebarHostWindow.qml
canvas=Modules/DesktopCards/DesktopCardCanvas.qml
desktop_card=Modules/DesktopCards/DesktopCard.qml
desktop_host=Modules/DesktopCards/DesktopCardHost.qml
state=Modules/SystemCards/SystemCardState.js
placement=Modules/SystemCards/SystemCardPlacement.js
wallpaper=Modules/Wallpaper/DesktopWallpaper.qml
awww=Common/functions/AwwwCommand.js

# The drag session only protects ownership until the screen-space DesktopCard
# is ready. It has no timer/frame/watchdog handoff path.
require_text "$session" 'property string phase:'
require_text "$session" 'function completeVisualHandoff(cardId)'
require_text "$session" 'function prepareVisualHandoff(cardId)'
require_text "$session" 'function requestVisualHandoffCheck(cardId)'
require_text "$session" 'visualHandoffPending'
require_text "$session" 'readonly property var presentationGhostRect:'
require_text "$session" 'property real presentationPointerX: 0'
require_text "$session" 'property real presentationPointerY: 0'
require_text "$session" 'readonly property real grabLocalX:'
require_text "$session" 'readonly property real grabLocalY:'
require_text "$session" 'readonly property real presentationGrabOffsetX:'
require_text "$session" 'function promoteToPresentation('
require_text "$session" 'root.transition(root.draggingSidebarPhase,'
require_text "$session" 'property string screenName: ""'
require_text "$session" 'preserving committed desktop handoff'
reject_text "$session" 'frozenGhostX'
reject_text "$session" 'frozenGhostRect'
reject_text "$session" 'Timer {'
reject_text "$session" 'handoffWatchdogTimer'
reject_text "$session" 'ghostCleanupTimer.restart()'

# The original source-local grab point is captured once. Promotion and every
# later pointer move use real item -> global -> presentation-host mapping;
# there is no cross-window delta approximation.
require_text "$presentation_service" 'function registerHost(screenName, item)'
require_text "$presentation_service" 'function mapItemPoint('
require_text "$presentation_service" 'function mapItemRect('
require_text "$presentation_service" 'host.mapFromGlobal('
require_text "$system_view" 'DesktopPresentationService.mapItemRect('
require_text "$system_view" 'DesktopPresentationService.mapItemPoint('
require_text "$system_view" 'SystemCardDragSession.grabLocalX'
require_text "$system_view" 'SystemCardDragSession.promoteToPresentation('
require_text "$system_view" 'mappedGrabPoint.x - sourceRect.x'
require_text "$system_view" 'SystemCardDragSession.hostWidth'
reject_text "$system_view" 'presentationInitialPointerX'
reject_text "$system_view" 'presentationInitialPointerY'
reject_text "$system_view" 'presentationSidebarPointerX'
reject_text "$system_view" 'presentationSidebarPointerY'
reject_text "$system_view" 'presentationPoint.x - sourceRect.x'
reject_text "$system_view" '+ pointerLocalX -'
reject_text "$system_view" '+ pointerLocalY -'
require_text "$grid_tile" 'real grabLocalX'
require_text "$grid_tile" 'real grabLocalY'
require_text "$grid_tile" 'centroid.pressPosition.x'
require_text "$grid_tile" 'centroid.position.x'
require_text "$grid_tile" 'SystemCardDragSession.presentationActive'
require_text "$system_view" 'Placement.screen'
reject_text "$system_view" 'screenToWallpaper('
reject_text "$system_view" 'function outputSize()'
require_text "$system_view" 'SystemCardService.setContainer('
require_text "$system_view" 'SystemCardDragSession.freezeGhost(screenX, screenY)'
require_text "$system_view" 'SystemCardDragSession.markTransferCommitted(tileId)'
require_text "$system_view" 'SystemCardDragSession.requestVisualHandoffCheck(tileId);'
reject_text "$system_view" 'pendingDesktopTransfer'

# SidebarHostWindow contains only the sidebar UI and pointer grab. Both the
# ghost and DesktopCards are rendered by DesktopCardHost's one Bottom-layer
# Ignore surface.
reject_text "$sidebar_host" 'systemCardDragGhost'
reject_text "$sidebar_host" 'ShaderEffectSource {'
require_text "$desktop_host" 'id: presentationGhost'
require_text "$desktop_host" 'DesktopPresentationService.registerHost('
require_text "$desktop_host" 'DesktopPresentationService.unregisterHost('
require_text "$desktop_host" 'WlrLayershell.layer: WlrLayer.Bottom'
require_text "$desktop_host" 'WlrLayershell.exclusionMode: ExclusionMode.Ignore'
require_text "$desktop_host" 'exclusiveZone: 0'
require_text "$desktop_host" 'id: viewport'
require_text "$desktop_host" 'id: cardCanvas'
require_text "$desktop_host" 'Region { item: cardCanvas.inputSlot0 }'
reject_text "$desktop_host" 'item: viewport'
require_text "$sidebar_host" 'WlrLayershell.layer: WlrLayer.Top'
require_text "$sidebar_host" 'WlrLayershell.exclusionMode: ExclusionMode.Normal'

presentation_scene=$(sed -n '/id: viewport/,/^        Connections {/p' \
    "$desktop_host")
printf '%s\n' "$presentation_scene" \
    | grep -Fq -- 'id: cardCanvas' \
    || fail "DesktopCardCanvas is not inside the presentation viewport"
printf '%s\n' "$presentation_scene" \
    | grep -Fq -- 'id: presentationGhost' \
    || fail "DragGhost is not inside the presentation viewport"

# The Canvas is fixed to output-local screen coordinates. Coordinate space is
# selected by state, not inferred from wallpaper mode in every binding.
require_text "$canvas" 'x: 0'
require_text "$canvas" 'y: 0'
require_text "$canvas" 'property bool wallpaperTransitionActive: false'
require_text "$canvas" 'readonly property string placementSpace:'
require_text "$canvas" 'readonly property var screenTarget:'
require_text "$canvas" 'readonly property var wallpaperTarget:'
require_text "$canvas" 'function beginWallpaperTransition()'
require_text "$canvas" 'function promoteCardsToScreen()'
require_text "$canvas" 'function prepareHandoff()'
require_text "$canvas" 'visible: active && !slot.waitingForVisualHandoff'
require_text "$canvas" 'function onHandoffCheckRequested(tileId)'
reject_text "$canvas" 'function onTransferCommittedChanged()'
reject_text "$canvas" 'onWaitingForVisualHandoffChanged:'
reject_text "$canvas" 'presentationOffset'
reject_text "$canvas" 'handoffPinned'
reject_text "$canvas" 'handoffSourceRect'
reject_text "$canvas" 'syncPinnedPresentation'
reject_text "$canvas" 'FrameAnimation {'
reject_text "$canvas" 'DesktopCardPresentation'

# A free card never reads scene offsets. User dragging always writes screen
# coordinates; wallpaper cards are moved only by the solver/projection path.
require_text "$desktop_card" 'setDesktopScreenPosition('
reject_text "$desktop_card" 'screenToWallpaper('
reject_text "$desktop_card" 'targetWallpaperX'
reject_text "$desktop_card" 'targetWallpaperY'
require_text "$desktop_card" 'root.placementController.beginCardDrag()'

# Automatic layout consumes wallpaper coordinates and explicitly starts the
# screen -> wallpaper transition after solving.
require_text "$desktop_host" 'state.desktop.wallpaper.xNorm'
require_text "$desktop_host" 'cardCanvas.startAutomaticTransitions();'
require_text "$desktop_host" 'cardCanvas.promoteCardsToScreen();'
require_text "$desktop_host" 'SystemCardDragSession.completeVisualHandoff(tileId)'
reject_text "$desktop_host" 'startPresentationTransition'
reject_text "$desktop_host" 'presentationOffset'

require_text "$state" 'var schemaVersion = 3;'
require_text "$state" 'placementSpace'
require_text "$state" 'screen:'
require_text "$state" 'wallpaper:'
require_text "$placement" 'function normalizedPosition('

# Layer ordering remains wallpaper Background < cards Bottom < normal apps.
require_text "$wallpaper" 'WlrLayershell.layer: WlrLayer.Background'
require_text "$desktop_host" 'WlrLayershell.layer: WlrLayer.Bottom'
require_text "$awww" '"--layer", "background"'
reject_text "$awww" '"--layer", "bottom"'

echo "desktop card handoff architecture tests passed"
