.pragma library

// Resolve currentShape "autoShape" to a concrete BarShape for one output, from
// live Niri state. Ordered rules; the first whose configured shape is non-empty
// wins. "" == null == "skip this state, fall through". The caller animates for
// free (BarSurface scalars all have Behaviors).
//
// `niri` is the Niri singleton (or any object with the same readonly props):
//   overviewOpen, focusedOutputName, activeWindowByOutput. The active-window
//   walk lives in NiriState.derive(); this reads the derived result.
// `outputWidth` is this output's logical width (the bar spans the whole
// output, so the caller passes its own width). niri's event stream does not
// emit OutputsChanged at connect, so outputsByName is unreliable for geometry.
function resolve(autoShape, niri, outputName, outputWidth) {
    var pick = function(name) {
        return (typeof name === "string" && name.length > 0) ? name : null;
    };

    // 1. overview  2. unfocused output
    if (niri && niri.overviewOpen) {
        var o = pick(autoShape.overviewShape);
        if (o) return o;
    }
    if (niri && outputName && outputName !== niri.focusedOutputName) {
        var u = pick(autoShape.unfocusedOutputShape);
        if (u) return u;
    }

    // Window state on THIS output's active workspace (derived by the Niri singleton).
    var window = (niri && niri.activeWindowByOutput) ? (niri.activeWindowByOutput[outputName] || null) : null;

    if (!window) {
        var nw = pick(autoShape.noWindowShape);
        if (nw) return nw;
    } else {
        if (window.isFloating) {
            var f = pick(autoShape.floatingWindowShape);
            if (f) return f;
        } else if (isMaximizedColumn(window, outputWidth)) {
            var m = pick(autoShape.maximizedColumnShape);
            if (m) return m;
        }
        var h = pick(autoShape.hasWindowShape);
        if (h) return h;
    }

    // Nothing matched (all relevant fields null) — last resort.
    return pick(autoShape.hasWindowShape) || "fullWidth";
}

// ponytail: width-ratio heuristic; niri 26.04 IPC has no maximized flag, so a
// tiled column whose tile fills ~the whole output width reads as maximized.
// Swap for a real flag if niri exposes one. Ceiling: a manually full-width
// column also matches.
function isMaximizedColumn(window, outputWidth) {
    if (!window || window.isFloating || !window.layout || !window.layout.tile_size) {
        return false;
    }
    if (!outputWidth) {
        return false;
    }
    return window.layout.tile_size[0] >= 0.9 * outputWidth;
}

// ---- self-check: run with `qjs AutoShape.js` or node ----
function _demo() {
    var defaults = {
        noWindowShape: "floating",
        hasWindowShape: "fullWidth",
        floatingWindowShape: "softAttach",
        maximizedColumnShape: "hug",
        overviewShape: "hidden",
        unfocusedOutputShape: ""
    };
    var tiled = { isFloating: false, layout: { tile_size: [800, 1000] } };
    var floating = { isFloating: true, layout: { tile_size: [400, 300] } };
    var maxed = { isFloating: false, layout: { tile_size: [1900, 1000] } };
    var niri = function(extra) {
        var n = {
            overviewOpen: false,
            focusedOutputName: "DP-1",
            activeWindowByOutput: {
                "DP-1": null,
                "DP-2": null
            }
        };
        for (var k in extra) n[k] = extra[k];
        return n;
    };
    // Put a window on the active workspace of `output`.
    var withWindow = function(w, output) {
        output = output || "DP-1";
        var n = niri({});
        n.activeWindowByOutput[output] = w;
        return n;
    };

    var W = 2000; // output logical width
    // rule order: overview beats window state
    var ov = withWindow(tiled); ov.overviewOpen = true;
    assert(resolve(defaults, ov, "DP-1", W) === "hidden", "overview");
    // unfocused output: default "" falls through to THIS output's own window state
    assert(resolve(defaults, withWindow(tiled, "DP-2"), "DP-2", W) === "fullWidth", "unfocused null falls through");
    // unfocused output: when set, wins over window state
    var d2 = Object.assign({}, defaults, { unfocusedOutputShape: "hug" });
    assert(resolve(d2, withWindow(tiled, "DP-2"), "DP-2", W) === "hug", "unfocused set");
    // no window
    assert(resolve(defaults, niri({}), "DP-1", W) === "floating", "no window");
    // floating focused
    assert(resolve(defaults, withWindow(floating), "DP-1", W) === "softAttach", "floating");
    // maximized column (width heuristic)
    assert(resolve(defaults, withWindow(maxed), "DP-1", W) === "hug", "maximized");
    // maximized column but output width unknown -> falls through to hasWindowShape
    assert(resolve(defaults, withWindow(maxed), "DP-1", 0) === "fullWidth", "maximized needs width");
    // normal tiled window
    assert(resolve(defaults, withWindow(tiled), "DP-1", W) === "fullWidth", "has window");
    // null fall-through: floating field null -> hasWindowShape
    var d3 = Object.assign({}, defaults, { floatingWindowShape: "" });
    assert(resolve(d3, withWindow(floating), "DP-1", W) === "fullWidth", "floating null falls through");

    console.log("AutoShape: all checks passed");
}

function assert(cond, msg) {
    if (!cond) throw new Error("AutoShape check failed: " + msg);
}

if (typeof require !== "undefined" && typeof module !== "undefined" && require.main === module) {
    _demo();
} else if (typeof scriptArgs !== "undefined") {
    _demo();
}
