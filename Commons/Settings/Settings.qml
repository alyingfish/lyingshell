pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool isLoaded: false
    property bool creatingRuntimeFile: false
    property bool loadingRuntimeFile: false
    property string errorMessage: ""

    readonly property alias options: settingsAdapter
    readonly property string homeDir: String(Quickshell.env("HOME") || "")
    readonly property string configDir: homeDir + "/.config/lyingshell"
    readonly property string settingsPath: configDir + "/settings.json"

    Component.onCompleted: initialize()

    Timer {
        id: externalReloadTimer
        interval: 160
        repeat: false

        onTriggered: {
            if (runtimeSettingsFile.path.length > 0) {
                root.reloadRuntimeSettings();
            }
        }
    }

    Process {
        id: createConfigDir
        command: ["mkdir", "-p", root.configDir]

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.ensureLoadedWithDefaults();
                root.handleRuntimeSettingsError("Failed to create settings directory");
                return;
            }

            // Dir exists now; write out the default settings file.
            root.createRuntimeSettingsFile();
        }
    }

    Process {
        id: settingsErrorNotifier

        property string notificationTitle: "Lying Shell settings error"

        function notify(message) {
            if (running) {
                running = false;
            }

            command = ["notify-send", notificationTitle, message];
            running = true;
        }

        command: ["notify-send", notificationTitle, ""]
    }

    FileView {
        id: runtimeSettingsFile
        // Load settings.json directly. The config dir already exists on every
        // run after the first, so the happy path skips the mkdir Process;
        // it's only spawned lazily on the first-run FileNotFound branch below.
        path: root.homeDir.length > 0 ? root.settingsPath : ""
        printErrors: false
        watchChanges: true

        onFileChanged: externalReloadTimer.restart()

        onLoaded: {
            root.loadingRuntimeFile = false;
            root.isLoaded = true;
            root.errorMessage = "";
        }

        onSaved: {
            if (root.creatingRuntimeFile) {
                root.creatingRuntimeFile = false;
                root.reloadRuntimeSettings();
            }
        }

        onLoadFailed: function(error) {
            root.loadingRuntimeFile = false;
            if (error === FileViewError.FileNotFound) {
                // First run (or dir missing): ensure the dir, then write
                // defaults from createConfigDir.onExited.
                createConfigDir.running = true;
                return;
            }

            root.ensureLoadedWithDefaults();
            root.handleRuntimeSettingsError("Failed to load settings: " + FileViewError.toString(error));
        }

        onSaveFailed: function(error) {
            root.creatingRuntimeFile = false;
            root.loadingRuntimeFile = false;
            root.ensureLoadedWithDefaults();
            root.handleRuntimeSettingsError("Failed to create settings file: " + FileViewError.toString(error));
        }

        onAdapterUpdated: {
            if (!root.isLoaded || root.loadingRuntimeFile || root.creatingRuntimeFile) {
                return;
            }

            writeAdapter();
        }

        adapter: JsonAdapter {
            id: settingsAdapter

            property JsonObject appearance: JsonObject {
                property string language: "en"
                property string mode: "light"
                property string accentColor: "#6750A4"
                property string font: "Noto Sans"
                // Derive the runtime accent from the wallpaper via matugen.
                // The derived color stays in memory (Theme.wallpaperAccent);
                // it never overwrites accentColor in this file.
                property bool useWallpaperColor: true
                // Drop spatial motion that travels a long way (the lock/unlock
                // sweep). Fades and small settles keep running: a fade is not
                // motion, and dropping them would only remove feedback.
                property bool reducedMotion: false
            }
            property JsonObject lock: JsonObject {
                // The lock screen dresses itself from its own photo and its own
                // matugen palette, on the shared appearance.mode. "" falls back
                // to the desktop wallpaper of the output it is shown on.
                property string wallpaper: ""
                // Portrait clipped by the scallop; "" draws the tonal plate with
                // the account's initial instead.
                property string avatar: ""
                // Display name above the password pill; "" uses $USER.
                property string fullName: ""
                // The full scene (avatar, prompt, tray) on the focused output
                // only; every other output gets wallpaper and clock. False puts
                // the full scene on every output.
                property bool focusedOutputOnly: true
                // PAM service under /etc/pam.d; "" picks the first of
                // lyingshell / system-auth / login that exists.
                property string pamConfig: ""
            }
            property JsonObject bar: JsonObject {
                property string currentShape: "autoShape"
                // Per-shape fields; `radius` applied per shape by BarSurface.
                // height + exclusiveZone are per-shape: the bar reserves exactly
                // exclusiveZone from the top edge.
                // `blur` toggles compositor background blur behind the surface
                // (on/off only — the compositor picks the strength).
                // NOTE: all shapes default to the same exclusiveZone to avoid
                // stuttering during window resizing — an unequal value re-tiles
                // the output on that shape/hide switch.
                property JsonObject shape: JsonObject {
                    property JsonObject floating: JsonObject {
                        property int margin: 8
                        property int radius: 16
                        property real elevation: 3
                        property real opacity: 0.92
                        property bool blur: true
                        property int height: 32
                        property int exclusiveZone: 32
                    }
                    property JsonObject softAttach: JsonObject {
                        property int margin: 0
                        property int radius: 16
                        property real elevation: 3
                        property real opacity: 0.92
                        property bool blur: true
                        property int height: 32
                        property int exclusiveZone: 32
                    }
                    property JsonObject fullWidth: JsonObject {
                        property int margin: 0
                        property int radius: 0
                        property real elevation: 0
                        property real opacity: 1.0
                        property bool blur: false
                        property int height: 32
                        property int exclusiveZone: 32
                    }
                    property JsonObject hug: JsonObject {
                        property int margin: 0
                        property int radius: 16
                        property real elevation: 0
                        property real opacity: 1.0
                        property bool blur: false
                        property int height: 32
                        property int exclusiveZone: 32
                    }
                    // Hidden keeps no visual config (it borrows the last visible
                    // shape's look while sliding away); only its reserve is its
                    // own setting, so hiding never changes the reserved strip.
                    property JsonObject hidden: JsonObject {
                        property int exclusiveZone: 32
                    }
                    // autoShape state→shape map; "" = fall through. See
                    // Modules/Bar/AutoShape.js.
                    property JsonObject autoShape: JsonObject {
                        property string noWindowShape: "floating"
                        property string hasWindowShape: "fullWidth"
                        property string floatingWindowShape: "softAttach"
                        property string maximizedColumnShape: "hug"
                        property string overviewShape: "hidden"
                        property string lockscreenShape: "hidden"
                        property string unfocusedOutputShape: ""
                    }
                }
                property JsonObject widgets: JsonObject {
                    property JsonObject quickSettingsButton: JsonObject {
                        // Bar pill battery percent text: always | never | whenLow.
                        property string showBatteryValue: "whenLow"
                    }
                    property JsonObject tray: JsonObject {
                        // Tray items whose id/title matches any regex stay in the
                        // pinned zone; the rest go to the overflow popover.
                        property var pinnedRegexes: ["syncthing"]
                        // Item ids in display order for the overflow popover;
                        // unlisted items follow in service order.
                        property var overflowOrder: []
                        // Auto-recolor only freedesktop *-symbolic tray icons to the
                        // theme foreground (on_surface); colored logos render raw and
                        // keep their hue. Turn off to never recolor.
                        property bool recolorIcons: true
                    }
                    property JsonObject workspaces: JsonObject {
                        property bool scrollLoop: true
                        property bool urgentPulse: true
                    }
                }
            }
            property JsonObject quickSettings: JsonObject {
                property JsonObject colorPicker: JsonObject {
                    // Last picked colors, newest first ("#rrggbb"); written by
                    // QuickSettingsPanel on every pick (deduped, capped at its
                    // maxRecentColors) and shown by the readout's Recent grid.
                    property var recentColors: []
                }
                property JsonObject widgets: JsonObject {
                    property JsonObject nightLight: JsonObject {
                        // Manual quick-settings toggle; Services/NightLight.qml
                        // owns the wlsunset process bound to it.
                        property bool enabled: false
                        property int temperature: 4000
                    }
                }
            }
            property JsonObject wallpaper: JsonObject {
                property bool enabled: true
                // Source folder scanned for the picker/IPC; "" → ~/Pictures/Wallpapers.
                property string directory: ""
                // Per-output selection: { "DP-1": "/path/a.jpg", ... }.
                property var perScreen: ({})
                // Shown on any output without a perScreen entry.
                property string defaultPath: ""
                // center | crop | fit | stretch | repeat (maps to shader uniform).
                property string fillMode: "crop"
                property string fillColor: "#000000"
                // Pool to pick from on each change; random when >1, "none" = instant.
                property var transitionType: ["disc"]
                property int transitionDuration: 1000
                property real transitionEdgeSmoothness: 0.05
                // Niri overview backdrop (needs a place-within-backdrop layer rule).
                property bool overviewEnabled: true
                property real overviewBlur: 16
                property real overviewTint: 0.3
            }
        }
    }

    function initialize() {
        // settings.json loads via runtimeSettingsFile.path; the config dir is
        // created lazily on the first-run FileNotFound branch. Nothing to do
        // here but flag a missing HOME (which leaves the load path empty).
        if (homeDir.length === 0) {
            errorMessage = "HOME is not set";
        }
    }

    function reloadRuntimeSettings() {
        loadingRuntimeFile = true;
        runtimeSettingsFile.reload();
    }

    function createRuntimeSettingsFile() {
        creatingRuntimeFile = true;
        runtimeSettingsFile.writeAdapter();
    }

    function ensureLoadedWithDefaults() {
        if (isLoaded) {
            return;
        }

        isLoaded = true;
    }

    function handleRuntimeSettingsError(message) {
        errorMessage = message;
        console.warn("[Settings] " + message);
        settingsErrorNotifier.notify(message);
    }
}
