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

    // The last non-hidden shape, so `hidden` keeps the current geometry while it
    // slides away instead of first morphing to full-width.
    property string lastVisibleShape: "floating"
    onShapeChanged: if (shape !== "hidden") lastVisibleShape = shape

    // Discrete per-shape geometry target, re-resolved when shape/settings change.
    readonly property var config: resolveConfig(isHidden ? lastVisibleShape : shape)

    // Extra vertical room kept below the bar so the elevation shadow and the hug
    // overhang are not clipped by the layer surface. This region is click-through
    // (see Bar.qml mask), so the headroom is free.
    readonly property real shadowBuffer: 24

    // ---- Animated scalars (binding target + Behavior == smooth morph) ----
    property real animMargin: config.margin
    property real animTopRadius: config.topRadius
    property real animBottomRadius: config.bottomRadius
    property real animReversed: config.reversed
    property real animOpacity: config.opacity
    property real revealOffset: isHidden ? -(animMargin + barHeight + shadowBuffer + 8) : 0

    // MD3 elevation (dp) of the bar's drop shadow, user-configurable per shape
    // via Settings.options.bar.shape.<shape>.elevation. Feeds QmlMaterial's
    // RRectShadowImpl (the Skia ambient + spot light shadow model) directly:
    // 0 == no shadow, higher values spread/soften the shadow and push it further
    // down. Every shape goes through the SAME RRectShadowImpl, differing only in
    // corner radius and this elevation. Animated so the depth tweens in step with
    // the shape morph (e.g. floating's 3dp eases to full-width's 0dp), and so a
    // shadow grows/shrinks naturally rather than popping. The fade rides on
    // elevation, not opacity or color alpha — RRectShadowImpl drops the color
    // alpha (QColor::rgb()) before rendering, so a color-alpha fade is a no-op.
    property real shadowElevation: config.elevation

    // Best-effort background blur (compositor effect; not animated).
    readonly property real blurSigma: config.blur
    readonly property bool blurEnabled: blurSigma > 0

    Behavior on animMargin { NumberAnimation { duration: MD.Token.duration.medium2; easing: MD.Token.easing.emphasized } }
    Behavior on animTopRadius { NumberAnimation { duration: MD.Token.duration.medium2; easing: MD.Token.easing.emphasized } }
    Behavior on animBottomRadius { NumberAnimation { duration: MD.Token.duration.medium2; easing: MD.Token.easing.emphasized } }
    Behavior on animReversed { NumberAnimation { duration: MD.Token.duration.medium2; easing: MD.Token.easing.emphasized } }
    Behavior on animOpacity { NumberAnimation { duration: MD.Token.duration.medium2; easing: MD.Token.easing.standard } }
    Behavior on shadowElevation { NumberAnimation { duration: MD.Token.duration.medium2; easing: MD.Token.easing.standard } }
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
                opacity: o.floating.opacity, elevation: o.floating.elevation,
                blur: o.floating.blur };
        case "soft-attach":
            return { margin: o.softAttach.margin, topRadius: o.softAttach.topCornerRadius,
                bottomRadius: o.softAttach.bottomCornerRadius, reversed: 0,
                opacity: o.softAttach.opacity, elevation: o.softAttach.elevation,
                blur: o.softAttach.blur };
        case "hug":
            return { margin: o.hug.margin, topRadius: 0, bottomRadius: 0,
                reversed: o.hug.reversedCornerRadius,
                opacity: o.hug.opacity, elevation: o.hug.elevation,
                blur: o.hug.blur };
        case "hidden":
        case "full-width":
        default:
            return { margin: o.fullWidth.margin, topRadius: o.fullWidth.cornerRadius,
                bottomRadius: o.fullWidth.cornerRadius, reversed: 0,
                opacity: o.fullWidth.opacity, elevation: o.fullWidth.elevation,
                blur: o.fullWidth.blur };
        }
    }

    // One continuous CurveRenderer path for every shape. Top corners are convex
    // (`animTopRadius`). The bottom is a single SIGNED value
    // `animBottomRadius - animReversed`: positive draws convex corners
    // (floating/soft-attach/full-width), negative draws reversed concave wings
    // that extend below the baseline (hug). Sweeping through 0 (square) makes
    // every transition — including hug<->convex shapes — morph continuously.
    function surfacePath(w, h) {
        const lim = Math.min(w / 2, h);
        const tr = Math.max(0, Math.min(animTopRadius, lim));
        const tl = tr;
        const signed = animBottomRadius - animReversed;
        const convex = signed >= 0;
        const b = Math.max(0, Math.min(Math.abs(signed), lim));

        let p = "M " + tl + " 0";
        p += " L " + (w - tr) + " 0";
        p += (tr > 0.01) ? (" A " + tr + " " + tr + " 0 0 1 " + w + " " + tr) : (" L " + w + " 0");
        if (convex) {
            p += " L " + w + " " + (h - b);
            p += (b > 0.01) ? (" A " + b + " " + b + " 0 0 1 " + (w - b) + " " + h) : (" L " + w + " " + h);
            p += " L " + b + " " + h;
            p += (b > 0.01) ? (" A " + b + " " + b + " 0 0 1 0 " + (h - b)) : (" L 0 " + h);
        } else {
            p += " L " + w + " " + (h + b);
            p += (b > 0.01) ? (" A " + b + " " + b + " 0 0 0 " + (w - b) + " " + h) : (" L " + w + " " + h);
            p += " L " + b + " " + h;
            p += (b > 0.01) ? (" A " + b + " " + b + " 0 0 0 0 " + (h + b)) : (" L 0 " + h);
        }
        p += " L 0 " + tl;
        p += (tl > 0.01) ? (" A " + tl + " " + tl + " 0 0 1 " + tl + " 0") : (" L 0 0");
        return p + " Z";
    }

    // MD3 elevation shadow, drawn behind the fill. QmlMaterial's RRectShadowImpl
    // is the Skia ambient + spot model (soft ambient base + a downward-projected
    // directional shadow), so it reads as natural depth rather than a flat halo.
    // Driven by corner radii from the same animated scalars as the fill, so the
    // shadow tracks the floating<->soft-attach morph. The user-configurable
    // per-shape `elevation` (animated via root.shadowElevation) sets the depth:
    // the shadow grows/shrinks with it, and a shape whose elevation is 0 renders
    // no shadow. The color stays full-alpha so the component can apply its own
    // ambient/spot opacities. `visible` culls once the depth eases to ~0.
    MD.RRectShadowImpl {
        x: root.surfaceX
        y: root.surfaceY
        width: root.surfaceWidth
        height: root.surfaceHeight
        visible: root.shadowElevation > 0.001
        elevation: root.shadowElevation
        corners: MD.Util.corners(root.animTopRadius, root.animTopRadius,
            Math.max(0, root.animBottomRadius), Math.max(0, root.animBottomRadius))

        color: MD.Token.color.shadow
    }

    // Surface fill, painted once on top of the shadow.
    MD.Shape {
        id: surfaceFill

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
