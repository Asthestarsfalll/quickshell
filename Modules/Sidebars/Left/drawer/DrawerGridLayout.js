.pragma library

Qt.include("../../../SystemCards/SystemCardCatalog.js");

var columnCount = 3;
var rowCount = 10;
// v6 stored the original fixed-card layout. v7 deliberately stores only the active
// sidebar subset; cards on Desktop are represented by SystemCardState.
var schemaVersion = 7;
var legacySchemaVersion = 6;

function idsFor(activeIds) {
    var requested = Array.isArray(activeIds) ? activeIds : ids();
    var seen = {};
    return ids().filter(function(id) {
        if (requested.indexOf(id) === -1 || seen[id])
            return false;
        seen[id] = true;
        return true;
    });
}

function definitions(activeIds) {
    return sidebarDefinitions(idsFor(activeIds));
}

function tileDefinitionFor(id) {
    return definitionFor(String(id));
}

function cloneTile(tile) {
    return {
        id: String(tile.id),
        column: Number(tile.column),
        row: Number(tile.row),
        columnSpan: Number(tile.columnSpan),
        rowSpan: Number(tile.rowSpan)
    };
}

function maskFor(column, row, columnSpan, rowSpan) {
    var mask = 0;
    for (var y = row; y < row + rowSpan; y += 1) {
        for (var x = column; x < column + columnSpan; x += 1)
            mask |= (1 << (y * columnCount + x));
    }
    return mask;
}

function withinBounds(tile) {
    return Number.isInteger(tile.column)
        && Number.isInteger(tile.row)
        && tile.column >= 0
        && tile.row >= 0
        && tile.column + tile.columnSpan <= columnCount
        && tile.row + tile.rowSpan <= rowCount;
}

function placementFor(layout, id) {
    if (!Array.isArray(layout))
        return null;
    for (var index = 0; index < layout.length; index += 1) {
        if (layout[index].id === id)
            return layout[index];
    }
    return null;
}

function validateLayout(layout, activeIds) {
    var expected = idsFor(activeIds);
    if (!Array.isArray(layout) || layout.length !== expected.length)
        return false;

    var seen = {};
    var occupied = 0;
    for (var index = 0; index < layout.length; index += 1) {
        var tile = layout[index];
        var definition = tileDefinitionFor(tile && tile.id);
        if (!tile || !definition || expected.indexOf(tile.id) === -1
                || seen[tile.id])
            return false;
        if (Number(tile.columnSpan) !== definition.columnSpan
                || Number(tile.rowSpan) !== definition.rowSpan
                || !withinBounds(tile)) {
            return false;
        }
        var mask = maskFor(
            tile.column,
            tile.row,
            tile.columnSpan,
            tile.rowSpan
        );
        if ((occupied & mask) !== 0)
            return false;
        occupied |= mask;
        seen[tile.id] = true;
    }

    for (var expectedIndex = 0;
            expectedIndex < expected.length;
            expectedIndex += 1) {
        if (!seen[expected[expectedIndex]])
            return false;
    }
    return true;
}

function clampAnchor(definition, column, row) {
    return {
        column: Math.max(
            0,
            Math.min(
                columnCount - definition.columnSpan,
                Math.round(Number(column) || 0)
            )
        ),
        row: Math.max(
            0,
            Math.min(
                rowCount - definition.rowSpan,
                Math.round(Number(row) || 0)
            )
        )
    };
}

function preferredAnchor(id, preferredAnchors) {
    var fallback = defaultAnchorFor(id);
    var preferred = preferredAnchors && preferredAnchors[id]
        ? preferredAnchors[id] : fallback;
    return clampAnchor(
        tileDefinitionFor(id),
        preferred.column,
        preferred.row
    );
}

function nearestFree(definition, original, occupied) {
    var candidates = [];
    for (var row = 0; row <= rowCount - definition.rowSpan; row += 1) {
        for (var column = 0;
                column <= columnCount - definition.columnSpan;
                column += 1) {
            var mask = maskFor(
                column,
                row,
                definition.columnSpan,
                definition.rowSpan
            );
            if ((occupied & mask) !== 0)
                continue;
            candidates.push({
                column: column,
                row: row,
                mask: mask,
                cost: (Math.abs(column - original.column)
                    + Math.abs(row - original.row)) * 1000
                    + row * columnCount + column
            });
        }
    }
    candidates.sort(function(left, right) {
        return left.cost - right.cost;
    });
    return candidates.length > 0 ? candidates[0] : null;
}

function defaultLayout(activeIds, preferredAnchors) {
    var expected = idsFor(activeIds);
    var layout = [];
    var occupied = 0;
    for (var index = 0; index < expected.length; index += 1) {
        var id = expected[index];
        var definition = tileDefinitionFor(id);
        var anchor = preferredAnchor(id, preferredAnchors);
        var candidate = nearestFree(definition, anchor, occupied);
        if (!candidate)
            return [];
        layout.push({
            id: id,
            column: candidate.column,
            row: candidate.row,
            columnSpan: definition.columnSpan,
            rowSpan: definition.rowSpan
        });
        occupied |= candidate.mask;
    }
    return layout;
}

function hydrateSaved(savedLayout, activeIds, preferredAnchors) {
    var expected = idsFor(activeIds);
    var fallback = defaultLayout(expected, preferredAnchors);
    if (!savedLayout
            || (Number(savedLayout.version) !== schemaVersion
                && Number(savedLayout.version) !== legacySchemaVersion)
            || !Array.isArray(savedLayout.tiles)) {
        return fallback;
    }

    var anchors = {};
    var savedOccupied = 0;
    for (var index = 0; index < savedLayout.tiles.length; index += 1) {
        var saved = savedLayout.tiles[index];
        var savedDefinition = saved && typeof saved.id === "string"
            ? tileDefinitionFor(saved.id) : null;
        var savedColumn = saved ? Number(saved.column) : NaN;
        var savedRow = saved ? Number(saved.row) : NaN;
        if (!saved || !savedDefinition
                || anchors[saved.id]
                || !Number.isInteger(savedColumn)
                || !Number.isInteger(savedRow)) {
            return fallback;
        }
        // A malformed persisted layout must not be silently reinterpreted as
        // a new arrangement.  Partial v7 documents may contain cards that
        // are no longer in this sidebar subset, so only active IDs take part
        // in the bounds/collision validation below.
        if (expected.indexOf(saved.id) !== -1) {
            var savedTile = {
                column: savedColumn,
                row: savedRow,
                columnSpan: savedDefinition.columnSpan,
                rowSpan: savedDefinition.rowSpan
            };
            if (!withinBounds(savedTile))
                return fallback;
            var savedMask = maskFor(
                savedColumn,
                savedRow,
                savedDefinition.columnSpan,
                savedDefinition.rowSpan
            );
            if ((savedOccupied & savedMask) !== 0)
                return fallback;
            savedOccupied |= savedMask;
        }
        anchors[saved.id] = {
            column: savedColumn,
            row: savedRow
        };
    }

    var hydrated = defaultLayout(expected, preferredAnchors);
    // Rebuild in catalog order, honoring saved anchors first and falling back
    // to the card's remembered sidebar anchor when it was absent from v7.
    var occupied = 0;
    var result = [];
    for (var expectedIndex = 0;
            expectedIndex < expected.length;
            expectedIndex += 1) {
        var id = expected[expectedIndex];
        var definition = tileDefinitionFor(id);
        var anchor = anchors[id]
            ? clampAnchor(definition, anchors[id].column, anchors[id].row)
            : preferredAnchor(id, preferredAnchors);
        var candidate = nearestFree(definition, anchor, occupied);
        if (!candidate)
            return fallback;
        result.push({
            id: id,
            column: candidate.column,
            row: candidate.row,
            columnSpan: definition.columnSpan,
            rowSpan: definition.rowSpan
        });
        occupied |= candidate.mask;
    }
    return validateLayout(result, expected) ? result : hydrated;
}

function serializeLayout(layout, activeIds) {
    var expected = idsFor(activeIds);
    var source = validateLayout(layout, expected)
        ? layout
        : defaultLayout(expected);
    return {
        version: schemaVersion,
        tiles: expected.map(function(id) {
            var tile = placementFor(source, id);
            return {
                id: id,
                column: tile.column,
                row: tile.row
            };
        })
    };
}

function serializedLayoutsEqual(first, second, activeIds) {
    return JSON.stringify(serializeLayout(
        hydrateSaved(first, activeIds), activeIds))
        === JSON.stringify(serializeLayout(
            hydrateSaved(second, activeIds), activeIds));
}

function contentRowCount(layout, activeIds) {
    if (!Array.isArray(layout) || layout.length === 0)
        return 1;
    var allowed = Array.isArray(activeIds) ? idsFor(activeIds) : null;
    var lastRow = 0;
    for (var index = 0; index < layout.length; index += 1) {
        var tile = layout[index];
        if (allowed && allowed.indexOf(tile.id) === -1)
            continue;
        lastRow = Math.max(lastRow,
            Number(tile.row) + Number(tile.rowSpan));
    }
    return Math.max(1, Math.min(rowCount, lastRow));
}

function candidatesFor(tile, original) {
    var candidates = [];
    for (var row = 0; row <= rowCount - tile.rowSpan; row += 1) {
        for (var column = 0;
                column <= columnCount - tile.columnSpan;
                column += 1) {
            candidates.push({
                column: column,
                row: row,
                mask: maskFor(
                    column,
                    row,
                    tile.columnSpan,
                    tile.rowSpan
                ),
                cost: (Math.abs(column - original.column)
                    + Math.abs(row - original.row)) * 1000
                    + row * columnCount + column
            });
        }
    }
    candidates.sort(function(left, right) {
        return left.cost - right.cost;
    });
    return candidates;
}

function moveLayout(layout, tileId, targetColumn, targetRow, activeIds) {
    var expected = idsFor(activeIds || (Array.isArray(layout)
        ? layout.map(function(tile) { return tile.id; }) : null));
    var current = validateLayout(layout, expected)
        ? layout.map(cloneTile)
        : defaultLayout(expected);
    var moving = placementFor(current, tileId);
    var definition = tileDefinitionFor(tileId);
    if (!moving || !definition)
        return null;

    var target = clampAnchor(definition, targetColumn, targetRow);
    var fixedMask = maskFor(
        target.column,
        target.row,
        definition.columnSpan,
        definition.rowSpan
    );
    var originalById = {};
    current.forEach(function(tile) {
        originalById[tile.id] = tile;
    });
    var remaining = current.filter(function(tile) {
        return tile.id !== tileId;
    });
    remaining.sort(function(first, second) {
        var areaDifference = second.columnSpan * second.rowSpan
            - first.columnSpan * first.rowSpan;
        if (areaDifference !== 0)
            return areaDifference;
        return first.id.localeCompare(second.id);
    });

    var candidateMap = {};
    remaining.forEach(function(tile) {
        candidateMap[tile.id] = candidatesFor(
            tile,
            originalById[tile.id]
        );
    });
    var bestCost = Number.POSITIVE_INFINITY;
    var bestPlacements = null;
    var placements = {};
    var visitedNodes = 0;
    var maximumNodes = 250000;

    function lowerBound(startIndex, occupiedMask) {
        var bound = 0;
        for (var itemIndex = startIndex;
                itemIndex < remaining.length;
                itemIndex += 1) {
            var candidates = candidateMap[remaining[itemIndex].id];
            var found = false;
            for (var candidateIndex = 0;
                    candidateIndex < candidates.length;
                    candidateIndex += 1) {
                if ((occupiedMask & candidates[candidateIndex].mask) === 0) {
                    bound += candidates[candidateIndex].cost;
                    found = true;
                    break;
                }
            }
            if (!found)
                return Number.POSITIVE_INFINITY;
        }
        return bound;
    }

    function search(index, occupiedMask, totalCost) {
        visitedNodes += 1;
        if (visitedNodes > maximumNodes || totalCost >= bestCost)
            return;
        if (index >= remaining.length) {
            bestCost = totalCost;
            bestPlacements = {};
            Object.keys(placements).forEach(function(id) {
                bestPlacements[id] = placements[id];
            });
            return;
        }
        var optimistic = lowerBound(index, occupiedMask);
        if (!isFinite(optimistic) || totalCost + optimistic >= bestCost)
            return;
        var tile = remaining[index];
        var candidates = candidateMap[tile.id];
        for (var candidateIndex = 0;
                candidateIndex < candidates.length;
                candidateIndex += 1) {
            var candidate = candidates[candidateIndex];
            if ((occupiedMask & candidate.mask) !== 0)
                continue;
            placements[tile.id] = candidate;
            search(
                index + 1,
                occupiedMask | candidate.mask,
                totalCost + candidate.cost
            );
            delete placements[tile.id];
        }
    }

    search(0, fixedMask, 0);
    if (!bestPlacements)
        return null;

    var result = expected.map(function(id) {
        var tileDefinition = tileDefinitionFor(id);
        if (id === tileId) {
            return {
                id: id,
                column: target.column,
                row: target.row,
                columnSpan: tileDefinition.columnSpan,
                rowSpan: tileDefinition.rowSpan
            };
        }
        var placement = bestPlacements[id];
        return {
            id: id,
            column: placement.column,
            row: placement.row,
            columnSpan: tileDefinition.columnSpan,
            rowSpan: tileDefinition.rowSpan
        };
    });
    return validateLayout(result, expected) ? result : null;
}
