.pragma library

// Presentation coordinates are transient host/screen coordinates. They must
// never be written back to the wallpaper-space model.
function offsetForRects(sourceRect, targetRect) {
    return {
        x: Number(sourceRect.x) - Number(targetRect.x),
        y: Number(sourceRect.y) - Number(targetRect.y)
    };
}

function projectWallpaperPoint(x, y, sceneOffsetX, sceneOffsetY) {
    return {
        x: Number(x) + Number(sceneOffsetX),
        y: Number(y) + Number(sceneOffsetY)
    };
}

function translatedRect(rect, offset) {
    return {
        x: Number(rect.x) + Number(offset.x),
        y: Number(rect.y) + Number(offset.y),
        width: Number(rect.width),
        height: Number(rect.height)
    };
}

function rectsWithinTolerance(first, second, tolerance) {
    const limit = Math.max(0, Number(tolerance) || 0);
    return Math.abs(Number(first.x) - Number(second.x)) <= limit
        && Math.abs(Number(first.y) - Number(second.y)) <= limit
        && Math.abs(Number(first.width) - Number(second.width)) <= limit
        && Math.abs(Number(first.height) - Number(second.height)) <= limit;
}
