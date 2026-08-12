pragma Singleton

import QtQuick
import Qcm.Material as MD

// Test stand-in for qs.Commons.Theme.LockTheme under plain qml6.
//
// The real singleton derives its seed from the lock wallpaper with matugen and
// caches it on disk; here the harness sets `wallpaper` and the seed directly.
// The composed off-spec roles are the SAME expressions as the product file, so
// a visual dump exercises the real colour rules — only the derivation is
// stubbed. `onWall` normally comes from a second scheme in the opposite mode;
// without one, the opposite mode's surface is approximated by the inverse
// surface role, which is the same neutral at the other end of the same ramp.
QtObject {
    id: root

    property bool active: true
    property string wallpaper: ""

    readonly property bool dark: MD.Token.color.mode === MD.Enum.Dark

    function withAlpha(base, a) {
        return Qt.rgba(base.r, base.g, base.b, a);
    }

    readonly property color onWall: MD.Token.color.inverse_surface
    readonly property color onWallDim: withAlpha(onWall, 0.74)

    readonly property color glass: withAlpha(dark ? MD.Token.color.surface_container : MD.Token.color.surface_container_low, dark ? 0.62 : 0.60)
    readonly property color glassHigh: withAlpha(dark ? MD.Token.color.surface_container_high : MD.Token.color.surface, 0.78)
    readonly property color authScrim: withAlpha(dark ? MD.Token.color.surface_dim : MD.Token.color.surface_bright, dark ? 0.44 : 0.40)

    readonly property color clockHours: MD.Token.color.primary
    readonly property color clockMinutes: MD.Token.color.tertiary
}
