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
system_view=Modules/Sidebars/Left/SystemView.qml
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
require_text "$session" 'readonly property var frozenGhostRect:'
require_text "$session" 'preserving committed desktop handoff'
reject_text "$session" 'Timer {'
reject_text "$session" 'handoffWatchdogTimer'
reject_text "$session" 'ghostCleanupTimer.restart()'

# Every user drop is screen-space. A source teardown cannot clear a committed
# session before the DesktopCard consumes the frozen screen rect.
require_text "$system_view" 'Placement.screen'
reject_text "$system_view" 'screenToWallpaper('
require_text "$system_view" 'SystemCardService.setContainer('
require_text "$system_view" 'SystemCardDragSession.freezeGhost()'
require_text "$system_view" 'SystemCardDragSession.markTransferCommitted(tileId)'
require_text "$system_view" 'SystemCardDragSession.requestVisualHandoffCheck(tileId);'
reject_text "$system_view" 'pendingDesktopTransfer'

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
