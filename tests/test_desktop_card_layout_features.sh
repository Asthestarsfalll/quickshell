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

catalog=Modules/SystemCards/SystemCardCatalog.js
placement=Modules/SystemCards/SystemCardPlacement.js
animations=Common/Animations.qml
left=Modules/Sidebars/Left/LeftSidebarWindow.qml
right=Modules/Sidebars/Right/RightSidebar.qml
left_content=Modules/Sidebars/Left/LeftSidebarContent.qml
system_view=Modules/Sidebars/Left/SystemView.qml
sidebar_host=Modules/Sidebars/SidebarHostWindow.qml
canvas=Modules/DesktopCards/DesktopCardCanvas.qml
host=Modules/DesktopCards/DesktopCardHost.qml
service=Services/SystemCardService.qml
settings=Modules/ControlCenter/GeneralSidebarPage.qml

require_text "$animations" 'readonly property int sidebarEnter: expressiveFastSpatial'
require_text "$animations" 'readonly property int sidebarExit: small'
require_text "$left" 'Animations.durations.sidebarEnter'
require_text "$left" 'Animations.durations.sidebarExit'
require_text "$right" 'Animations.durations.sidebarEnter'
require_text "$right" 'Animations.durations.sidebarExit'
require_text "$left" 'duration: root.exitDuration'
require_text "$right" 'duration: root.exitDuration'

blur_count=$(grep -c 'excludeHostBlur: true' "$catalog")
[ "$blur_count" -eq 6 ] || fail "expected six transparent host blur metadata entries"
require_text "$system_view" 'systemCardBlurExclusionItems'
require_text "$left_content" 'systemCardBlurExclusionItems'
require_text "$sidebar_host" 'leftSidebar.systemCardBlurExclusionItems'
require_text "$canvas" 'systemCardBlurExclusionItems'
require_text "$host" 'SystemCardService.cardExcludesHostBlur('
reject_text "$sidebar_host" 'timeCardBlurExclusionItem'
reject_text "$canvas" 'timeBlurExclusionItem'

for mode in screenTopLeft screenTopRight screenBottomLeft \
    screenBottomRight screenCenter
do
    require_text "$settings" "$mode"
done
require_text "$placement" 'function isScreenLayoutMode('
require_text "$placement" 'function isWallpaperLayoutMode('
require_text "$placement" 'var desktopLayoutModes = [freeMode]'
require_text "$host" 'DesktopCardLayout.solveScreen('
require_text "$host" 'SystemCardService.isWallpaperLayoutMode('
reject_text "$host" 'window.layoutMode === "free"'
require_text "$host" 'function scheduleDesktopLayout(reason, priorityId)'
require_text "$host" 'function reconcileDesktopLayout(reason)'
require_text "$host" 'window.runScreenLayout();'
require_text "$host" 'window.runWallpaperLayout();'
reject_text "$host" 'Qt.callLater(window.runLayout)'
require_text "$host" 'function runFreeCollisionLayout()'
require_text "$canvas" 'function prepareScreenLayoutTransition('
require_text "$canvas" 'function updateCollisionPreview('
require_text "$canvas" 'function resolveExternalDrop('
require_text "$canvas" 'function resolveCurrentCollisionLayout('
require_text Modules/DesktopCards/DesktopCardLayout.js \
    'function resolveAllCollisions('
reject_text Modules/DesktopCards/DesktopCardLayout.js 'radius <= 8'
require_text "$system_view" \
    'DesktopPresentationService.resolveDropCollision('
require_text "$service" 'function transferToDesktop('
require_text Modules/DesktopCards/DesktopCard.qml \
    'SystemCardService.isFreeLayoutMode('
require_text Modules/DesktopCards/DesktopCard.qml \
    'enabled: root.canDrag'
require_text "$service" 'function setDesktopScreenPositions(positions, requestLayout)'

echo "desktop card layout feature architecture tests passed"
