.pragma library

function safeNumber(value, fallback) {
    const number = Number(value);
    return isFinite(number) ? number : fallback;
}

function clamp(value, minimum, maximum) {
    return Math.max(minimum, Math.min(maximum, value));
}

function rectsOverlap(first, second, gap) {
    const padding = Math.max(0, Number(gap) || 0);
    return first.x < second.x + second.width + padding
        && first.x + first.width + padding > second.x
        && first.y < second.y + second.height + padding
        && first.y + first.height + padding > second.y;
}

function overlapsAny(rect, occupied, gap) {
    for (let index = 0; index < occupied.length; index += 1) {
        if (rectsOverlap(rect, occupied[index], gap))
            return true;
    }
    return false;
}

function normalizedPosition(card) {
    return {
        xNorm: clamp(safeNumber(card.xNorm, 0.5), 0, 1),
        yNorm: clamp(safeNumber(card.yNorm, 0.5), 0, 1)
    };
}

function boundedSize(card, canvasWidth, canvasHeight) {
    return {
        width: Math.max(1, Math.min(
            safeNumber(card.width, 280), Math.max(1, canvasWidth))),
        height: Math.max(1, Math.min(
            safeNumber(card.height, 220), Math.max(1, canvasHeight)))
    };
}

function rectAt(card, x, y, canvasWidth, canvasHeight) {
    const size = boundedSize(card, canvasWidth, canvasHeight);
    return {
        id: String(card.id),
        x: clamp(x, 0, Math.max(0, canvasWidth - size.width)),
        y: clamp(y, 0, Math.max(0, canvasHeight - size.height)),
        width: size.width,
        height: size.height
    };
}

function candidatePoints(card, canvasWidth, canvasHeight) {
    const size = boundedSize(card, canvasWidth, canvasHeight);
    const current = normalizedPosition(card);
    const maxX = Math.max(0, canvasWidth - size.width);
    const maxY = Math.max(0, canvasHeight - size.height);
    const points = [];
    const seen = {};

    function add(x, y, rank) {
        const point = {
            x: clamp(x, 0, maxX),
            y: clamp(y, 0, maxY),
            rank: rank
        };
        const key = Math.round(point.x) + ":" + Math.round(point.y);
        if (seen[key])
            return;
        seen[key] = true;
        points.push(point);
    }

    add(current.xNorm * canvasWidth,
        current.yNorm * canvasHeight, -100000);
    add(0, 0, 0);
    add(maxX, 0, 1);
    add(0, maxY, 2);
    add(maxX, maxY, 3);
    add((canvasWidth - size.width) / 2,
        (canvasHeight - size.height) / 2, 4);

    const step = Math.max(24, Math.min(size.width, size.height) * 0.42);
    for (let y = 0; y <= maxY + 1; y += step) {
        for (let x = 0; x <= maxX + 1; x += step)
            add(x, y, 10 + points.length);
    }
    points.sort(function(first, second) {
        return first.rank - second.rank;
    });
    return points;
}

function busyScore(analysis, rect) {
    if (!analysis || typeof analysis.busyScore !== "function")
        return 0;
    const score = Number(analysis.busyScore(
        rect.x, rect.y, rect.width, rect.height));
    return isFinite(score) ? score : 0;
}

function candidateCost(card, point, rect, analysis, canvasWidth, canvasHeight) {
    const current = normalizedPosition(card);
    const movement = Math.pow(
        (point.x / Math.max(1, canvasWidth)) - current.xNorm, 2)
        + Math.pow(
            (point.y / Math.max(1, canvasHeight)) - current.yNorm, 2);
    const edgeDistance = Math.min(
        rect.x,
        rect.y,
        canvasWidth - rect.x - rect.width,
        canvasHeight - rect.y - rect.height
    ) / Math.max(1, Math.min(canvasWidth, canvasHeight));
    const edgePenalty = Math.max(0, 0.08 - edgeDistance) * 0.25;
    const score = busyScore(analysis, rect);
    let wallpaperCost = 0;
    if (card.mode === "leastBusy")
        wallpaperCost = score;
    else if (card.mode === "mostBusy")
        wallpaperCost = -score;
    return wallpaperCost + movement * 0.035 + edgePenalty
        + point.rank * 0.000001;
}

function placeCard(card, occupied, canvasWidth, canvasHeight, analysis, gap) {
    const candidates = candidatePoints(card, canvasWidth, canvasHeight);
    const scored = [];
    for (let index = 0; index < candidates.length; index += 1) {
        const point = candidates[index];
        const rect = rectAt(
            card, point.x, point.y, canvasWidth, canvasHeight);
        if (overlapsAny(rect, occupied, gap))
            continue;
        scored.push({
            point: point,
            rect: rect,
            cost: card.mode === "free"
                ? point.rank
                : candidateCost(
                    card, point, rect, analysis,
                    canvasWidth, canvasHeight)
        });
    }

    scored.sort(function(first, second) {
        return first.cost - second.cost;
    });
    if (scored.length > 0)
        return scored[0];

    // A valid wallpaper canvas can become crowded after a user resize.  Keep
    // the result deterministic and search every integer row/column before
    // reporting the only possible degraded fallback.
    const size = boundedSize(card, canvasWidth, canvasHeight);
    const maxX = Math.max(0, canvasWidth - size.width);
    const maxY = Math.max(0, canvasHeight - size.height);
    const fallbackStep = Math.max(1, Math.floor(Math.min(
        size.width, size.height) / 4));
    for (let y = 0; y <= maxY + 1; y += fallbackStep) {
        for (let x = 0; x <= maxX + 1; x += fallbackStep) {
            const rect = rectAt(card, x, y, canvasWidth, canvasHeight);
            if (!overlapsAny(rect, occupied, gap))
                return { point: { x: rect.x, y: rect.y }, rect: rect,
                    cost: 0 };
        }
    }
    return null;
}

function solve(cards, canvasWidth, canvasHeight, analysis, focusId) {
    const safeWidth = Math.max(1, safeNumber(canvasWidth, 1));
    const safeHeight = Math.max(1, safeNumber(canvasHeight, 1));
    const source = Array.isArray(cards) ? cards.slice() : [];
    const occupied = [];
    const placements = [];
    const gap = 12;

    // A per-card mode change treats the other cards as fixed obstacles.  A
    // global change or wallpaper reflow leaves focusId empty and runs the
    // full collision-aware solver below.
    if (String(focusId || "") !== "") {
        const focus = source.find(function(card) {
            return String(card.id) === String(focusId);
        });
        if (focus) {
            const fixed = source.filter(function(card) {
                return String(card.id) !== String(focusId);
            });
            fixed.forEach(function(card) {
                const current = normalizedPosition(card);
                const rect = rectAt(
                    card,
                    current.xNorm * safeWidth,
                    current.yNorm * safeHeight,
                    safeWidth,
                    safeHeight
                );
                occupied.push(rect);
                placements.push({
                    id: String(card.id),
                    xNorm: clamp(rect.x / safeWidth, 0, 1),
                    yNorm: clamp(rect.y / safeHeight, 0, 1),
                    rect: rect
                });
            });
            const placedFocus = placeCard(
                focus, occupied, safeWidth, safeHeight, analysis, gap);
            if (placedFocus) {
                placements.push({
                    id: String(focus.id),
                    xNorm: clamp(placedFocus.rect.x / safeWidth, 0, 1),
                    yNorm: clamp(placedFocus.rect.y / safeHeight, 0, 1),
                    rect: placedFocus.rect
                });
                return placements;
            }
            // If the current geometry cannot accommodate the focus card,
            // keep its normalized position rather than moving fixed cards.
            const current = normalizedPosition(focus);
            const rect = rectAt(
                focus,
                current.xNorm * safeWidth,
                current.yNorm * safeHeight,
                safeWidth,
                safeHeight
            );
            placements.push({
                id: String(focus.id),
                xNorm: clamp(rect.x / safeWidth, 0, 1),
                yNorm: clamp(rect.y / safeHeight, 0, 1),
                rect: rect
            });
            return placements;
        }
    }

    // Fixed/free cards become obstacles first.  Within each group, larger
    // cards are placed first so smaller cards can use the remaining holes.
    source.sort(function(first, second) {
        const firstFree = first.mode === "free" ? 0 : 1;
        const secondFree = second.mode === "free" ? 0 : 1;
        if (firstFree !== secondFree)
            return firstFree - secondFree;
        const areaDifference = safeNumber(second.width, 0)
            * safeNumber(second.height, 0)
            - safeNumber(first.width, 0) * safeNumber(first.height, 0);
        if (areaDifference !== 0)
            return areaDifference;
        return String(first.id).localeCompare(String(second.id));
    });

    source.forEach(function(card) {
        const placed = placeCard(
            card, occupied, safeWidth, safeHeight, analysis, gap);
        if (!placed)
            return;
        occupied.push(placed.rect);
        placements.push({
            id: String(card.id),
            xNorm: clamp(placed.rect.x / safeWidth, 0, 1),
            yNorm: clamp(placed.rect.y / safeHeight, 0, 1),
            rect: placed.rect
        });
    });
    return placements;
}

function hasNoOverlap(placements, gap) {
    const list = Array.isArray(placements) ? placements : [];
    for (let first = 0; first < list.length; first += 1) {
        for (let second = first + 1; second < list.length; second += 1) {
            if (rectsOverlap(list[first].rect, list[second].rect, gap || 0))
                return false;
        }
    }
    return true;
}
