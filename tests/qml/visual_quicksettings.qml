import QtQuick
import QtQuick.Window
import Qcm.Material as MD
import Quickshell.Bluetooth
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

    property string outDir: {
        const args = Qt.application.arguments;
        return args[args.length - 1].startsWith("/") ? args[args.length - 1] : "/tmp/qs-visual";
    }

    Component.onCompleted: {
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

    property int shotIndex: 0
    readonly property var shots: [
        ["main-light", () => panel.open = true],
        ["session-menu", () => panel.sessionMenuOpen = true],
        ["tools-open", () => {
                panel.sessionMenuOpen = false;
                panel.toolsOpen = true;
            }],
        ["pmode-open", () => {
                panel.toolsOpen = false;
                panel.pmodeOpen = true;
            }],
        ["tiles-page2", () => {
                panel.pmodeOpen = false;
                panel.setPage(1);
            }],
        ["detail-wifi", () => {
                panel.setPage(0);
                panel.detail = "wifi";
            }],
        ["detail-audio", () => {
                panel.detail = "output";
            }],
        ["detail-bt-off", () => {
                Bluetooth.defaultAdapter.enabled = false;
                panel.detail = "bluetooth";
            }],
        ["main-dark", () => {
                Bluetooth.defaultAdapter.enabled = true;
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
                const ok = result.saveToFile(root.outDir + "/" + name + ".png");
                console.log((ok ? "SAVED " : "FAILED ") + name);
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
