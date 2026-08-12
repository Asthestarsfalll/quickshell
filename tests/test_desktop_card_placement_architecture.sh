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
geometry=Modules/SystemCards/SystemCardGeometry.js
state=Modules/SystemCards/SystemCardState.js
service=Services/SystemCardService.qml
desktop_card=Modules/DesktopCards/DesktopCard.qml
canvas=Modules/DesktopCards/DesktopCardCanvas.qml
host=Modules/DesktopCards/DesktopCardHost.qml
solver=Modules/DesktopCards/DesktopCardLayout.js
scene=Services/WallpaperSceneService.qml
wallpaper=Modules/Wallpaper/DesktopWallpaper.qml
analyzer=core/plugin/desktopcards/src/wallpaper_analyzer.cpp

# Geometry is defined once from sidebar spans and consumed by both surfaces.
reject_text "$catalog" 'desktopWidth'
reject_text "$catalog" 'desktopHeight'
require_text "$geometry" 'var baseCellWidth = 152;'
require_text "$geometry" 'var baseCellHeight = 160;'
require_text "$service" 'return Geometry.sizeFor(String(cardId));'
require_text "$canvas" 'SystemCardService.cardSize('
require_text "$host" 'SystemCardService.cardSize(id)'

# The desktop policy is global; per-card mode and focus solving are gone.
require_text "$state" 'var schemaVersion = 3;'
reject_text "$state" 'setDesktopMode'
reject_text "$service" 'setDesktopMode'
reject_text "$desktop_card" 'placementMode'
reject_text "$desktop_card" '最空旷处'
reject_text "$desktop_card" '最密集处'
reject_text "$host" 'pendingLayoutFocusId'

# Desktop coordinates are explicit: screen placement is independent from
# wallpaper placement and automatic modes migrate between them explicitly.
require_text "$canvas" 'property bool positionInitialized: false'
require_text "$canvas" 'slot.positionInitialized = true;'
require_text "$canvas" 'readonly property string placementSpace:'
require_text "$canvas" 'readonly property var screenTarget:'
require_text "$canvas" 'readonly property var wallpaperTarget:'
require_text "$canvas" 'function beginWallpaperTransition()'
require_text "$canvas" 'function promoteCardsToScreen()'
require_text "$host" 'allActiveCardsPresented'
require_text "$host" 'state.desktop.wallpaper.xNorm'
require_text "$service" 'setDesktopScreenPositions(positions)'
require_text "$service" 'setDesktopWallpaperPosition(cardId, xNorm, yNorm)'
require_text "$state" 'screen:'
require_text "$state" 'wallpaper:'
reject_text "$canvas" 'presentationOffsetX'
reject_text "$canvas" 'presentationOffsetY'

# Current position is a normal candidate and cannot carry the old -0.1-scale
# absolute advantage.
reject_text "$solver" '-100000'
require_text "$solver" 'point.rank * 0.000000001'
require_text "$solver" 'movementPenalty'

# Analysis cannot start from a half-updated image size, is unnecessary in
# free mode, and remains allocation-bounded even if a malformed caller slips
# past the QML readiness gate.
require_text "$scene" 'property size imagePixelSize: Qt.size(0, 0)'
require_text "$scene" 'readonly property bool analysisGeometryReady:'
require_text "$wallpaper" 'property: "imagePixelSize"'
reject_text "$host" 'analysisNeeded'
require_text "$host" 'window.layoutMode === "free"'
require_text "$host" 'function scheduleAutomaticLayout()'
require_text "$host" 'property bool automaticLayoutScheduled: false'
require_text "$host" 'Qt.callLater(function() {'
require_text "$host" 'window.scheduleAutomaticLayout();'
require_text "$host" '!window.scene.analysisGeometryReady'
require_text "$analyzer" 'constexpr int kMaximumAnalysisWidth = 4096;'
require_text "$analyzer" 'm_threadPool.setMaxThreadCount(1);'

echo "desktop card placement architecture tests passed"
