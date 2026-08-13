import QtQuick
import QtQuick.Window
import Quickshell
import Qcm.Material as MD
import qs.Commons.Theme
import qs.Services
import qs.Modules.Lock

import "../../Modules/Lock/LockMotion.js" as LockMotion

// Offscreen visual dump of the SWEEP: the lock scene with the circular hole cut
// in it, over a checkerboard standing in for the desktop the compositor shows
// through that hole.
//
//   QML_XHR_ALLOW_FILE_READ=1 qml6 -I tests/qml/mocks -I ~/.local/lib \
//       tests/qml/visual_lock_sweep.qml -- /tmp/out [dark|light] [wallpaper.jpg]
//
// Like visual_lock.qml it needs a REAL graphics session — the hole is a
// ShaderEffect, and the offscreen platform's software backend draws nothing for
// one. Same 48px stub window; the scene is grabbed at full size on its own.
//
// What it proves: the circle is centred on where the avatar RESTS (not where
// its approach transform has it), it stays a circle on a non-square surface,
// and at deskHole 1 it has overshot the corners rather than merely touching
// them — the geometry the 900ms curve is timed against.
Window {
    id: root

    visible: true
    width: 48
    height: 48
    color: "#000000"
    title: "lyingshell lock sweep"

    readonly property var argv: {
        var all = Qt.application.arguments;
        var split = all.indexOf("--");
        return split >= 0 ? all.slice(split + 1) : [];
    }

    property string outDir: argv.length > 0 ? argv[0] : "/tmp/lock-visual"
    property bool darkMode: argv.indexOf("dark") >= 0
    property string wallpaper: {
        for (var i = 0; i < argv.length; i++) {
            if (argv[i].endsWith(".jpg") || argv[i].endsWith(".png")) {
                return argv[i];
            }
        }
        return "";
    }

    Component.onCompleted: {
        MD.Token.color.useSysColorSM = false;
        MD.Token.color.useSysAccentColor = false;
        MD.Token.color.accentColor = "#78dc77";
        MD.Token.color.paletteType = MD.Enum.PaletteTonalSpot;
        MD.Token.color.mode = root.darkMode ? MD.Enum.Dark : MD.Enum.Light;
        LockTheme.wallpaper = root.wallpaper;
        Lock.wake("foyer");
        steps.start();
    }

    Item {
        id: stage

        width: 1600
        height: 1000

        // The desktop the hole reveals. A checkerboard, so a hole that is not
        // actually transparent cannot be mistaken for one that is.
        Row {
            anchors.fill: parent

            Repeater {
                model: 16

                Column {
                    required property int index

                    width: stage.width / 16
                    height: stage.height

                    Repeater {
                        model: 10

                        Rectangle {
                            required property int index

                            width: stage.width / 16
                            height: stage.height / 10
                            color: (index + parent.parent.index) % 2 === 0 ? "#3d4a5c" : "#8fa3bd"
                        }
                    }
                }
            }
        }

        LockScene {
            id: scene

            anchors.fill: parent
            full: true
            interactive: false
        }

        ShaderEffectSource {
            id: sceneTexture

            anchors.fill: parent
            sourceItem: scene
            hideSource: true
            live: true
            visible: false
        }

        ShaderEffect {
            anchors.fill: parent

            property variant scene: sceneTexture
            property vector2d centre: Qt.vector2d(0.5, scene.sweepOriginY / stage.height)
            property real radius: root.hole * LockMotion.fullRadius(stage.width, stage.height) / stage.width
            property real aspect: stage.height / stage.width
            property real feather: 1.0 / stage.width

            fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/assets/shaders/qsb/lock_sweep.frag.qsb")
        }
    }

    // ---- the walk --------------------------------------------------------

    property real hole: 0
    property int step: 0
    readonly property var script: [0.0, 0.08, 0.25, 0.5, 1.0]

    Timer {
        id: steps

        interval: 700
        repeat: false

        onTriggered: {
            if (root.step >= root.script.length) {
                Qt.exit(0);
                return;
            }
            root.hole = root.script[root.step];
            settle.start();
        }
    }

    Timer {
        id: settle

        interval: 250
        repeat: false

        onTriggered: scene.grabToImage(function () {}) // warm the texture

        Component.onCompleted: {}
    }

    Connections {
        target: settle

        function onTriggered() {
            grab.start();
        }
    }

    Timer {
        id: grab

        interval: 120
        repeat: false

        onTriggered: {
            stage.grabToImage(function (result) {
                var name = "sweep-" + String(root.step) + "-hole" + String(Math.round(root.hole * 100));
                // A save into a directory that does not exist fails silently
                // unless it is checked; see visual_lock.qml.
                var path = root.outDir + "/" + name + ".png";
                if (result.saveToFile(path)) {
                    console.log("SHOT: " + name);
                } else {
                    console.warn("SHOT-FAILED: " + name + " -> " + path + " (does the output directory exist?)");
                }
                root.step++;
                steps.start();
            }, Qt.size(stage.width, stage.height));
        }
    }
}
