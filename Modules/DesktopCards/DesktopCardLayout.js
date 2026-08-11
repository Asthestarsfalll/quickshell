.pragma library

var automaticModes = ["leastBusy", "mostBusy"];

function safeNumber(value, fallback) {
    const number = Number(value);
    return isFinite(number) ? number : fallback;
}

function clamp(value, minimum, maximum) {
    return Math.max(minimum, Math.min(maximum, value));
}

function isAutomaticMode(mode) {
    return automaticModes.indexOf(String(mode || "")) !== -1;
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
            safeNumber(card.width, 1), Math.max(1, canvasWidth))),
        height: Math.max(1, Math.min(
            safeNumber(card.height, 1), Math.max(1, canvasHeight)))
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

    // The current point remains a normal candidate.  It is only a final
    // tie-breaker and never receives a score bonus large enough to override
    // the wallpaper busy signal.
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
    // Keep this deliberately subordinate to real wallpaper scores.
    return Math.max(0, 0.08 - edgeDistance) * 0.02;
}

function movementPenalty(card, point, canvasWidth, canvasHeight) {
    const current = normalizedPosition(card);
    const dx = point.x / Math.max(1, canvasWidth) - current.xNorm;
    const dy = point.y / Math.max(1, canvasHeight) - current.yNorm;
    // A tie-breaker only: realistic busy differences such as 0.018 vs 0.07
    // must always dominate movement preservation.
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

function placeCard(card, occupied, canvasWidth, canvasHeight, analysis,
                   gap, mode) {
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

    // The normal candidate grid is intentionally sparse.  If a large
    // canonical card leaves only a narrow hole, search that hole
    // deterministically before giving up.
    const size = boundedSize(card, canvasWidth, canvasHeight);
    const maxX = Math.max(0, canvasWidth - size.width);
    const maxY = Math.max(0, canvasHeight - size.height);
    const fallbackStep = Math.max(1, Math.floor(
        Math.min(size.width, size.height) / 4));
    for (let y = 0; y <= maxY + 1; y += fallbackStep) {
        for (let x = 0; x <= maxX + 1; x += fallbackStep) {
            const rect = rectAt(card, x, y, canvasWidth, canvasHeight);
            if (!overlapsAny(rect, occupied, gap))
                return { point: { x: rect.x, y: rect.y }, rect: rect,
                    cost: candidateCost(
                        card, { x: rect.x, y: rect.y }, rect, analysis,
                        canvasWidth, canvasHeight, mode) };
        }
    }
    return null;
}

function solve(cards, canvasWidth, canvasHeight, analysis, mode) {
    const safeWidth = Math.max(1, safeNumber(canvasWidth, 1));
    const safeHeight = Math.max(1, safeNumber(canvasHeight, 1));
    const selectedMode = String(mode || "");
    if (!isAutomaticMode(selectedMode))
        return [];

    const source = Array.isArray(cards) ? cards.slice() : [];
    const occupied = [];
    const placements = [];
    const gap = 12;

    // There is one global strategy now.  Larger cards are placed first so
    // the solver does not strand a wide canonical card in a late small gap.
    source.sort(function(first, second) {
        const areaDifference = safeNumber(second.width, 0)
            * safeNumber(second.height, 0)
            - safeNumber(first.width, 0) * safeNumber(first.height, 0);
        if (areaDifference !== 0)
            return areaDifference;
        return String(first.id).localeCompare(String(second.id));
    });

    source.forEach(function(card) {
        const placed = placeCard(
            card, occupied, safeWidth, safeHeight, analysis, gap,
            selectedMode);
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
