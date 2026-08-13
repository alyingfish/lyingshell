import QtQuick
import Quickshell
import Quickshell.Wayland
import Qcm.Material as MD
import qs.Modules.Bar.Widgets
import qs.Modules.Bar.Widgets.SystemTray
import qs.Modules.Bar.Widgets.Workspaces
import qs.Modules.Lock
import qs.Services
import qs.Services.Niri

PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
    }

    color: "transparent"

    // While the session is locked the compositor draws only the lock
    // surfaces: a window that tries to render then stalls its render thread
    // on buffers that are never released, and the stall can wedge the whole
    // shell — dead keyboard on the lock screen included (see RENDERING
    // SAFETY in Modules/Lock/LockScreen.qml). Park the bar for the duration;
    // the clock and any stray animation must not force frames onto a surface
    // nobody draws. It unparks on release, so the desktop the unlock sweep
    // reveals already carries a fresh bar.
    updatesEnabled: !Lock.locked
    // Size the window off the SETTLED margin, not animMargin: an animated height
    // resizes the Wayland layer-surface buffer every morph frame, which drops
    // ~3 frames per morph (visible stutter). The surface still animates inside the
    // window via surfaceX/surfaceY. Same reasoning as exclusiveZone below.
    // Tray-expanded (popover/drag) jumps to full screen height in one step —
    // never animated — so the tray popover, tooltip, and drag visuals stay in
    // this window's scene. The collapsed reserve keeps room for tray tooltips.
    // Quick-settings panel expansion reuses the same full-height jump.
    // The tray + quick-settings widgets (the whole ~4k-line quick-settings tree)
    // cost ~90ms to construct; defer them one tick past the bar's first paint so
    // workspaces + clock show immediately (measured first paint ~0.24s vs ~0.32s
    // eager). Loaders are null until deferredReady flips, so every reference
    // below is guarded.
    property bool deferredReady: false
    Timer {
        interval: 0
        running: true
        onTriggered: root.deferredReady = true
    }

    readonly property bool overlayExpanded: (systemTrayLoader.item ? systemTrayLoader.item.expanded : false) || (quickSettingsLoader.item ? quickSettingsLoader.item.expanded : false)
    implicitHeight: overlayExpanded && root.screen ? root.screen.height : barSurface.config.margin + barSurface.barHeight + Math.max(barSurface.shadowBuffer, barSurface.reversedTarget + 4, systemTrayLoader.item ? systemTrayLoader.item.collapsedReserve : 0)
    // Reserve straight from settings (barSurface resolves hidden → its own
    // `hidden.exclusiveZone`, else the active shape's). Equal defaults (32) mean
    // neither hiding the bar (overview) nor switching shapes on an empty↔populated
    // workspace changes the reserve, so niri never re-tiles — no reflow stutter.
    // The bar disappears visually via revealOffset.
    exclusiveZone: barSurface.exclusiveZone

    // Restrict input to the visible surface; margins/shadow/hidden stay
    // click-through. While the tray popover/drag is active the whole window
    // takes input (null mask = full window) so the tray click-catcher sees
    // outside presses.
    mask: overlayExpanded ? null : barMask

    Region {
        id: barMask

        item: maskItem
    }

    // Best-effort background blur (no-op without ext-background-effect-v1).
    BackgroundEffect.blurRegion: barSurface.blurEnabled ? blurRegion : null

    Region {
        id: blurRegion

        item: maskItem
        topLeftRadius: Math.round(barSurface.animTopRadius)
        topRightRadius: Math.round(barSurface.animTopRadius)
        bottomLeftRadius: Math.round(barSurface.animBottomRadius)
        bottomRightRadius: Math.round(barSurface.animBottomRadius)
    }

    BarSurface {
        id: barSurface

        anchors.fill: parent
        outputName: root.screen ? root.screen.name : ""
    }

    // This output's pre-lock desktop capture, parked below the strip where
    // the viewport never shows it. It lives HERE because the bar window
    // already exists on every output: raising fresh fullscreen windows at
    // lock time stuttered the entry and provoked a Qt wl_surface.enter
    // crash (see LockStillCapture.qml).
    LockStillCapture {
        y: root.height
        screen: root.screen
        // The shot waits out this window's own overlays: the lock gesture
        // force-closes the quick-settings panel and tray popover, but the
        // close is an animation, and a still taken mid-fade would carry the
        // half-closed panel through the whole entry sweep. Lock's
        // captureBail bounds the wait.
        hold: root.overlayExpanded
    }

    // A parked window drops the frames its animations would have drawn, and
    // re-enabling updates does not repaint by itself: with no fresh damage
    // the compositor keeps showing the stale pre-lock buffer — a ghost of
    // the quick-settings panel mid-close. One tick after unlock (so
    // updatesEnabled is already true), poke an invisible pixel to force a
    // current frame.
    Rectangle {
        id: unparkNudge

        width: 1
        height: 1
        color: "transparent"
    }

    Timer {
        id: unparkRepaint

        interval: 0
        onTriggered: unparkNudge.rotation = unparkNudge.rotation === 0 ? 1 : 0
    }

    Connections {
        target: Lock

        function onLockedChanged() {
            if (!Lock.locked) {
                unparkRepaint.restart();
            }
        }
    }

    Item {
        id: content

        // Inset off the SETTLED target, not max(8, animRadius): clamping the eased
        // radius once it drops below 8 kinks the morph.
        property real edgeMargin: Math.max(8, barSurface.contentRadiusTarget)

        Behavior on edgeMargin {
            NumberAnimation {
                duration: MD.Token.duration.medium2
                easing: MD.Token.easing.emphasized
            }
        }
        readonly property int rowSpacing: 8
        readonly property int minimumCenterGap: 24
        readonly property real availableWidth: width
        readonly property bool rightContentVisible: availableWidth >= leftContent.implicitWidth + rightContent.implicitWidth + minimumCenterGap
        readonly property bool centerContentVisible: rightContentVisible && availableWidth >= leftContent.implicitWidth + rightContent.implicitWidth + centerDateTime.implicitWidth + minimumCenterGap * 2

        // Track the surface rect so content moves with the background.
        x: barSurface.surfaceX + edgeMargin
        y: barSurface.surfaceY
        width: Math.max(0, barSurface.surfaceWidth - edgeMargin * 2)
        height: barSurface.surfaceHeight

        Row {
            id: leftContent

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: content.rowSpacing

            Workspaces {
                workspaceModel: root.screen && root.screen.name ? Niri.workspacesByOutput[root.screen.name] || [] : []

                onFocusRequested: function (workspaceId) {
                    Niri.focusWorkspaceById(workspaceId);
                }
            }
        }

        Row {
            id: rightContent

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: content.rowSpacing
            visible: content.rightContentVisible

            Loader {
                id: systemTrayLoader

                active: root.deferredReady
                anchors.verticalCenter: parent.verticalCenter
                sourceComponent: SystemTray {
                    barHidden: barSurface.isHidden
                    barSurfaceRect: Qt.rect(barSurface.surfaceX, barSurface.surfaceY, barSurface.surfaceWidth, barSurface.surfaceHeight)
                }
            }

            Loader {
                id: quickSettingsLoader

                active: root.deferredReady
                anchors.verticalCenter: parent.verticalCenter
                sourceComponent: QuickSettingsButton {
                    barHidden: barSurface.isHidden
                    barSurfaceRect: Qt.rect(barSurface.surfaceX, barSurface.surfaceY, barSurface.surfaceWidth, barSurface.surfaceHeight)
                    screenName: root.screen ? root.screen.name : ""
                }
            }
        }

        DateTime {
            id: centerDateTime

            // Plain binding, NOT anchors.centerIn: the anchor rounds its offset and
            // flips sign against the fractional sliding parent — the ±1px wobble.
            x: (parent.width - width) / 2
            y: (parent.height - height) / 2
            visible: content.centerContentVisible
        }
    }

    Item {
        id: maskItem

        x: barSurface.surfaceX
        y: barSurface.surfaceY
        width: barSurface.surfaceWidth
        height: barSurface.surfaceHeight
    }
}
