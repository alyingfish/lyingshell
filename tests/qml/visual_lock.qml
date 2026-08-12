import QtQuick
import QtQuick.Window
import Qcm.Material as MD
import qs.Commons.Theme
import qs.Services
import qs.Modules.Lock

// Offscreen visual dump of the lock scene against the web prototype: renders
// the real LockScene over mocked services and saves one PNG per state, at the
// prototype's own 1600x1000 so the two can be compared side by side.
//
//   QML_XHR_ALLOW_FILE_READ=1 qml6 -I tests/qml/mocks -I ~/.local/lib \
//       tests/qml/visual_lock.qml -- /tmp/out [dark|light] [wallpaper.jpg]
//
// It needs a REAL graphics session — no QT_QPA_PLATFORM=offscreen. The
// offscreen plugin loads the software scene-graph backend, which silently
// draws nothing for a ShaderEffect, and both the avatar's scallop and the
// sweep's circle are shaders. The window is deliberately a 48px stub: the
// scene is a full-size item grabbed on its own, so running this leaves nothing
// but a thumbnail on screen for a second.
//
// Each state settles, is grabbed, and only then advances — grab callbacks
// chain the sequence, so animation load cannot race a fixed schedule.
Window {
    id: root

    visible: true
    width: 48
    height: 48
    color: "#000000"
    title: "lyingshell lock visual"

    // Only what follows `--` is ours; everything before it belongs to qml6
    // (and its -I paths are absolute, so a bare "first absolute argument"
    // scan picks up an import directory instead of the output one).
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
        // The prototype's Aurora seed, so the dumps line up with its own.
        MD.Token.color.accentColor = "#78dc77";
        MD.Token.color.paletteType = MD.Enum.PaletteTonalSpot;
        MD.Token.color.mode = root.darkMode ? MD.Enum.Dark : MD.Enum.Light;
        LockTheme.wallpaper = root.wallpaper;
        steps.start();
    }

    // The prototype's own viewport, so the two can be compared side by side.
    LockScene {
        id: scene

        width: 1600
        height: 1000
        full: true
    }

    // ---- the walk --------------------------------------------------------

    property int step: 0

    readonly property var script: [
        {
            "name": "01-glance",
            "settle": 900,
            "run": function () {
                Lock.reset();
            }
        },
        {
            "name": "02-ask",
            "settle": 1200,
            "run": function () {
                Lock.wake("f");
            }
        },
        {
            "name": "03-typed",
            "settle": 700,
            "run": function () {
                Lock.setPassword("foyer");
            }
        },
        {
            "name": "04-caps",
            "settle": 700,
            "run": function () {
                Lock.capsLock = true;
            }
        },
        {
            "name": "05-revealed",
            "settle": 500,
            "run": function () {
                Lock.capsLock = false;
                Lock.reveal = true;
            }
        },
        {
            "name": "06-pending",
            "settle": 500,
            "run": function () {
                Lock.reveal = false;
                Lock.phase = Lock.phasePending;
            }
        },
        {
            "name": "07-refused",
            "settle": 900,
            "run": function () {
                Lock.failed("Failed");
            }
        },
        {
            "name": "08-success",
            "settle": 900,
            "run": function () {
                Lock.refused = false;
                Lock.phase = Lock.phasePending;
                Lock.succeeded = true;
            }
        }
    ]

    Timer {
        id: steps

        interval: 400
        repeat: false

        onTriggered: {
            if (root.step >= root.script.length) {
                Qt.exit(0);
                return;
            }
            var item = root.script[root.step];
            item.run();
            settle.interval = item.settle;
            settle.start();
        }
    }

    Timer {
        id: settle

        repeat: false

        onTriggered: {
            var item = root.script[root.step];
            root.grabWindow(item.name);
        }
    }

    function grabWindow(name) {
        scene.grabToImage(function (result) {
            result.saveToFile(root.outDir + "/" + name + ".png");
            console.log("SHOT: " + name);
            root.step++;
            steps.start();
        }, Qt.size(scene.width, scene.height));
    }
}
