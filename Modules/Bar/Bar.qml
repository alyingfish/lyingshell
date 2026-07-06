import QtQuick
import Quickshell
import Quickshell.Wayland
import Qcm.Material as MD
import qs.Commons.Settings
import qs.Modules.Bar.Widgets
import qs.Modules.Bar.Widgets.SystemTray
import qs.Modules.Bar.Widgets.Workspaces
import qs.Services.Niri

PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
    }

    color: "transparent"
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
    // Reserve from the settled target, not animMargin: an animated zone repushes
    // every frame and re-tiles windows on every morph frame.
    exclusiveZone: barSurface.isHidden ? 0 : Math.round(barSurface.config.margin + barSurface.barHeight)

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
        barHeight: Settings.options.bar.height
        outputName: root.screen ? root.screen.name : ""
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
