import QtQuick
import Qcm.Material as MD
import qs.Commons.Settings
import qs.Commons.Theme
import qs.Services
import qs.Material
import qs.Modules.Bar.Widgets

import "../../Material/Motion.js" as Motion
import "../Bar/BarMotion.js" as BarMotion

// The status pill on the lock surface, and the quick-settings panel it opens.
//
// The prototype reparents the shell's own #tray pill onto the lock stage
// rather than mocking a second one up. A QML item cannot move between windows
// that way, so this raises a second instance of the same widget instead —
// same indicators, same panel, same code — differing only in the three things
// the lock changes: it wears glass, it does not claim the output's ShellIpc
// registration (the bar's keeps it), and it hands the panel a content item to
// live in, because a session-lock surface is not a QsWindow.
//
// It is the floating desktop bar's continuation: Glance/Hello use the same
// fully-hidden offset and Ask uses the same M3E default-spatial spring as the
// desktop bar's hidden -> floating change.
Item {
    id: root

    // Where the panel card is reparented to (the scene root).
    property Item overlayParent: null

    readonly property bool panelOpen: pill.panelOpen
    readonly property bool present: Lock.phase === Lock.phaseAsk || Lock.phase === Lock.phasePending
    readonly property var floatingBar: Settings.options.bar.shape.floating
    readonly property real hiddenOffset: BarMotion.hiddenOffset(floatingBar.margin, floatingBar.height)

    // Floating-bar metrics, so both resting geometry and travel continue to
    // follow user configuration instead of matching only the defaults.
    readonly property real slotTop: floatingBar.margin
    readonly property real slotSide: floatingBar.margin
    readonly property real slotHeight: floatingBar.height
    readonly property real slotPadding: Math.max(8, floatingBar.radius)

    implicitWidth: pill.implicitWidth + slotPadding * 2 + slotSide
    implicitHeight: slotTop + slotHeight

    MotionSpring {
        id: revealMotion

        target: root.present ? 1 : 0
        spring: Motion.spatialDefault
        motionEnabled: !Settings.options.appearance.reducedMotion
    }

    transform: Translate {
        y: root.hiddenOffset * (1 - revealMotion.value)
    }

    onPresentChanged: if (!present)
        pill.panelOpen = false

    // Escape unwinds the panel's layers before the lock's own: detail view,
    // then the power menu or an expanded row, then the panel itself. Returns
    // true when it consumed the key.
    function unwind() {
        if (!pill.panelOpen) {
            return false;
        }
        var panel = pill.panel;
        if (panel.detail.length > 0) {
            panel.detail = "";
            return true;
        }
        if (panel.sessionMenuOpen) {
            panel.sessionMenuOpen = false;
            return true;
        }
        if (panel.toolsOpen) {
            panel.toolsOpen = false;
            return true;
        }
        if (panel.pmodeOpen) {
            panel.pmodeOpen = false;
            return true;
        }
        pill.panelOpen = false;
        return true;
    }

    QuickSettingsButton {
        id: pill

        anchors.right: parent.right
        anchors.rightMargin: root.slotSide + root.slotPadding
        anchors.top: parent.top
        anchors.topMargin: root.slotTop + (root.slotHeight - implicitHeight) / 2
        enabled: root.present

        // The lock's own instance: the bar keeps the output's IPC panel.
        registerIpc: false
        surfaceColor: LockTheme.glass
        // The MD3 8% state layer mixed into the raised glass, not laid over it.
        surfaceHoverColor: Qt.rgba(MD.Token.color.on_surface.r * 0.08 + LockTheme.glassHigh.r * 0.92, MD.Token.color.on_surface.g * 0.08 + LockTheme.glassHigh.g * 0.92, MD.Token.color.on_surface.b * 0.08 + LockTheme.glassHigh.b * 0.92, LockTheme.glassHigh.a)
        overlayParent: root.overlayParent
        // The card hangs off the pill the way it hangs off the bar.
        barSurfaceRect: Qt.rect(0, root.slotTop, root.width, root.slotHeight)
    }
}
