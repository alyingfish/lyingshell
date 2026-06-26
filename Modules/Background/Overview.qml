import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Qcm.Material as MD
import qs.Commons.Settings
import qs.Commons.Theme
import qs.Services.Niri
import qs.Services.Wallpaper

// Blurred + tinted wallpaper copy for the niri overview backdrop. It shares the
// cached texture with Background.qml. Niri only shows it in the overview when a
// layer rule pins this namespace into the backdrop:
//
//   layer-rule {
//       match namespace="lyingshell-overview"
//       place-within-backdrop true
//   }
Loader {
    active: Niri.available && Settings.options.wallpaper.enabled && Settings.options.wallpaper.overviewEnabled

    sourceComponent: Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: panelWindow

            required property ShellScreen modelData
            property string wallpaper: ""
            property color tintColor: Theme.effectiveMode === "dark" ? MD.Token.color.surface : MD.Token.color.on_surface

            visible: wallpaper !== ""

            // Seed immediately: Background may emit wallpaperProcessingComplete
            // before this delegate's Connections exist (no async cache to delay it).
            Component.onCompleted: wallpaper = Wallpaper.getWallpaper(modelData.name)

            Component.onDestruction: bgImage.source = ""

            // Reuse Background's already-resolved path/texture.
            Connections {
                target: Wallpaper
                function onWallpaperProcessingComplete(screenName, path, cachedPath) {
                    if (screenName === modelData.name) {
                        panelWindow.wallpaper = path;
                    }
                }
            }

            color: "transparent"
            screen: modelData
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "lyingshell-overview-" + (screen?.name || "unknown")

            anchors {
                top: true
                bottom: true
                right: true
                left: true
            }

            readonly property bool blurOn: Settings.options.wallpaper.overviewBlur > 0

            Image {
                id: bgImage
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: panelWindow.wallpaper
                visible: !panelWindow.blurOn
                smooth: true
                mipmap: false
                cache: true // Shares texture with Background's currentWallpaper
                asynchronous: true
            }

            // Blur via a standalone MultiEffect (the item-`layer.effect` path
            // renders empty on this backdrop surface).
            MultiEffect {
                anchors.fill: parent
                source: bgImage
                visible: panelWindow.blurOn
                autoPaddingEnabled: false
                blurEnabled: true
                blur: 1.0
                blurMax: Math.round(Settings.options.wallpaper.overviewBlur)
            }

            Rectangle {
                anchors.fill: parent
                color: panelWindow.tintColor
                opacity: Settings.options.wallpaper.overviewTint
            }
        }
    }
}
