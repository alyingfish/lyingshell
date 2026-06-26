pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import qs.Commons.Settings

// Per-output wallpaper manager. Holds the selection (persisted in settings.json
// under `wallpaper.perScreen`), scans a source directory for the picker/IPC, and
// signals the Background/Overview surfaces to swap. Trimmed from Noctalia's
// WallpaperService: no favorites, automation, browse modes, solid color,
// online sources, or ImageMagick cache. ponytail: add those when a real need
// shows up.
Singleton {
    id: root

    // Background.qml waits on this before its first paint.
    readonly property bool isInitialized: Settings.isLoaded

    // Real transition keys the shader loader understands (excludes none/random).
    readonly property var allTransitions: ["fade", "disc", "stripes", "wipe", "pixelate", "honeycomb"]

    // Qt-native formats only (no ImageMagick conversion step).
    readonly property var imageFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp", "*.gif"]

    readonly property string defaultDirectory: {
        var d = preprocessPath(Settings.options.wallpaper.directory);
        return d ? d : Settings.homeDir + "/Pictures/Wallpapers";
    }

    // Single source directory → one scanned list shared across outputs.
    property var wallpaperList: []

    // screenName -> path. Background listens; Overview mirrors via the
    // processing-complete signal Background re-emits.
    signal wallpaperChanged(string screenName, string path)
    // cachedPath is always "" here (no resize cache); Overview just needs path.
    signal wallpaperProcessingComplete(string screenName, string path, string cachedPath)
    signal wallpaperListUpdated(int count)

    Component.onCompleted: {
        if (Settings.isLoaded) {
            refreshWallpapersList();
        }
    }

    Connections {
        target: Settings
        function onIsLoadedChanged() {
            if (Settings.isLoaded) {
                root.refreshWallpapersList();
            }
        }
    }

    Connections {
        target: Settings.options.wallpaper
        function onDirectoryChanged() {
            root.refreshWallpapersList();
        }
    }

    // ----------------------------------------------------------------
    function preprocessPath(path) {
        if (!path || typeof path !== "string") {
            return "";
        }
        if (path.startsWith("~/")) {
            return Settings.homeDir + path.substring(1);
        }
        return path;
    }

    function getFillModeUniform() {
        switch (Settings.options.wallpaper.fillMode) {
        case "center":
            return 0.0;
        case "fit":
            return 2.0;
        case "stretch":
            return 3.0;
        case "repeat":
            return 4.0;
        default:
            return 1.0; // crop
        }
    }

    // ----------------------------------------------------------------
    function getWallpaper(screenName) {
        var per = Settings.options.wallpaper.perScreen || {};
        if (per[screenName]) {
            return preprocessPath(per[screenName]);
        }
        if (Settings.options.wallpaper.defaultPath) {
            return preprocessPath(Settings.options.wallpaper.defaultPath);
        }
        // Inherit from any output that does have one, so new monitors aren't blank.
        for (var k in per) {
            if (per[k]) {
                return preprocessPath(per[k]);
            }
        }
        return "";
    }

    function changeWallpaper(path, screenName) {
        if (!path) {
            return;
        }
        var per = Object.assign({}, Settings.options.wallpaper.perScreen || {});
        if (screenName) {
            per[screenName] = path;
            Settings.options.wallpaper.perScreen = per;
            wallpaperChanged(screenName, preprocessPath(path));
        } else {
            Settings.options.wallpaper.defaultPath = path;
            for (var i = 0; i < Quickshell.screens.length; i++) {
                per[Quickshell.screens[i].name] = path;
            }
            Settings.options.wallpaper.perScreen = per;
            for (var j = 0; j < Quickshell.screens.length; j++) {
                wallpaperChanged(Quickshell.screens[j].name, preprocessPath(path));
            }
        }
    }

    function setRandomWallpaper(screenName) {
        if (root.wallpaperList.length === 0) {
            return;
        }
        var p = root.wallpaperList[Math.floor(Math.random() * root.wallpaperList.length)];
        changeWallpaper(p, screenName);
    }

    // ----------------------------------------------------------------
    function refreshWallpapersList() {
        var dir = root.defaultDirectory;
        if (!dir || scanProcess.running) {
            return;
        }
        var args = ["find", "-L", dir, "-maxdepth", "1", "-mindepth", "1", "-type", "f", "("];
        for (var i = 0; i < root.imageFilters.length; i++) {
            if (i > 0) {
                args.push("-o");
            }
            args.push("-iname", root.imageFilters[i]);
        }
        args.push(")");
        scanProcess.command = args;
        scanProcess.running = true;
    }

    Process {
        id: scanProcess
        stdout: StdioCollector {}
        onExited: function (exitCode, exitStatus) {
            var files = [];
            if (exitCode === 0) {
                var lines = scanProcess.stdout.text.split('\n');
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line !== '' && !line.split('/').pop().startsWith('.')) {
                        files.push(line);
                    }
                }
                files.sort(function (a, b) {
                    return a.split('/').pop().localeCompare(b.split('/').pop());
                });
            }
            root.wallpaperList = files;
            root.wallpaperListUpdated(files.length);
        }
    }

    // ----------------------------------------------------------------
    // `qs ipc call wallpaper set <path> [output]`, `... random [output]`,
    // `... get [output]`. Output omitted → applies to every screen.
    IpcHandler {
        target: "wallpaper"

        function set(path: string, output: string): void {
            root.changeWallpaper(path, output && output.length > 0 ? output : undefined);
        }

        function random(output: string): void {
            root.setRandomWallpaper(output && output.length > 0 ? output : undefined);
        }

        function get(output: string): string {
            var name = output && output.length > 0 ? output : (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "");
            return root.getWallpaper(name);
        }
    }
}
