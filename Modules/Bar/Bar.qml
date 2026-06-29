import QtQuick
import Quickshell
import Quickshell.Wayland
import Qcm.Material as MD
import qs.Commons.I18n
import qs.Commons.Settings
import qs.Commons.Theme
import qs.Modules.Bar.Widgets
import qs.Services.Niri

PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
    }

    // Transparent window; the visible bar is the inset BarSurface so margins,
    // rounded corners, opacity, and shadow can render around it.
    color: "transparent"
    implicitHeight: barSurface.totalHeight
    // Reserve from the discrete target margin, not the animated `animMargin`:
    // an animated exclusiveZone repushes to the compositor every frame, so the
    // tiled terminal re-tiles (and reflows) on every morph frame. Using the
    // settled target makes the zone — and thus the terminal — change exactly
    // once per shape switch. The surface still morphs smoothly via animMargin.
    exclusiveZone: barSurface.isHidden
        ? 0
        : Math.round(barSurface.config.margin + barSurface.barHeight)

    // Restrict input to the visible surface so the transparent margins, shadow
    // buffer, and slid-away (hidden) state stay click-through.
    mask: Region {
        item: maskItem
    }

    // Best-effort background blur behind the surface. A no-op where the
    // compositor lacks ext-background-effect-v1 (e.g. current Niri); the rounded
    // region approximates the bar body (wings excluded).
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

        readonly property int edgeMargin: Math.max(8, Math.round(Math.max(barSurface.animTopRadius, barSurface.animBottomRadius)))
        readonly property int rowSpacing: 8
        readonly property int minimumCenterGap: 24
        readonly property real availableWidth: width
        readonly property bool rightContentVisible: availableWidth >= leftContent.implicitWidth + rightContent.implicitWidth + minimumCenterGap
        readonly property bool centerContentVisible: rightContentVisible
            && availableWidth >= leftContent.implicitWidth + rightContent.implicitWidth + centerDateTime.implicitWidth + minimumCenterGap * 2

        // Tracks the surface rect (incl. the hidden slide-out) so content
        // moves with the background instead of blinking on shape change.
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
                workspaceModel: root.screen && root.screen.name
                    ? Niri.workspacesByOutput[root.screen.name] || []
                    : []

                onFocusRequested: function(workspaceId) {
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

            MD.Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "dashboard"
                size: 16
                color: MD.Token.color.primary
                fill: true
            }

            MD.Text {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("app.name")
                color: MD.Token.color.on_surface
                typescale: MD.Token.typescale.title_small
                font.family: Theme.textTypeface
                verticalAlignment: Text.AlignVCenter
            }
        }

        DateTime {
            id: centerDateTime

            // Center with a plain binding, NOT anchors.centerIn: the anchor
            // rounds its offset to whole pixels, and against the fractional
            // (smoothly sliding) parent that rounding flips sign each half-pixel
            // — the ±1px morph wobble. The un-rounded offset cancels the parent's
            // fractional x/y exactly, so the centre stays put while the bar slides.
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
