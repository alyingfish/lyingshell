pragma Singleton

import QtQml
import QtQuick
import Quickshell
import Quickshell.Io
import Qcm.Material as MD
import qs.Commons.Settings
import qs.Commons.Theme
import qs.Services.Wallpaper

// The lock screen's own palette.
//
// The lock has its own photo and its own matugen scheme, apart from the
// desktop's, but follows the one shared dark/light setting — the prototype's
// rule (src/lock/color/scheme.js + src/theme/mode.js). Two things follow from
// that:
//
//  * The seed is derived from the LOCK wallpaper, cached per mode next to the
//    desktop's accent cache, so a start with a warm cache never waits on
//    matugen (same pipeline as Theme.qml, keyed on a different image).
//  * While the lock is up the process wears that seed (Theme.accentOverride).
//    QmlMaterial's MD.Token.color is one process-wide scheme, and the shell's
//    own components read it directly, so a second MD.MdColorMgr handed down a
//    subtree (MD.MProp.color) would re-tint the QmlMaterial parts and leave
//    every lyingshell component on the desktop palette. Swapping the seed is
//    what makes the quick-settings panel follow the surface it serves, which
//    is what css/lock.css does in the prototype. Nothing is pushed to external
//    apps, and the desktop's own seed comes back on unlock.
//
// The roles MD3 does not name are composed from spec roles, never invented:
// `onwall` is the opposite mode's surface (the far neutral of the same
// palette) for ink that sits directly on the photo; the glass pair and the
// auth scrim are translucent surface roles at the prototype's own alphas.
Singleton {
    id: root

    // Set by Services/Lock.qml while the lock surfaces are up.
    property bool active: false

    readonly property bool dark: Theme.effectiveMode === "dark"

    // Source screen for the wallpaper fallback — the same "first screen" rule
    // Theme.qml uses for the desktop accent.
    readonly property string sourceScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""

    readonly property string wallpaper: {
        var configured = Settings.options.lock.wallpaper;
        if (configured && configured.length > 0) {
            return configured.startsWith("~/") ? Settings.homeDir + configured.substring(1) : configured;
        }
        // No lock photo set: wear the desktop's, so the lock is never blank.
        return Wallpaper.getWallpaper(root.sourceScreen);
    }

    // Per-mode seed for the lock photo. Empty until matugen has run once for
    // this image; the override stays off until then, so the lock simply opens
    // on the desktop palette rather than on a wrong one.
    readonly property string accent: dark ? accentCacheData.dark : accentCacheData.light
    readonly property string oppositeAccent: dark ? accentCacheData.light : accentCacheData.dark

    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || ((Quickshell.env("HOME") || "") + "/.cache")) + "/lyingshell"

    onActiveChanged: root.push()
    onAccentChanged: root.push()

    function push() {
        Theme.accentOverride = active && accent.length > 0 ? accent : "";
    }

    Component.onCompleted: {
        // Same blocking read as Theme.qml: blockLoading only makes text()/data()
        // block, so without this the lock seed lands asynchronously and a warm
        // cache still looks cold to needsDerive() — a matugen run at every boot,
        // and a lock opened in that window wears the desktop palette.
        accentCache.text();
        maybeExtract();
    }
    onWallpaperChanged: maybeExtract()

    Connections {
        target: Settings
        function onIsLoadedChanged() {
            if (Settings.isLoaded) {
                root.maybeExtract();
            }
        }
    }

    function needsDerive() {
        if (!wallpaper || wallpaper.length === 0) {
            return false;
        }
        return !(accentCacheData.path === wallpaper && accentCacheData.light.length > 0 && accentCacheData.dark.length > 0);
    }

    function maybeExtract() {
        if (!Settings.isLoaded || !needsDerive()) {
            return;
        }
        extractDebounce.restart();
    }

    Timer {
        id: extractDebounce
        interval: 150
        onTriggered: extractAccent.run(root.wallpaper)
    }

    // One matugen run yields both modes, so the cache is never half-warm and a
    // dark/light flip while locked can't fall back to the desktop seed.
    Process {
        id: extractAccent
        stdout: StdioCollector {}

        property string sourcePath: ""

        function run(path) {
            if (!path) {
                return;
            }
            sourcePath = path;
            if (running) {
                running = false;
            }
            command = ["sh", "-c", 'command -v matugen >/dev/null 2>&1 || exit 0; ' + 'matugen image "$1" --prefer saturation -j hex --dry-run', "sh", path];
            running = true;
        }

        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0) {
                return;
            }
            var light = Theme.parseAccent(stdout.text, "light");
            var dark = Theme.parseAccent(stdout.text, "dark");
            if (light && dark) {
                accentCacheData.path = sourcePath;
                accentCacheData.light = light;
                accentCacheData.dark = dark;
                accentCache.writeAdapter();
                root.push();
            }
        }
    }

    FileView {
        id: accentCache
        path: root.cacheDir + "/lock-accent.json"
        blockLoading: true
        printErrors: false

        adapter: JsonAdapter {
            id: accentCacheData
            property string path: ""
            property string light: ""
            property string dark: ""
        }
    }

    // ---- off-spec roles, composed from spec roles ------------------------
    // These read MD.Token.color, which IS the lock palette while `active` (see
    // the header). Off the lock they resolve against the desktop palette,
    // which is what the offscreen visual harness wants.

    function withAlpha(base, a) {
        return Qt.rgba(base.r, base.g, base.b, a);
    }

    // The opposite mode's neutral, for ink laid directly on the photo. Built
    // from the lock seed for the OTHER mode, so it is the same palette's far
    // end rather than a second, unrelated scheme.
    property MD.MdColorMgr oppositeScheme: MD.MdColorMgr {
        useSysColorSM: false
        useSysAccentColor: false
        paletteType: MD.Enum.PaletteTonalSpot
        mode: root.dark ? MD.Enum.Light : MD.Enum.Dark
        accentColor: root.oppositeAccent.length > 0 ? root.oppositeAccent : MD.Token.color.accentColor
    }

    readonly property color onWall: oppositeScheme.surface
    readonly property color onWallDim: withAlpha(onWall, 0.74)

    // The tray pill and the password pill: a translucent surface container.
    readonly property color glass: withAlpha(dark ? MD.Token.color.surface_container : MD.Token.color.surface_container_low, dark ? 0.62 : 0.60)
    readonly property color glassHigh: withAlpha(dark ? MD.Token.color.surface_container_high : MD.Token.color.surface, 0.78)

    // The wash that comes in with the prompt. Nothing else ever sits between
    // the photo and the eye.
    readonly property color authScrim: withAlpha(dark ? MD.Token.color.surface_dim : MD.Token.color.surface_bright, dark ? 0.44 : 0.40)

    // The clock wears the mode's own primary/tertiary, so the ink on the wall
    // follows the dark/light switch like every other role does.
    readonly property color clockHours: MD.Token.color.primary
    readonly property color clockMinutes: MD.Token.color.tertiary
}
