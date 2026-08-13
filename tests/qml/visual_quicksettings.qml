import QtQuick
import QtQuick.Window
import Qcm.Material as MD
import Quickshell.Bluetooth
import Quickshell.Networking
import qs.Commons.Settings
import qs.Services.Niri
import "../../Modules/QuickSettings"

// Offscreen visual dump of the quick-settings panel against the web
// prototype: renders the real QuickSettingsPanel over mocked services (demo
// data mirroring quicksettings.html) and saves one PNG per UI state.
//
//   QML_XHR_ALLOW_FILE_READ=1 QT_QPA_PLATFORM=offscreen \
//       qml6 -I tests/qml/mocks -I ~/.local/lib \
//       tests/qml/visual_quicksettings.qml -- /tmp/out
//
// The card wrapper mirrors QuickSettingsPopup.qml (radius 24,
// surface-container-low) so corners and edge spacing are comparable. Each
// state settles, is grabbed, and only then advances (grab callbacks chain
// the sequence, so animation load cannot race a fixed schedule).
Window {
    id: root

    visible: true
    width: 424
    height: 760
    color: "#2b1660"

    // The first argument after `--`, like the lock harnesses take it. Reading
    // the LAST argument instead silently redirected the whole run to the
    // fallback whenever anything trailed the path (a stray `light`, say), and
    // saveToFile into a directory that does not exist fails per shot — a run
    // that reports nothing but failures while the path it was given sits
    // empty. The resolved directory is printed for the same reason.
    readonly property var argv: {
        const all = Qt.application.arguments;
        const split = all.indexOf("--");
        return split >= 0 ? all.slice(split + 1) : [];
    }

    property string outDir: argv.length > 0 && argv[0].startsWith("/") ? argv[0] : "/tmp/qs-visual"

    Component.onCompleted: {
        console.log("OUT: " + root.outDir);
        // Prototype baseline seed, tonal-spot palette (mirrors Theme.qml).
        MD.Token.color.useSysColorSM = false;
        MD.Token.color.useSysAccentColor = false;
        MD.Token.color.accentColor = "#6750A4";
        MD.Token.color.paletteType = MD.Enum.PaletteTonalSpot;
        MD.Token.color.mode = MD.Enum.Light;
    }

    Rectangle {
        id: card

        x: 40
        y: 40
        width: panel.implicitWidth
        height: panel.implicitHeight
        radius: 24
        color: MD.Token.color.surface_container_low

        MD.MProp.textColor: MD.Token.color.on_surface
        MD.MProp.backgroundColor: MD.Token.color.surface_container_low

        QuickSettingsPanel {
            id: panel

            width: parent.width
        }
    }

    // Depth-first search for the loaded detail-page body exposing `prop`
    // (the pushed page is not a public panel handle).
    function findWithProp(item, prop) {
        if (!item) {
            return null;
        }
        if (prop in item) {
            return item;
        }
        for (var i = 0; i < item.children.length; i++) {
            const hit = findWithProp(item.children[i], prop);
            if (hit) {
                return hit;
            }
        }
        return null;
    }

    property int shotIndex: 0
    readonly property var shots: [
        ["main-light", () => panel.open = true],
        ["session-menu", () => panel.sessionMenuOpen = true],
        ["tools-open", () => {
                panel.sessionMenuOpen = false;
                panel.toolsOpen = true;
            }],
        ["pmode-open", () => {
                // Open the new row before clearing the old (as the buttons do).
                panel.pmodeOpen = true;
                panel.toolsOpen = false;
            }],
        ["tiles-page2", () => {
                panel.pmodeOpen = false;
                panel.setPage(1);
            }],
        ["detail-wifi", () => {
                panel.setPage(0);
                panel.detail = "wifi";
            }],
        // Expanded-row states (prototype wifi.js accordion bodies).
        ["detail-wifi-hero-open", () => {
                const body = root.findWithProp(panel, "expandedNetwork");
                body.expandedNetwork = Networking.wifiNets[0];
            }],
        ["detail-wifi-psk", () => {
                const body = root.findWithProp(panel, "expandedNetwork");
                body.expandedNetwork = Networking.wifiNets[5];
            }],
        ["detail-wifi-hidden", () => {
                const body = root.findWithProp(panel, "expandedNetwork");
                body.expandedNetwork = body.hiddenSentinel;
            }],
        // Second beat: the join form has settled, scroll it into view.
        ["detail-wifi-hidden-scrolled", () => {
                const body = root.findWithProp(panel, "expandedNetwork");
                var flick = body.parent;
                while (flick && !("contentY" in flick)) {
                    flick = flick.parent;
                }
                if (flick) {
                    flick.contentY = Math.max(0, flick.contentHeight - flick.height);
                }
            }],
        ["detail-hotspot", () => {
                const body = root.findWithProp(panel, "expandedNetwork");
                body.expandedNetwork = null;
                Networking.wifiDevice.mode = WifiDeviceMode.AccessPoint;
            }],
        ["detail-bt", () => {
                Networking.wifiDevice.mode = WifiDeviceMode.Station;
                panel.detail = "bluetooth";
            }],
        ["detail-bt-hero-open", () => {
                const body = root.findWithProp(panel, "expandedDevice");
                body.expandedDevice = Bluetooth.allDevices[0];
            }],
        ["detail-bt-paired-open", () => {
                const body = root.findWithProp(panel, "expandedDevice");
                body.expandedDevice = Bluetooth.allDevices[2];
            }],
        ["detail-sound", () => {
                panel.detail = "sound";
            }],
        ["detail-bt-off", () => {
                Bluetooth.defaultAdapter.enabled = false;
                panel.detail = "bluetooth";
            }],
        ["detail-color", () => {
                Bluetooth.defaultAdapter.enabled = true;
                Niri.lastPickedColor = "#8150ff";
                Settings.options.quickSettings.colorPicker.recentColors = ["#8150ff", "#e2725b", "#3a7ca5", "#f4c95d", "#6b8e23"];
                panel.detail = "color";
            }],
        ["main-dark", () => {
                panel.detail = "";
                MD.Token.color.mode = MD.Enum.Dark;
            }]
    ]

    function advance() {
        if (root.shotIndex >= root.shots.length) {
            Qt.exit(0);
            return;
        }
        const entry = root.shots[root.shotIndex];
        root.shotIndex += 1;
        entry[1]();
        settle.shotName = entry[0];
        settle.restart();
    }

    Timer {
        id: settle

        property string shotName: ""

        interval: 900

        onTriggered: {
            const name = shotName;
            const started = card.grabToImage(result => {
                const path = root.outDir + "/" + name + ".png";
                if (result.saveToFile(path)) {
                    console.log("SAVED " + name);
                } else {
                    console.warn("FAILED " + name + " -> " + path + " (does the output directory exist?)");
                }
                root.advance();
            });
            if (!started) {
                console.log("GRAB-REFUSED " + name);
                root.advance();
            }
        }
    }

    Timer {
        interval: 300
        running: true

        onTriggered: root.advance()
    }
}
