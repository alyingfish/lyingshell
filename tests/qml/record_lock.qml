import QtQuick
import QtQuick.Window
import Quickshell
import Qcm.Material as MD
import qs.Commons.Theme
import qs.Services
import qs.Modules.Lock

import "../../Modules/Lock/LockMotion.js" as LockMotion

// Frame recorder: walks the lock screen through every transition and writes one
// PNG per rendered frame, with the wall-clock offset of each printed as
// "FRAME <index> <ms>". A stills dump (visual_lock.qml) cannot show whether a
// transition is smooth, whether it stalls, or whether it lands where it should;
// this can, and the timestamps let the frames be reassembled into a video with
// their real timing.
//
//   QML_XHR_ALLOW_FILE_READ=1 QT_FORCE_STDERR_LOGGING=1 \
//       qml6 -I tests/qml/mocks -I ~/.local/lib \
//       tests/qml/record_lock.qml -- /tmp/frames [dark|light] [wallpaper.jpg] [live]
//
// `live` runs the same walk in a real full-size window and measures the frame
// interval instead of grabbing, which is the only way to see whether a
// transition is actually SMOOTH: a grab-driven recording is paced by the grabs,
// so it can make a janky animation look even and an even one look janky.
//
// Needs a real graphics session, like the other visual_* harnesses: the avatar
// and the sweep are shaders. Grabs run back to back — each frame is requested
// from the previous one's callback — so the capture never outruns the renderer,
// and the scripted actions fire off the same loop so they cannot drift ahead of
// the frames that are supposed to show them.
Window {
    id: root

    // `live` measures instead of recording, and needs a real window to measure.
    readonly property bool live: argv.indexOf("live") >= 0

    visible: true
    width: live ? 1600 : 48
    height: live ? 1000 : 48
    color: "#000000"
    title: "lyingshell lock recorder"

    readonly property var argv: {
        var all = Qt.application.arguments;
        var split = all.indexOf("--");
        return split >= 0 ? all.slice(split + 1) : [];
    }

    property string outDir: argv.length > 0 ? argv[0] : "/tmp/lock-frames"
    property bool darkMode: argv.indexOf("dark") >= 0
    property string wallpaper: {
        for (var i = 0; i < argv.length; i++) {
            if (argv[i].endsWith(".jpg") || argv[i].endsWith(".png")) {
                return argv[i];
            }
        }
        return "";
    }

    // The desktop the sweep's hole reveals.
    Item {
        id: stage

        width: 1600
        height: 1000

        Image {
            anchors.fill: parent
            source: root.wallpaper
            fillMode: Image.PreserveAspectCrop
        }

        Rectangle {
            anchors.fill: parent
            color: "#101418"
            opacity: 0.55
        }

        Text {
            anchors.centerIn: parent
            text: "desktop"
            color: "#8fa3bd"
            font.pixelSize: 96
            font.weight: Font.DemiBold
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
            property real radius: Lock.deskHole * LockMotion.fullRadius(stage.width, stage.height) / stage.width
            property real aspect: stage.height / stage.width
            property real feather: 1.0 / stage.width

            fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/assets/shaders/qsb/lock_sweep.frag.qsb")
        }
    }

    // ---- the walk --------------------------------------------------------

    // Uncompressed frames at a reduced size: a PNG encode of a full-size
    // frame costs ~250ms, which samples a 285ms spring twice. BMP is a memcpy
    // and ffmpeg turns the pile into a video afterwards.
    readonly property int grabWidth: 800
    readonly property int grabHeight: 500

    property real startedAt: 0
    property int frame: 0
    property int cue: 0

    // [ms, label, action]. The lock is never taken — only the pieces that
    // animate are driven, so this runs anywhere.
    readonly property var script: [
        [0, "glance", function () {
                Lock.reset();
                Lock.deskHole = 0;
            }],
        [900, "wake+f", function () {
                Lock.wake("f");
            }],
        [2200, "type o", function () {
                Lock.setPassword("fo");
            }],
        [2330, "type y", function () {
                Lock.setPassword("foy");
            }],
        [2460, "type e", function () {
                Lock.setPassword("foye");
            }],
        [2590, "type r", function () {
                Lock.setPassword("foyer");
            }],
        [3100, "caps on", function () {
                Lock.capsLock = true;
            }],
        [3900, "caps off", function () {
                Lock.capsLock = false;
            }],
        [4400, "delete r", function () {
                Lock.setPassword("foye");
            }],
        [4600, "delete e", function () {
                Lock.setPassword("foy");
            }],
        [5000, "refill", function () {
                Lock.setPassword("wrong");
            }],
        [5400, "submit (wrong)", function () {
                Lock.phase = Lock.phasePending;
            }],
        [6300, "refused", function () {
                Lock.failed("Failed");
            }],
        [7400, "submit (right)", function () {
                Lock.refused = false;
                Lock.setPassword("foyer");
                Lock.phase = Lock.phasePending;
            }],
        [8300, "success pose", function () {
                Lock.succeeded = true;
            }],
        [8820, "hello + sweep", function () {
                Lock.phase = Lock.phaseHello;
                Lock.deskHole = 1;
            }],
        [9900, "back to glance", function () {
                Lock.reset();
                Lock.deskHole = 0;
            }],
        [10800, "END", null]
    ]

    function elapsed() {
        return Date.now() - root.startedAt;
    }

    // [elapsed, interval] per rendered frame, in live mode.
    property var samples: []

    function pump() {
        var now = elapsed();
        while (root.cue < root.script.length && now >= root.script[root.cue][0]) {
            var step = root.script[root.cue];
            console.log("CUE " + step[0] + " " + step[1]);
            if (step[2] === null) {
                root.finish();
                return;
            }
            step[2]();
            root.cue++;
        }
        if (!root.live) {
            grab();
        }
    }

    function finish() {
        if (root.live) {
            for (var i = 0; i < root.samples.length; i++) {
                console.log("TICK " + root.samples[i][0] + " " + root.samples[i][1].toFixed(2));
            }
        }
        console.log("FRAMES " + root.frame);
        Qt.exit(0);
    }

    // Drives the walk off the compositor's own frame clock in live mode, and
    // records what that clock actually delivered.
    FrameAnimation {
        running: root.live && root.startedAt > 0

        onTriggered: {
            root.frame++;
            root.samples.push([root.elapsed(), frameTime * 1000]);
            root.pump();
        }
    }

    function grab() {
        var index = root.frame++;
        var at = elapsed();
        stage.grabToImage(function (result) {
            result.saveToFile(root.outDir + "/f" + String(index).padStart(5, "0") + ".bmp");
            console.log("FRAME " + index + " " + at);
            root.pump();
        }, Qt.size(root.grabWidth, root.grabHeight));
    }

    Component.onCompleted: {
        MD.Token.color.useSysColorSM = false;
        MD.Token.color.useSysAccentColor = false;
        MD.Token.color.accentColor = "#78dc77";
        MD.Token.color.paletteType = MD.Enum.PaletteTonalSpot;
        MD.Token.color.mode = root.darkMode ? MD.Enum.Dark : MD.Enum.Light;
        LockTheme.wallpaper = root.wallpaper;
        settle.start();
    }

    // Let the wallpaper decode and the scene reach rest before t=0.
    Timer {
        id: settle

        interval: 900
        onTriggered: {
            root.startedAt = Date.now();
            root.pump();
        }
    }
}
