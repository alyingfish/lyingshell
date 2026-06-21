import QtQuick
import QtQuick.Shapes
import Qcm.Material as MD
import qs.Commons.Settings

// Animated Bar background surface. One CurveRenderer Shape whose path, MD3
// elevation shadow, and fill opacity are driven by scalar properties. Each
// scalar binds to the active shape's target value AND has a Behavior, so
// switching `Settings.options.bar.currentShape` morphs smoothly. The `hug` shape
// extends its bottom-left/right edges downward and closes them with inner
// reversed (concave) fillets. `blurSigma`/`blurEnabled` feed the owner window's
// BackgroundEffect (best-effort; a no-op where the compositor lacks
// ext-background-effect-v1, e.g. current Niri).
Item {
    id: root

    // Bar thickness (content band height) supplied by the owning window.
    property real barHeight: 32

    readonly property string shape: Settings.options.bar.currentShape
    readonly property var shapeOptions: Settings.options.bar.shape
    readonly property bool isHidden: shape === "hidden"

    // Discrete per-shape geometry target, re-resolved when shape/settings change.
    readonly property var config: resolveConfig(shape)

    // Extra vertical room kept below the bar so the elevation shadow (and, in
    // PR3, the hug overhang) is not clipped by the layer surface.
    readonly property real shadowBuffer: 24

    // ---- Animated scalars (binding target + Behavior == smooth morph) ----
    property real animMargin: config.margin
    property real animTopRadius: config.topRadius
    property real animBottomRadius: config.bottomRadius
    property real animReversed: config.reversed
    property real animOpacity: config.opacity
    property real animElevation: config.shadow ? MD.Token.elevation.level2 : MD.Token.elevation.level0
    property real revealOffset: isHidden ? -(animMargin + barHeight + shadowBuffer + 8) : 0

    // Best-effort background blur (compositor effect; not animated).
    readonly property real blurSigma: config.blur
    readonly property bool blurEnabled: blurSigma > 0

    Behavior on animMargin { NumberAnimation { duration: MD.Token.duration.medium2; easing: MD.Token.easing.emphasized } }
    Behavior on animTopRadius { NumberAnimation { duration: MD.Token.duration.medium2; easing: MD.Token.easing.emphasized } }
    Behavior on animBottomRadius { NumberAnimation { duration: MD.Token.duration.medium2; easing: MD.Token.easing.emphasized } }
    Behavior on animReversed { NumberAnimation { duration: MD.Token.duration.medium2; easing: MD.Token.easing.emphasized } }
    Behavior on animOpacity { NumberAnimation { duration: MD.Token.duration.medium2; easing: MD.Token.easing.standard } }
    Behavior on animElevation { NumberAnimation { duration: MD.Token.duration.medium2; easing: MD.Token.easing.emphasized } }
    Behavior on revealOffset { NumberAnimation { duration: MD.Token.duration.long2; easing: MD.Token.easing.emphasized } }

    // ---- Derived surface rectangle within this item ----
    // Keep room below the bar for the shadow and the hug overhang. Uses the
    // discrete target (not the animated value) so the window resizes once per
    // shape switch rather than every animation frame.
    readonly property real totalHeight: animMargin + barHeight + Math.max(shadowBuffer, config.reversed + 4)
    readonly property real surfaceX: animMargin
    readonly property real surfaceY: animMargin + revealOffset
    readonly property real surfaceWidth: Math.max(0, width - animMargin * 2)
    readonly property real surfaceHeight: barHeight

    function resolveConfig(name) {
        const o = shapeOptions;
        switch (name) {
        case "floating":
            return { margin: o.floating.margin, topRadius: o.floating.cornerRadius,
                bottomRadius: o.floating.cornerRadius, reversed: 0,
                opacity: o.floating.opacity, shadow: o.floating.enableShadow,
                blur: o.floating.blur };
        case "soft-attach":
            return { margin: o.softAttach.margin, topRadius: o.softAttach.topCornerRadius,
                bottomRadius: o.softAttach.bottomCornerRadius, reversed: 0,
                opacity: o.softAttach.opacity, shadow: o.softAttach.enableShadow,
                blur: o.softAttach.blur };
        case "hug":
            return { margin: o.hug.margin, topRadius: 0, bottomRadius: 0,
                reversed: o.hug.reversedCornerRadius,
                opacity: o.hug.opacity, shadow: o.hug.enableShadow,
                blur: o.hug.blur };
        case "hidden":
        case "full-width":
        default:
            return { margin: o.fullWidth.margin, topRadius: o.fullWidth.cornerRadius,
                bottomRadius: o.fullWidth.cornerRadius, reversed: 0,
                opacity: o.fullWidth.opacity, shadow: o.fullWidth.enableShadow,
                blur: o.fullWidth.blur };
        }
    }

    // Clockwise rounded-rect SVG path with independent top/bottom corner radii.
    function rectPath(w, h, tl, tr, br, bl) {
        const maxR = Math.min(w, h) / 2;
        tl = Math.max(0, Math.min(tl, maxR));
        tr = Math.max(0, Math.min(tr, maxR));
        br = Math.max(0, Math.min(br, maxR));
        bl = Math.max(0, Math.min(bl, maxR));
        let p = "M " + tl + " 0";
        p += " L " + (w - tr) + " 0";
        p += (tr > 0.01) ? (" A " + tr + " " + tr + " 0 0 1 " + w + " " + tr) : (" L " + w + " 0");
        p += " L " + w + " " + (h - br);
        p += (br > 0.01) ? (" A " + br + " " + br + " 0 0 1 " + (w - br) + " " + h) : (" L " + w + " " + h);
        p += " L " + bl + " " + h;
        p += (bl > 0.01) ? (" A " + bl + " " + bl + " 0 0 1 0 " + (h - bl)) : (" L 0 " + h);
        p += " L 0 " + tl;
        p += (tl > 0.01) ? (" A " + tl + " " + tl + " 0 0 1 " + tl + " 0") : (" L 0 0");
        return p + " Z";
    }

    // `hug` path: square top + full width, with the bottom-left/right edges
    // extended downward by `r` and closed with inner reversed (concave) fillets.
    // At r == 0 this collapses to the plain rectangle, so morphing in/out of
    // full-width stays continuous.
    function hugPath(w, h, r) {
        r = Math.max(0, Math.min(r, Math.min(w / 2, h)));
        let p = "M 0 0 L " + w + " 0";
        if (r > 0.01) {
            p += " L " + w + " " + (h + r);
            p += " A " + r + " " + r + " 0 0 0 " + (w - r) + " " + h;
            p += " L " + r + " " + h;
            p += " A " + r + " " + r + " 0 0 0 0 " + (h + r);
        } else {
            p += " L " + w + " " + h + " L 0 " + h;
        }
        return p + " Z";
    }

    function surfacePath(w, h) {
        return animReversed > 0.01
            ? hugPath(w, h, animReversed)
            : rectPath(w, h, animTopRadius, animTopRadius, animBottomRadius, animBottomRadius);
    }

    // MD3 drop shadow behind the surface (hidden at elevation level0).
    MD.Elevation {
        x: root.surfaceX
        y: root.surfaceY
        width: root.surfaceWidth
        height: root.surfaceHeight
        elevation: root.animElevation
        corners: MD.Util.corners(root.animTopRadius, root.animTopRadius,
            root.animBottomRadius, root.animBottomRadius)
    }

    // Surface fill.
    MD.Shape {
        x: root.surfaceX
        y: root.surfaceY
        width: root.surfaceWidth
        height: root.surfaceHeight

        ShapePath {
            readonly property color base: MD.Token.color.surface_container

            strokeWidth: 0
            fillColor: Qt.rgba(base.r, base.g, base.b, root.animOpacity)

            PathSvg {
                path: root.surfacePath(root.surfaceWidth, root.surfaceHeight)
            }
        }
    }
}
