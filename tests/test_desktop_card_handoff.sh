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

# The singleton owns gesture state. Successful handoff is geometry-driven;
# no timer/frame gate guesses when either visual has rendered.
require_text "$session" 'property string phase:'
require_text "$session" 'function finishTransfer()'
require_text "$session" 'function completeVisualHandoff(cardId)'
require_text "$session" 'function prepareVisualHandoff(cardId)'
require_text "$session" 'visualHandoffPending'
require_text "$session" 'readonly property var frozenGhostRect:'
require_text "$session" 'if (!root.transferCommitted || !root.visualHandoffPending'
require_text "$session" 'preserving committed desktop handoff'
source_change_block=$(sed -n '/onSourceItemChanged:/,/^    }/p' "$session")
if printf '%s\n' "$source_change_block" | grep -Fq 'root.finishGhost'; then
    fail "committed source teardown must not finish the visual handoff"
fi
reject_text "$session" 'Timer {'
reject_text "$session" 'handoffWatchdogTimer'
reject_text "$session" 'ghostCleanupTimer.restart()'
reject_text "$system_view" 'id: transferGhostTimer'
reject_text "$system_view" 'transferGhostTimer.restart()'
reject_text Modules/Sidebars/SidebarHostWindow.qml 'FrameAnimation {'
reject_text "$canvas" 'FrameAnimation {'

# A committed desktop delegate is prepared while the ghost remains the only
# visible owner. Loader readiness and geometry readiness are separate signals.
require_text "$canvas" 'return root.desktopIds.indexOf(String(id)) !== -1;'
reject_text "$canvas" 'SystemCardDragSession.frozen &&'
require_text "$canvas" 'waitingForVisualHandoff'
require_text "$canvas" 'visible: active && !slot.waitingForVisualHandoff'
require_text "$canvas" 'cardLoader.item !== null'
require_text "$canvas" 'signal delegateReady(string tileId)'
require_text "$canvas" 'signal handoffReady(string tileId)'
require_text "$canvas" 'function prepareHandoffPresentation()'
require_text "$canvas" 'function startPresentationTransition(tileId)'
require_text "$canvas" 'id: presentationSettleAnimation'
require_text "$canvas" 'presentationSettleAnimation.restart();'
require_text "$canvas" 'Presentation.rectsWithinTolerance('
require_text "$system_view" 'SystemCardDragSession.markTransferCommitted(tileId);'
require_text "$system_view" 'SystemCardDragSession.prepareVisualHandoff(tileId)'
require_text "$system_view" 'SystemCardDragSession.finishTransfer();'
reject_text "$system_view" 'pendingDesktopTransfer'
require_text "$desktop_host" 'function onDelegateReady()'
require_text "$desktop_host" 'function onHandoffReady(tileId)'
require_text "$desktop_host" 'SystemCardDragSession.completeVisualHandoff(tileId)'
require_text "$desktop_host" 'cardCanvas.startPresentationTransition(tileId);'
reject_text "$desktop_host" 'function onCardPresented'
require_text Modules/Sidebars/SidebarHostWindow.qml \
    'hideSource: SystemCardDragSession.sourceItem !== null'
require_text Modules/DesktopCards/DesktopCard.qml \
    'const visualWallpaperPoint = root.scene.screenToWallpaper('

# Canvas is fixed screen-space. Wallpaper motion is a direct projection input
# on each card and never enters the layout Behavior or moves an ancestor.
require_text "$canvas" 'x: 0'
require_text "$canvas" 'y: 0'
reject_text "$canvas" 'x: root.scene ? root.scene.animatedOffsetX'
reject_text "$canvas" 'y: root.scene ? root.scene.animatedOffsetY'
require_text "$canvas" 'readonly property real projectedScreenX:'
require_text "$canvas" '+ Number(root.scene ? root.scene.animatedOffsetX : 0)'
require_text "$canvas" 'x: slot.dragging'
require_text "$canvas" ': slot.projectedScreenX + slot.presentationOffsetX'
require_text "$canvas" 'Behavior on layoutWallpaperX {'
require_text "$canvas" 'Behavior on layoutWallpaperY {'
reject_text "$canvas" 'Behavior on x {'
reject_text "$canvas" 'Behavior on y {'
reject_text "$canvas" 'syncPinnedPresentation'
reject_text "$canvas" 'handoffPinned'
reject_text "$canvas" 'handoffSourceRect'

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
