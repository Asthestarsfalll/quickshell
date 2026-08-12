.pragma library

var screen = "screen";
var wallpaper = "wallpaper";

function clamp(value, minimum, maximum) {
    return Math.max(minimum, Math.min(maximum, Number(value) || 0));
}

function safeDimension(value) {
    return Math.max(1, Number(value) || 1);
}

function normalizedPosition(x, y, width, height) {
    return {
        xNorm: clamp(Number(x) / safeDimension(width), 0, 1),
        yNorm: clamp(Number(y) / safeDimension(height), 0, 1)
    };
}

function screenPoint(xNorm, yNorm, width, height, cardWidth,
                    cardHeight) {
    var safeWidth = safeDimension(width);
    var safeHeight = safeDimension(height);
    var safeCardWidth = Math.max(0, Number(cardWidth) || 0);
    var safeCardHeight = Math.max(0, Number(cardHeight) || 0);
    return {
        x: clamp(Number(xNorm) * safeWidth,
            0, Math.max(0, safeWidth - safeCardWidth)),
        y: clamp(Number(yNorm) * safeHeight,
            0, Math.max(0, safeHeight - safeCardHeight))
    };
}

function wallpaperPoint(xNorm, yNorm, width, height, cardWidth,
                        cardHeight) {
    var safeWidth = safeDimension(width);
    var safeHeight = safeDimension(height);
    var safeCardWidth = Math.max(0, Number(cardWidth) || 0);
    var safeCardHeight = Math.max(0, Number(cardHeight) || 0);
    return {
        x: clamp(Number(xNorm) * safeWidth,
            0, Math.max(0, safeWidth - safeCardWidth)),
        y: clamp(Number(yNorm) * safeHeight,
            0, Math.max(0, safeHeight - safeCardHeight))
    };
}

function projectedWallpaperPoint(x, y, offsetX, offsetY) {
    return {
        x: Number(x) + Number(offsetX || 0),
        y: Number(y) + Number(offsetY || 0)
    };
}

function interpolate(start, target, progress) {
    var amount = clamp(progress, 0, 1);
    return Number(start) + (Number(target) - Number(start)) * amount;
}
