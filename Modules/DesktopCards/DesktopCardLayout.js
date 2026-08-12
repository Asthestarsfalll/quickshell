.pragma library

// Keep layout mode classification in one place.  This file owns geometry and
// collision solving; SystemCardPlacement.js owns the meaning of each mode.
Qt.include("../SystemCards/SystemCardPlacement.js");

var desktopCardGap = 12;
var desktopCardEdgeInset = 24;

function safeNumber(value, fallback) {
    const number = Number(value);
    return isFinite(number) ? number : fallback;
}

function clamp(value, minimum, maximum) {
    return Math.max(minimum, Math.min(maximum, value));
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
            safeNumber(card.width, 1), Math.max(1, canvasWidth))),
        height: Math.max(1, Math.min(
            safeNumber(card.height, 1), Math.max(1, canvasHeight)))
    };
}

function safeInset(canvasWidth, canvasHeight, size, inset) {
    const requested = Math.max(0, Number(inset) || 0);
    const availableX = Math.max(0, canvasWidth - size.width);
    const availableY = Math.max(0, canvasHeight - size.height);
    return Math.min(requested, availableX / 2, availableY / 2);
}

function rectAt(card, x, y, canvasWidth, canvasHeight, inset) {
    const size = boundedSize(card, canvasWidth, canvasHeight);
    const edge = safeInset(canvasWidth, canvasHeight, size, inset || 0);
    return {
        id: String(card.id),
        x: clamp(Number(x) || 0, edge,
            Math.max(edge, canvasWidth - edge - size.width)),
        y: clamp(Number(y) || 0, edge,
            Math.max(edge, canvasHeight - edge - size.height)),
        width: size.width,
        height: size.height
    };
}

function rectsOverlap(first, second, gap) {
    if (!first || !second)
        return false;
    const padding = Math.max(0, Number(gap) || 0);
    return first.x < second.x + second.width + padding
        && first.x + first.width + padding > second.x
        && first.y < second.y + second.height + padding
        && first.y + first.height + padding > second.y;
}

function overlapsAny(rect, occupied, gap) {
    const list = Array.isArray(occupied) ? occupied : [];
    for (let index = 0; index < list.length; index += 1) {
        if (rectsOverlap(rect, list[index], gap))
            return true;
    }
    return false;
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
        current.yNorm * canvasHeight, 0);
    add(0, 0, 1);
    add(maxX, 0, 2);
    add(0, maxY, 3);
    add(maxX, maxY, 4);
    add((canvasWidth - size.width) / 2,
        (canvasHeight - size.height) / 2, 5);

    const step = Math.max(24, Math.min(size.width, size.height) * 0.42);
    let rank = 10;
    for (let y = 0; y <= maxY + 1; y += step) {
        for (let x = 0; x <= maxX + 1; x += step) {
            add(x, y, rank);
            rank += 1;
        }
    }
    return points;
}

function busyScore(analysis, rect) {
    if (!analysis || !analysis.valid
            || typeof analysis.busyScore !== "function")
        return 0;
    const score = Number(analysis.busyScore(
        rect.x, rect.y, rect.width, rect.height));
    return isFinite(score) ? clamp(score, 0, 1) : 0;
}

function edgePenalty(rect, canvasWidth, canvasHeight) {
    const edgeDistance = Math.min(
        rect.x,
        rect.y,
        canvasWidth - rect.x - rect.width,
        canvasHeight - rect.y - rect.height
    ) / Math.max(1, Math.min(canvasWidth, canvasHeight));
    return Math.max(0, 0.08 - edgeDistance) * 0.02;
}

function movementPenalty(card, point, canvasWidth, canvasHeight) {
    const current = normalizedPosition(card);
    const dx = point.x / Math.max(1, canvasWidth) - current.xNorm;
    const dy = point.y / Math.max(1, canvasHeight) - current.yNorm;
    return (dx * dx + dy * dy) * 0.0005;
}

function candidateCost(card, point, rect, analysis, canvasWidth,
                      canvasHeight, mode) {
    const score = busyScore(analysis, rect);
    const wallpaperCost = mode === "mostBusy" ? -score : score;
    return wallpaperCost
        + edgePenalty(rect, canvasWidth, canvasHeight)
        + movementPenalty(card, point, canvasWidth, canvasHeight)
        + point.rank * 0.000000001;
}

function placeWallpaperCard(card, occupied, canvasWidth, canvasHeight,
                            analysis, gap, mode) {
    const candidates = candidatePoints(card, canvasWidth, canvasHeight);
    const scored = [];
    for (let index = 0; index < candidates.length; index += 1) {
        const point = candidates[index];
        const rect = rectAt(
            card, point.x, point.y, canvasWidth, canvasHeight, 0);
        if (overlapsAny(rect, occupied, gap))
            continue;
        scored.push({
            point: point,
            rect: rect,
            cost: candidateCost(
                card, point, rect, analysis,
                canvasWidth, canvasHeight, mode)
        });
    }

    scored.sort(function(first, second) {
        return first.cost - second.cost;
    });
    if (scored.length > 0)
        return scored[0];

    // The normal grid is intentionally sparse. Search narrow holes before
    // falling back to a deterministic bounded point.
    const size = boundedSize(card, canvasWidth, canvasHeight);
    const maxX = Math.max(0, canvasWidth - size.width);
    const maxY = Math.max(0, canvasHeight - size.height);
    const fallbackStep = Math.max(1, Math.floor(
        Math.min(size.width, size.height) / 4));
    for (let y = 0; y <= maxY + 1; y += fallbackStep) {
        for (let x = 0; x <= maxX + 1; x += fallbackStep) {
            const rect = rectAt(card, x, y, canvasWidth, canvasHeight, 0);
            if (!overlapsAny(rect, occupied, gap)) {
                return {
                    point: { x: rect.x, y: rect.y, rank: 0 },
                    rect: rect,
                    cost: candidateCost(
                        card, { x: rect.x, y: rect.y, rank: 0 }, rect,
                        analysis, canvasWidth, canvasHeight, mode)
                };
            }
        }
    }
    // If the canvas cannot fit the remaining card even at zero gap, keep a
    // stable bounded target instead of dropping the card from the result.
    const fallbackPoint = candidates.length > 0
        ? candidates[0] : { x: 0, y: 0, rank: 0 };
    const fallbackRect = rectAt(
        card, fallbackPoint.x, fallbackPoint.y,
        canvasWidth, canvasHeight, 0);
    return {
        point: fallbackPoint,
        rect: fallbackRect,
        cost: candidateCost(
            card, fallbackPoint, fallbackRect, analysis,
            canvasWidth, canvasHeight, mode)
    };
}

function sortedCards(cards) {
    const source = Array.isArray(cards) ? cards.slice() : [];
    source.sort(function(first, second) {
        const areaDifference = safeNumber(second.width, 0)
            * safeNumber(second.height, 0)
            - safeNumber(first.width, 0) * safeNumber(first.height, 0);
        if (areaDifference !== 0)
            return areaDifference;
        return String(first.id).localeCompare(String(second.id));
    });
    return source;
}

function solve(cards, canvasWidth, canvasHeight, analysis, mode) {
    const safeWidth = Math.max(1, safeNumber(canvasWidth, 1));
    const safeHeight = Math.max(1, safeNumber(canvasHeight, 1));
    const selectedMode = String(mode || "");
    if (!isWallpaperLayoutMode(selectedMode))
        return [];

    const occupied = [];
    const placements = [];
    sortedCards(cards).forEach(function(card) {
        const placed = placeWallpaperCard(
            card, occupied, safeWidth, safeHeight, analysis,
            desktopCardGap, selectedMode);
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

function anchorPoint(mode, card, canvasWidth, canvasHeight) {
    const size = boundedSize(card, canvasWidth, canvasHeight);
    const edge = safeInset(
        canvasWidth, canvasHeight, size, desktopCardEdgeInset);
    const maxX = Math.max(edge, canvasWidth - edge - size.width);
    const maxY = Math.max(edge, canvasHeight - edge - size.height);
    switch (String(mode || "")) {
    case "screenTopRight":
        return { x: maxX, y: edge };
    case "screenBottomLeft":
        return { x: edge, y: maxY };
    case "screenBottomRight":
        return { x: maxX, y: maxY };
    case "screenCenter":
        return {
            x: (canvasWidth - size.width) / 2,
            y: (canvasHeight - size.height) / 2
        };
    case "screenTopLeft":
    default:
        return { x: edge, y: edge };
    }
}

function screenCandidatePoints(card, canvasWidth, canvasHeight, mode) {
    const size = boundedSize(card, canvasWidth, canvasHeight);
    const edge = safeInset(
        canvasWidth, canvasHeight, size, desktopCardEdgeInset);
    const maxX = Math.max(edge, canvasWidth - edge - size.width);
    const maxY = Math.max(edge, canvasHeight - edge - size.height);
    const anchor = anchorPoint(mode, card, canvasWidth, canvasHeight);
    const points = [];
    const seen = {};

    function add(x, y, rank) {
        const point = {
            x: clamp(x, edge, maxX),
            y: clamp(y, edge, maxY),
            rank: rank
        };
        const key = Math.round(point.x) + ":" + Math.round(point.y);
        if (seen[key])
            return;
        seen[key] = true;
        points.push(point);
    }

    add(anchor.x, anchor.y, 0);
    add(edge, edge, 1);
    add(maxX, edge, 2);
    add(edge, maxY, 3);
    add(maxX, maxY, 4);
    add((canvasWidth - size.width) / 2,
        (canvasHeight - size.height) / 2, 5);

    const step = Math.max(24, Math.min(size.width, size.height) * 0.42);
    let rank = 10;
    for (let y = edge; y <= maxY + 1; y += step) {
        for (let x = edge; x <= maxX + 1; x += step) {
            add(x, y, rank);
            rank += 1;
        }
    }
    return points;
}

function screenDistance(point, anchor, width, height) {
    const dx = (point.x - anchor.x) / Math.max(1, width);
    const dy = (point.y - anchor.y) / Math.max(1, height);
    return dx * dx + dy * dy;
}

function screenCandidateCost(card, point, anchor, width, height) {
    const current = normalizedPosition(card);
    const movementX = point.x / Math.max(1, width) - current.xNorm;
    const movementY = point.y / Math.max(1, height) - current.yNorm;
    return screenDistance(point, anchor, width, height)
        + (movementX * movementX + movementY * movementY) * 0.0005
        + point.rank * 0.000000001;
}

function placeScreenCard(card, occupied, canvasWidth, canvasHeight, mode,
                         gap) {
    const anchor = anchorPoint(mode, card, canvasWidth, canvasHeight);
    const candidates = screenCandidatePoints(
        card, canvasWidth, canvasHeight, mode);
    const scored = [];
    candidates.forEach(function(point) {
        const rect = rectAt(
            card, point.x, point.y, canvasWidth, canvasHeight,
            desktopCardEdgeInset);
        if (overlapsAny(rect, occupied, gap))
            return;
        scored.push({
            point: point,
            rect: rect,
            cost: screenCandidateCost(
                card, point, anchor, canvasWidth, canvasHeight)
        });
    });
    scored.sort(function(first, second) {
        return first.cost - second.cost;
    });
    if (scored.length > 0)
        return scored[0];
    const fallback = anchorPoint(mode, card, canvasWidth, canvasHeight);
    const fallbackRect = rectAt(
        card, fallback.x, fallback.y, canvasWidth, canvasHeight,
        desktopCardEdgeInset);
    // A very small output may be mathematically over capacity. Preserve a
    // deterministic bounded delegate rather than omitting an active card.
    return {
        point: fallback,
        rect: fallbackRect,
        cost: 0
    };
}

function solveScreenWithGap(cards, canvasWidth, canvasHeight, mode, gap) {
    const occupied = [];
    const placements = [];
    sortedCards(cards).forEach(function(card) {
        const placed = placeScreenCard(
            card, occupied, canvasWidth, canvasHeight, mode, gap);
        if (!placed)
            return;
        occupied.push(placed.rect);
        placements.push({
            id: String(card.id),
            xNorm: clamp(placed.rect.x / canvasWidth, 0, 1),
            yNorm: clamp(placed.rect.y / canvasHeight, 0, 1),
            rect: placed.rect
        });
    });
    return placements;
}

function solveScreen(cards, canvasWidth, canvasHeight, mode) {
    const safeWidth = Math.max(1, safeNumber(canvasWidth, 1));
    const safeHeight = Math.max(1, safeNumber(canvasHeight, 1));
    const selectedMode = String(mode || "");
    if (!isScreenLayoutMode(selectedMode))
        return [];
    let placements = solveScreenWithGap(
        cards, safeWidth, safeHeight, selectedMode, desktopCardGap);
    if (placements.length !== (Array.isArray(cards) ? cards.length : 0)) {
        // Very small outputs may not have room for the preferred gap. Keep
        // the layout deterministic and prioritize non-overlap over spacing.
        placements = solveScreenWithGap(
            cards, safeWidth, safeHeight, selectedMode, 0);
    }
    return placements;
}

function movementDistance(first, second) {
    const dx = Number(first.x) - Number(second.x);
    const dy = Number(first.y) - Number(second.y);
    return dx * dx + dy * dy;
}

function avoidanceCandidates(card, canvasWidth, canvasHeight) {
    const size = boundedSize(card, canvasWidth, canvasHeight);
    const current = rectAt(
        card, card.x, card.y, canvasWidth, canvasHeight, 0);
    const maxX = Math.max(current.x, canvasWidth - size.width);
    const maxY = Math.max(current.y, canvasHeight - size.height);
    const points = [{ x: current.x, y: current.y, rank: 0 }];
    const step = Math.max(18, Math.min(size.width, size.height) * 0.35);
    for (let radius = 1; radius <= 8; radius += 1) {
        points.push(
            { x: current.x - radius * step, y: current.y, rank: radius },
            { x: current.x + radius * step, y: current.y, rank: radius },
            { x: current.x, y: current.y - radius * step, rank: radius },
            { x: current.x, y: current.y + radius * step, rank: radius },
            { x: current.x - radius * step,
                y: current.y - radius * step, rank: radius },
            { x: current.x + radius * step,
                y: current.y + radius * step, rank: radius },
            { x: current.x - radius * step,
                y: current.y + radius * step, rank: radius },
            { x: current.x + radius * step,
                y: current.y - radius * step, rank: radius }
        );
    }
    points.push(
        { x: 0, y: 0, rank: 20 },
        { x: maxX, y: 0, rank: 21 },
        { x: 0, y: maxY, rank: 22 },
        { x: maxX, y: maxY, rank: 23 }
    );
    return points;
}

function nearestFreePosition(card, occupied, canvasWidth, canvasHeight,
                             gap) {
    const candidates = avoidanceCandidates(
        card, canvasWidth, canvasHeight);
    const scored = [];
    candidates.forEach(function(point) {
        const rect = rectAt(
            card, point.x, point.y, canvasWidth, canvasHeight, 0);
        if (overlapsAny(rect, occupied, gap))
            return;
        scored.push({
            rect: rect,
            cost: movementDistance(rect, card)
                + point.rank * 0.000001
        });
    });
    scored.sort(function(first, second) {
        return first.cost - second.cost;
    });
    return scored.length > 0 ? scored[0].rect : null;
}

// The dragged card is authoritative. Every other card is an avoider. The
// result is runtime-only screen geometry; callers decide when to batch commit
// it to the persistent CardState.
function resolveDraggedCollision(cards, draggedId, draggedRect,
                                 canvasWidth, canvasHeight) {
    const source = Array.isArray(cards) ? cards.slice() : [];
    const positions = {};
    source.forEach(function(card) {
        const rect = rectAt(
            card, card.x, card.y, canvasWidth, canvasHeight,
            0);
        positions[String(card.id)] = rect;
    });
    const id = String(draggedId || "");
    if (!positions[id])
        return [];
    positions[id] = rectAt(
        { id: id, width: draggedRect.width, height: draggedRect.height },
        draggedRect.x, draggedRect.y, canvasWidth, canvasHeight,
        0);

    const queue = [id];
    const maxIterations = Math.max(1, source.length * source.length * 4);
    let iterations = 0;
    while (queue.length > 0 && iterations < maxIterations) {
        const sourceId = queue.shift();
        const sourceRect = positions[sourceId];
        source.forEach(function(card) {
            const otherId = String(card.id);
            if (otherId === id || otherId === sourceId)
                return;
            const other = positions[otherId];
            if (!rectsOverlap(sourceRect, other, desktopCardGap))
                return;

            const occupied = [];
            Object.keys(positions).forEach(function(occupiedId) {
                if (occupiedId !== otherId)
                    occupied.push(positions[occupiedId]);
            });
            const moved = nearestFreePosition(
                { id: otherId, width: other.width, height: other.height,
                    x: other.x, y: other.y },
                occupied, canvasWidth, canvasHeight, desktopCardGap)
                || nearestFreePosition(
                    { id: otherId, width: other.width, height: other.height,
                        x: other.x, y: other.y },
                    occupied, canvasWidth, canvasHeight, 0);
            if (!moved)
                return;
            if (Math.abs(moved.x - other.x) < 0.01
                    && Math.abs(moved.y - other.y) < 0.01)
                return;
            positions[otherId] = moved;
            queue.push(otherId);
            iterations += 1;
        });
    }

    return Object.keys(positions).sort().map(function(cardId) {
        const rect = positions[cardId];
        return {
            id: cardId,
            x: rect.x,
            y: rect.y,
            width: rect.width,
            height: rect.height,
            rect: rect
        };
    });
}

function hasNoOverlap(placements, gap) {
    const list = Array.isArray(placements) ? placements : [];
    for (let first = 0; first < list.length; first += 1) {
        for (let second = first + 1; second < list.length; second += 1) {
            const firstRect = list[first].rect || list[first];
            const secondRect = list[second].rect || list[second];
            if (rectsOverlap(firstRect, secondRect,
                    gap === undefined ? desktopCardGap : gap))
                return false;
        }
    }
    return true;
}
