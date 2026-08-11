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
wallpaper=Modules/Wallpaper/DesktopWallpaper.qml
desktop_host=Modules/DesktopCards/DesktopCardHost.qml
awww=Common/functions/AwwwCommand.js

# The singleton owns visual cleanup; a page Loader must not own the transfer
# timer or strand the global session when SystemView is destroyed.
require_text "$session" 'property string phase:'
require_text "$session" 'function finishTransfer()'
require_text "$session" 'function completeVisualHandoff(cardId)'
require_text "$session" 'function prepareVisualHandoff(cardId)'
require_text "$session" 'visualHandoffPending'
require_text "$session" 'readonly property var frozenGhostRect:'
require_text "$session" 'if (!root.transferCommitted || !root.visualHandoffPending'
require_text "$session" 'Timer {'
require_text "$session" 'id: handoffWatchdogTimer'
reject_text "$session" 'ghostCleanupTimer.restart()'
reject_text "$system_view" 'id: transferGhostTimer'
reject_text "$system_view" 'transferGhostTimer.restart()'

# A committed desktop delegate is prepared while the ghost remains the only
# visible owner. Loader readiness and geometry readiness are separate signals.
require_text "$canvas" 'return root.desktopIds.indexOf(tileId) !== -1;'
reject_text "$canvas" 'SystemCardDragSession.frozen &&'
require_text "$canvas" 'waitingForVisualHandoff'
require_text "$canvas" 'visible: active && !slot.waitingForVisualHandoff'
require_text "$canvas" 'cardLoader.item !== null'
require_text "$canvas" 'signal delegateReady(string tileId)'
require_text "$canvas" 'signal handoffReady(string tileId)'
require_text "$canvas" 'function prepareHandoffPresentation()'
require_text "$canvas" 'function startPresentationTransition(tileId)'
require_text "$canvas" 'id: presentationLayer'
require_text "$canvas" 'id: presentationSettleAnimation'
require_text "$canvas" 'id: handoffFrameGate'
require_text "$canvas" 'FrameAnimation {'
require_text "$canvas" 'handoffFrameGate.start();'
require_text "$canvas" 'presentationSettleAnimation.restart();'
require_text "$canvas" 'property bool handoffPinned: false'
require_text "$canvas" 'function syncPinnedPresentation()'
require_text "$canvas" 'slot.syncPinnedPresentation();'
require_text "$canvas" 'Presentation.rectsWithinTolerance('
require_text "$system_view" 'SystemCardDragSession.markTransferCommitted(id);'
require_text "$system_view" 'SystemCardDragSession.prepareVisualHandoff(id)'
require_text "$system_view" 'SystemCardDragSession.finishTransfer();'
require_text "$system_view" 'function commitPendingDesktopTransfer(tileId)'
require_text "$system_view" 'function onFrozenGhostPresented(tileId)'
require_text "$session" 'signal frozenGhostPresented(string cardId)'
require_text "$session" 'function notifyFrozenGhostPresented()'
require_text "$session" 'function updateFrozenGhostRect(x, y, width, height)'
require_text Modules/Sidebars/SidebarHostWindow.qml \
    'id: frozenGhostFrameGate'
require_text Modules/Sidebars/SidebarHostWindow.qml \
    'if (frameCount < 2)'
require_text Modules/Sidebars/SidebarHostWindow.qml \
    'SystemCardDragSession.updateFrozenGhostRect('
require_text Modules/Sidebars/SidebarHostWindow.qml \
    'systemCardDragGhost.x,'
require_text Modules/Sidebars/SidebarHostWindow.qml \
    'systemCardDragGhost.y,'
reject_text Modules/Sidebars/SidebarHostWindow.qml \
    'systemCardDragGhost.mapToItem(root'
require_text "$desktop_host" 'function onDelegateReady()'
require_text "$desktop_host" 'function onHandoffReady(tileId)'
require_text "$desktop_host" 'SystemCardDragSession.completeVisualHandoff(tileId)'
require_text "$desktop_host" 'cardCanvas.startPresentationTransition(tileId);'
reject_text "$desktop_host" 'function onCardPresented'
require_text Modules/Sidebars/SidebarHostWindow.qml \
    'hideSource: SystemCardDragSession.sourceItem !== null'
require_text Modules/DesktopCards/DesktopCard.qml \
    'const visualWallpaperPoint = root.scene.screenToWallpaper('

# The top-level ghost is a 1:1 visual proxy. Its logical rect is therefore
# the same rect that the wallpaper-space drop calculation persists.
require_text Modules/Sidebars/SidebarHostWindow.qml 'opacity: 1'
require_text Modules/Sidebars/SidebarHostWindow.qml 'scale: 1'
reject_text Modules/Sidebars/SidebarHostWindow.qml 'scale: visible ? 1.025 : 1'
reject_text Modules/Sidebars/SidebarHostWindow.qml 'opacity: 0.96'

# Layer-shell ordering is explicit: wallpaper/awww Background, cards Bottom.
require_text "$wallpaper" 'WlrLayershell.layer: WlrLayer.Background'
require_text "$desktop_host" 'WlrLayershell.layer: WlrLayer.Bottom'
require_text "$awww" '"--layer", "background"'
reject_text "$awww" '"--layer", "bottom"'

echo "desktop card handoff architecture tests passed"
