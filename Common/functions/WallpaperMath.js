function clamp01(value) {
    return Math.max(0, Math.min(1, Number(value) || 0));
}

function coverGeometry(screenWidth, screenHeight,
                       imageWidth, imageHeight, preferredScale) {
    const safeScreenWidth = Math.max(1, Number(screenWidth) || 1);
    const safeScreenHeight = Math.max(1, Number(screenHeight) || 1);
    const safeImageWidth = Math.max(1, Number(imageWidth) || 1);
    const safeImageHeight = Math.max(1, Number(imageHeight) || 1);
    const safePreferredScale = Math.max(
        1, Number(preferredScale) || 1);
    const coverScale = Math.max(
        safeScreenWidth / safeImageWidth,
        safeScreenHeight / safeImageHeight);
    const effectiveScale = coverScale * safePreferredScale;
    const scaledWidth = safeImageWidth * effectiveScale;
    const scaledHeight = safeImageHeight * effectiveScale;

    return {
        coverScale: coverScale,
        effectiveScale: effectiveScale,
        scaledWidth: scaledWidth,
        scaledHeight: scaledHeight,
        overflowX: Math.max(0, scaledWidth - safeScreenWidth),
        overflowY: Math.max(0, scaledHeight - safeScreenHeight)
    };
}

function tiledColumnProgress(columnCount, fullSpan) {
    const columns = Math.max(0, Math.round(Number(columnCount) || 0));
    const span = Math.max(2, Math.round(Number(fullSpan) || 6));
    if (columns === 0)
        return 0.5;
    if (columns === 1)
        return 0;
    return clamp01((columns - 1) / (span - 1));
}

function workspaceProgress(workspaces) {
    if (!workspaces || workspaces.length <= 1)
        return 0.5;
    let activePosition = 0;
    for (let index = 0; index < workspaces.length; index += 1) {
        if (workspaces[index].isActive) {
            activePosition = index;
            break;
        }
    }
    return clamp01(activePosition / (workspaces.length - 1));
}

function horizontalProgress(baseProgress, leftOpen, rightOpen,
                            sidebarStep) {
    let result = Number(baseProgress);
    if (!isFinite(result))
        result = 0.5;
    const step = Math.max(0, Number(sidebarStep) || 0);
    if (leftOpen)
        result -= step;
    if (rightOpen)
        result += step;
    return clamp01(result);
}

function wallpaperPosition(overflow, progress) {
    const safeOverflow = Math.max(0, Number(overflow) || 0);
    return -safeOverflow * clamp01(progress);
}
