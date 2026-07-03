// Pure pin/partition logic for the Bar system tray. No QML/Quickshell types:
// items are duck-typed { id, title } so tests and callers stay decoupled.
.pragma library

function escapeRegex(text) {
    return String(text).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function pinRegexFor(itemId) {
    return "^" + escapeRegex(itemId) + "$";
}

// Case-insensitive match against the item id or title. Invalid user regexes
// are skipped instead of throwing.
function regexMatchesItem(pattern, item) {
    if (!item)
        return false;
    let regex;
    try {
        regex = new RegExp(pattern, "i");
    } catch (error) {
        return false;
    }
    return regex.test(String(item.id || "")) || regex.test(String(item.title || ""));
}

// Index of the first regex matching the item, -1 when unpinned.
function firstMatchIndex(regexes, item) {
    for (let index = 0; index < regexes.length; index++) {
        if (regexMatchesItem(regexes[index], item))
            return index;
    }
    return -1;
}

// Split tray items into { pinned, overflow }. Pinned order follows the regex
// list order (then service order); overflow follows `order` (a list of item
// ids), with unlisted items after in service order.
function partition(items, regexes, order) {
    const orderIds = order || [];
    const pinned = [];
    const overflow = [];
    for (let index = 0; index < items.length; index++) {
        const item = items[index];
        const match = firstMatchIndex(regexes, item);
        if (match >= 0)
            pinned.push({ item: item, match: match, order: index });
        else
            overflow.push({ item: item, match: orderIds.indexOf(item.id), order: index });
    }
    pinned.sort(function (a, b) {
        return a.match - b.match || a.order - b.order;
    });
    overflow.sort(function (a, b) {
        const am = a.match < 0 ? orderIds.length : a.match;
        const bm = b.match < 0 ? orderIds.length : b.match;
        return am - bm || a.order - b.order;
    });
    return {
        pinned: pinned.map(function (entry) { return entry.item; }),
        overflow: overflow.map(function (entry) { return entry.item; })
    };
}

// New overflowOrder after dropping `item` at `index` among the currently
// displayed overflow `items` (`index` counted with the dragged item still in
// place, as the caret shows it). Snapshots the full displayed order, so stale
// ids self-clean on every drop.
function orderAfterDrop(items, item, index) {
    const ids = items.map(function (other) { return other.id; });
    const current = ids.indexOf(item.id);
    if (current >= 0) {
        ids.splice(current, 1);
        if (index > current)
            index--;
    }
    ids.splice(Math.max(0, Math.min(ids.length, index)), 0, item.id);
    return ids;
}

// Pin `item` so it lands at `index` among the pinned items of `items`
// (index counted with the dragged item excluded). Existing regexes that match
// the item are dropped, then an exact-id regex is inserted before the regex
// pinning the current occupant of `index`, keeping user-authored patterns.
// ponytail: a broad regex shared by several items moves its whole cluster;
// per-item ordering inside one regex needs an explicit order setting.
function pinAt(regexes, items, item, index) {
    const kept = regexes.filter(function (pattern) {
        return !regexMatchesItem(pattern, item);
    });
    const others = items.filter(function (other) {
        return other.id !== item.id;
    });
    const pinnedAfter = partition(others, kept).pinned;
    let insertAt = kept.length;
    const neighbor = pinnedAfter[index];
    if (neighbor !== undefined) {
        const neighborIndex = firstMatchIndex(kept, neighbor);
        if (neighborIndex >= 0)
            insertAt = neighborIndex;
    }
    kept.splice(insertAt, 0, pinRegexFor(item.id));
    return kept;
}

// Drop every regex matching the item.
// ponytail: unpinning an item pinned by a broad regex unpins its siblings too.
function unpin(regexes, item) {
    return regexes.filter(function (pattern) {
        return !regexMatchesItem(pattern, item);
    });
}

// Classify a drag point into a drop target. All coordinates share one space
// (the tray overlay). `geo`:
//   fromPinned: drag origin zone
//   barBottom:  bottom edge of the bar strip
//   button:     { x, width, visible }            overflow button
//   row:        { x, width }                     pinned row
//   pinnedCount, overflowCount: int
//   card:       { x, y, width, height, visible } overflow popover card
//   grid:       { x, y }                         grid origin inside overlay
//   cellWidth, cellHeight: real
// Returns { zone: "pinned"|"unpinBtn"|"overflow"|"blocked", index: int }.
function classifyDrag(x, y, geo) {
    const inBarStrip = y >= 0 && y <= geo.barBottom;

    // Overflow button: unpin target for pinned items. Checked before the
    // pinned zone so its slop is not eaten by the row's left slop.
    if (inBarStrip && geo.button.visible && x >= geo.button.x - 8 && x <= geo.button.x + geo.button.width) {
        return { zone: geo.fromPinned ? "unpinBtn" : "blocked", index: -1 };
    }

    // Pinned zone: the bar strip around the pinned row, with slop.
    const rowWidth = Math.max(geo.row.width + 32, geo.cellWidth + 16);
    if (inBarStrip && x >= geo.row.x - 16 && x <= geo.row.x - 16 + rowWidth) {
        return {
            zone: "pinned",
            index: rowInsertionIndex(x - geo.row.x, geo.cellWidth, 0, geo.pinnedCount)
        };
    }

    // Overflow popover card: unpin target for pinned items; a reorder target
    // for overflow items. Both carry a grid insertion index.
    if (geo.card.visible && x >= geo.card.x && x <= geo.card.x + geo.card.width && y >= geo.card.y && y <= geo.card.y + geo.card.height) {
        return {
            zone: "overflow",
            index: gridInsertionIndex(x - geo.grid.x, y - geo.grid.y, geo.cellWidth, geo.cellHeight, 0, Math.max(1, Math.min(4, geo.overflowCount)), geo.overflowCount)
        };
    }

    return { zone: "blocked", index: -1 };
}

// Insertion index for a horizontal row of `count` uniform cells: 0..count.
// `x` is relative to the first cell's left edge.
function rowInsertionIndex(x, cellWidth, spacing, count) {
    if (count <= 0 || cellWidth <= 0)
        return 0;
    const step = cellWidth + spacing;
    const index = Math.round(x / step);
    return Math.max(0, Math.min(count, index));
}

// Insertion index for a row-major grid with `columns` uniform cells per row.
// `x`/`y` are relative to the first cell's top-left corner. Returns 0..count.
function gridInsertionIndex(x, y, cellWidth, cellHeight, spacing, columns, count) {
    if (count <= 0 || columns <= 0 || cellWidth <= 0 || cellHeight <= 0)
        return 0;
    const rows = Math.ceil(count / columns);
    const row = Math.max(0, Math.min(rows - 1, Math.floor(y / (cellHeight + spacing))));
    const rowStart = row * columns;
    const cellsInRow = Math.min(columns, count - rowStart);
    const column = Math.max(0, Math.min(cellsInRow, Math.round(x / (cellWidth + spacing))));
    return Math.min(count, rowStart + column);
}
