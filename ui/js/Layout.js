
// Pure grid maths: no QML, no state, so it can be unit-tested on its own
// (tests/tst_layout.qml). A rect is { x, y, w, h } in grid cells; `bounds`
// is { cols, rows }.

// The size presets every module picks its allowed sizes from.
var presets = {
    S: { w: 4,  h: 4 },
    M: { w: 8,  h: 4 },
    L: { w: 8,  h: 8 },
    W: { w: 12, h: 4 },
    X: { w: 20, h: 4 }        // extra wide: a strip across the middle of the screen
};
var presetOrder = ["S", "M", "L", "W", "X"];

function preset(key) {
    return presets[key] || presets.M;
}

function overlaps(a, b) {
    return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
}

function inside(r, bounds) {
    return r.x >= 0 && r.y >= 0 && r.w > 0 && r.h > 0 && r.x + r.w <= bounds.cols && r.y + r.h <= bounds.rows;
}

// `others` is an array of rects; true when `r` fits the screen and touches none of them.
function canPlace(r, others, bounds) {
    if (!inside(r, bounds))
        return false;
    for (var i = 0; i < others.length; i++)
        if (overlaps(r, others[i]))
            return false;
    return true;
}

function clamp(v, lo, hi) {
    return Math.max(lo, Math.min(hi, v));
}

// Pull a rect back inside the screen (never changes its size).
function clampRect(r, bounds) {
    return {
        x: clamp(r.x, 0, Math.max(0, bounds.cols - r.w)),
        y: clamp(r.y, 0, Math.max(0, bounds.rows - r.h)),
        w: r.w,
        h: r.h
    };
}

// The free position closest to (x, y) for a w×h widget, or null when the
// screen has no room. Distance is measured in cells, so a drop lands next to
// where the pointer let go instead of jumping to the top-left corner.
function findFree(others, w, h, bounds, x, y) {
    var best = null;
    var bestD = 1e9;
    var maxX = bounds.cols - w;
    var maxY = bounds.rows - h;
    for (var cy = 0; cy <= maxY; cy++) {
        for (var cx = 0; cx <= maxX; cx++) {
            var d = (cx - x) * (cx - x) + (cy - y) * (cy - y);
            if (d >= bestD)
                continue;
            if (canPlace({ x: cx, y: cy, w: w, h: h }, others, bounds)) {
                best = { x: cx, y: cy, w: w, h: h };
                bestD = d;
            }
        }
    }
    return best;
}

// The allowed preset whose footprint is closest to a dragged corner (cols × rows).
function nearestPreset(allowed, cols, rows) {
    var best = allowed[0];
    var bestD = 1e9;
    for (var i = 0; i < allowed.length; i++) {
        var p = preset(allowed[i]);
        var d = (p.w - cols) * (p.w - cols) + (p.h - rows) * (p.h - rows);
        if (d < bestD) {
            bestD = d;
            best = allowed[i];
        }
    }
    return best;
}

// Grid dimensions for a screen: whole cells only, never zero.
function boundsFor(width, height, cell) {
    return { cols: Math.max(1, Math.floor(width / cell)), rows: Math.max(1, Math.floor(height / cell)) };
}

// Next id for a widget of this type: "clock-led-1", "clock-led-2", ...
function nextId(type, existing) {
    var n = 1;
    while (existing.indexOf(type + "-" + n) >= 0)
        n++;
    return type + "-" + n;
}

// Puts a list of rects right for one screen, in order: a rect that is off the
// screen is pulled back in, and one that sits on an earlier rect moves to the
// nearest free spot (or stays put when there is none). Returns new rects in the
// same order; sizes never change.
function settle(rects, bounds) {
    var placed = [];
    var out = [];
    for (var i = 0; i < rects.length; i++) {
        var r = rects[i];
        if (!canPlace(r, placed, bounds)) {
            var c = clampRect(r, bounds);
            if (!canPlace(c, placed, bounds))
                c = findFree(placed, r.w, r.h, bounds, c.x, c.y) || c;
            r = c;
        }
        placed.push(r);
        out.push({ x: r.x, y: r.y, w: r.w, h: r.h });
    }
    return out;
}

// The cell that puts a w × h widget in the middle of the screen: { x, y }. With
// an odd number of spare cells it sits half a cell off, rounded down.
function centered(w, h, bounds) {
    return { x: Math.max(0, Math.floor((bounds.cols - w) / 2)), y: Math.max(0, Math.floor((bounds.rows - h) / 2)) };
}
