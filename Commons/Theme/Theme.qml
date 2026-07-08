pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import Qcm.Material as MD
import qs.Commons.Settings
import qs.Services.Wallpaper

Singleton {
    id: root

    readonly property string textTypeface: Settings.options.appearance.font
    readonly property string requestedMode: Settings.options.appearance.mode
    readonly property string effectiveMode: requestedMode === "dark" ? "dark" : "light"

    // Wallpaper-derived accent, reactive on the persisted per-mode cache. This is
    // the source of truth at startup AND after a fresh extraction, so the correct
    // color is present on the very first frame with no matugen on the boot path.
    // useWallpaperColor selects whether it drives the theme; the matugen seed
    // never overwrites the user's accentColor in settings.json.
    readonly property string wallpaperAccent: effectiveMode === "dark" ? accentCacheData.dark : accentCacheData.light
    readonly property string requestedAccentColor: Settings.options.appearance.useWallpaperColor && wallpaperAccent.length > 0 ? wallpaperAccent : Settings.options.appearance.accentColor

    // Source screen for wallpaper-derived accent: first screen.
    // ponytail: single source screen; add a setting if multi-monitor ever needs
    // separate accents.
    readonly property string colorSourceScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""

    // Shell-owned matugen config + templates live next to this file.
    readonly property string matugenDir: Qt.resolvedUrl("matugen").toString().replace(/^file:\/\//, "")

    // Derived-accent cache dir. Fully regenerable (we re-extract every start), so
    // it belongs under XDG_CACHE_HOME; falls back to ~/.cache.
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || ((Quickshell.env("HOME") || "") + "/.cache")) + "/lyingshell"

    Component.onCompleted: {
        // FileView won't create the parent dir; ensure it before any write.
        ensureCacheDir.running = true;
        // Don't theme off a not-yet-loaded mode. Settings load asynchronously;
        // until they land, appearance.mode falls back to the adapter default
        // ("light"). Acting on that stale mode makes accentPush regenerate every
        // app theme (kitty/ghostty/gtk…) in LIGHT and SIGUSR1-reload the apps,
        // flashing the whole desktop before mode flips to dark. So the first
        // apply/push is deferred to onIsLoadedChanged below. blockLoading on the
        // Settings FileView does NOT help — cross-singleton init runs this
        // handler before that load populates the adapter.
        if (Settings.isLoaded) {
            applyAll();
        }
    }

    // Fires the initial apply/push exactly once, when settings are loaded and the
    // real persisted mode is known.
    Connections {
        target: Settings
        function onIsLoadedChanged() {
            if (Settings.isLoaded) {
                root.applyAll();
            }
        }
    }

    function applyAll() {
        apply();
        // pushAccentColor() regenerates the app themes AND then flips
        // color-scheme/gtk-theme, in that order, in ONE script. Open libadwaita
        // apps (nautilus) re-read lyingshell.css on the color-scheme change, so
        // the css must be rewritten first — otherwise they re-read the old mode's
        // pinned colors and stick. Two racing processes can't guarantee that
        // order (a preempted regen fires the scheme flip early), so the scheme
        // flip lives at the tail of accentPush, not in a separate process.
        pushAccentColor();
        // No matugen on the boot path: the wallpaperAccent binding already
        // supplies the cached color. This is a no-op unless the cache is stale
        // for the current wallpaper+mode (cold first run / wallpaper changed
        // while the shell was down).
        maybeExtractFromWallpaper();
    }

    onEffectiveModeChanged: {
        // Skip the load-time "light"→persisted transition; onIsLoadedChanged owns
        // the first push. Only real, post-load mode changes reach here.
        if (!Settings.isLoaded) {
            return;
        }
        applyAll();
    }
    onRequestedAccentColorChanged: {
        if (!Settings.isLoaded) {
            return;
        }
        apply();
        pushAccentColor();
    }

    function apply() {
        MD.Token.color.useSysColorSM = false;
        MD.Token.color.useSysAccentColor = false;
        MD.Token.color.accentColor = requestedAccentColor;
        MD.Token.color.paletteType = MD.Enum.PaletteTonalSpot;
        MD.Token.color.mode = effectiveMode === "dark" ? MD.Enum.Dark : MD.Enum.Light;
    }

    // Push the accent to external apps via matugen, run once per installed app
    // (no conditional templates) with the mode's ANSI hues injected as JSON.
    function pushAccentColor() {
        accentPush.run(requestedAccentColor, effectiveMode, matugenDir);
    }

    Process {
        id: accentPush

        function run(accent, mode, dir) {
            if (dir.length === 0) {
                return;
            }
            if (running) {
                running = false;
            }
            // Three sequential phases in one script, ordered so nautilus flips ASAP:
            //   1. matugen regenerates the GTK CSS on disk.
            //   2. THEN flip freedesktop color-scheme + adw-gtk3 gtk-theme so
            //      portal/libadwaita apps (nautilus) re-read the fresh
            //      lyingshell.css and legacy GTK3 follows. The scheme flip MUST
            //      come after step 1 — libadwaita re-reads the pinned @define-color
            //      set on the color-scheme change, so flipping it before the css
            //      is rewritten makes open apps latch the old mode and stick.
            //   3. THEN the terminals (kitty/ghostty/alacritty/niri). They ignore
            //      color-scheme; kitty live-reloads via its matugen post_hook
            //      SIGUSR1. Doing GTK first is why nautilus no longer waits behind
            //      ~5 serial terminal matugen spawns before its only reload trigger.
            // A preempted run (running=false on a rapid re-trigger) killed during
            // the GTK regen dies before the flip, so only a completed GTK regen
            // flips the scheme — no early flip, no white flash (scheme goes
            // straight to the target, no bounce).
            // ponytail: gsettings/dconf only; standard theme dirs only.
            command = ["sh", "-c", `
ACCENT="$1"; MODE="$2"; DIR="$3"; IFACE=org.gnome.desktop.interface;
if [ "$MODE" = "dark" ]; then
  SCHEME=prefer-dark; GTK=adw-gtk3-dark;
  ANSI='{"red":"#f38ba8","green":"#a6e3a1","yellow":"#f9e2af","blue":"#89b4fa","magenta":"#f5c2e7","cyan":"#94e2d5"}';
else
  SCHEME=prefer-light; GTK=adw-gtk3;
  ANSI='{"red":"#d20f39","green":"#40a02b","yellow":"#df8e1d","blue":"#1e66f5","magenta":"#ea76cb","cyan":"#179299"}';
fi;
MATUGEN=0;
if command -v matugen >/dev/null 2>&1 && cd "$DIR" 2>/dev/null; then
  MATUGEN=1;
  gen() { matugen color hex "$ACCENT" -m "$MODE" -t scheme-tonal-spot -q -c "$1" --import-json-string "$ANSI"; };
  [ -d "$HOME/.config/gtk-3.0" ] && { gen gtk3.toml; sh gtk-import.sh "$HOME/.config/gtk-3.0"; };
  [ -d "$HOME/.config/gtk-4.0" ] && { gen gtk4.toml; sh gtk-import.sh "$HOME/.config/gtk-4.0"; };
fi;
have_theme() { [ -d "$HOME/.local/share/themes/$1" ] || [ -d "$HOME/.themes/$1" ] || [ -d "/usr/share/themes/$1" ]; };
if command -v gsettings >/dev/null 2>&1; then
  gsettings set "$IFACE" color-scheme "$SCHEME";
  have_theme "$GTK" && gsettings set "$IFACE" gtk-theme "$GTK";
elif command -v dconf >/dev/null 2>&1; then
  dconf write /org/gnome/desktop/interface/color-scheme "'$SCHEME'";
  have_theme "$GTK" && dconf write /org/gnome/desktop/interface/gtk-theme "'$GTK'";
fi;
if [ "$MATUGEN" = 1 ]; then
  command -v kitty >/dev/null 2>&1 && gen kitty.toml;
  command -v ghostty >/dev/null 2>&1 && gen ghostty.toml;
  command -v alacritty >/dev/null 2>&1 && gen alacritty.toml;
  command -v niri >/dev/null 2>&1 && gen niri.toml;
fi
`, "sh", accent, mode, dir];
            running = true;
        }
    }

    // On a wallpaper or mode change, re-derive the matugen primary and cache it;
    // the wallpaperAccent binding then drives apply()/pushAccentColor through
    // requestedAccentColor. mode stays manual.
    Connections {
        target: Settings.options.appearance
        function onUseWallpaperColorChanged() {
            root.maybeExtractFromWallpaper();
        }
    }
    Connections {
        target: Wallpaper
        function onWallpaperChanged(screenName, path) {
            if (screenName === root.colorSourceScreen) {
                root.maybeExtractFromWallpaper();
            }
        }
    }

    // Derive only when the current wallpaper+mode isn't already cached. This is
    // what lets every startup signal cascade — settings load flipping
    // useWallpaperColor, the mode flip, an initial wallpaper event — skip matugen
    // when the cache is warm, while a real wallpaper change (path differs) still
    // re-derives.
    function needsDerive() {
        if (!Settings.options.appearance.useWallpaperColor) {
            return false;
        }
        var wp = Wallpaper.getWallpaper(root.colorSourceScreen);
        if (!wp) {
            return false; // wallpaper not known yet; a later wallpaperChanged retries
        }
        return !(accentCacheData.path === wp && wallpaperAccent.length > 0);
    }

    function maybeExtractFromWallpaper() {
        if (!needsDerive()) {
            return;
        }
        // Debounce: picker drags can fire many wallpaperChanged in a row.
        extractDebounce.restart();
    }

    // Persist the derived accent for a mode, keyed by the wallpaper it came from.
    // A new wallpaper invalidates the other mode's entry (derived from the old
    // image), forcing a re-derive when that mode is next used.
    function cacheAccent(mode, accent) {
        var wp = Wallpaper.getWallpaper(root.colorSourceScreen);
        if (accentCacheData.path !== wp) {
            accentCacheData.light = "";
            accentCacheData.dark = "";
            accentCacheData.path = wp;
        }
        if (mode === "dark") {
            accentCacheData.dark = accent;
        } else {
            accentCacheData.light = accent;
        }
        accentCache.writeAdapter();
    }

    Timer {
        id: extractDebounce
        interval: 150
        onTriggered: extractAccent.run(Wallpaper.getWallpaper(root.colorSourceScreen), root.effectiveMode)
    }

    Process {
        id: extractAccent
        stdout: StdioCollector {}

        function run(path, mode) {
            if (!path) {
                return;
            }
            if (running) {
                running = false;
            }
            // --prefer saturation: matugen errors non-interactively on images
            // with multiple candidate source colors without a preference.
            command = ["sh", "-c", 'command -v matugen >/dev/null 2>&1 || exit 0; ' + 'matugen image "$1" -m "$2" --prefer saturation -j hex --dry-run', "sh", path, mode];
            running = true;
        }

        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0) {
                return;
            }
            var accent = root.parseAccent(stdout.text, root.effectiveMode);
            if (accent) {
                // Persist only; the wallpaperAccent binding + apply() pick it up
                // reactively, and the next start/reload reads it with no matugen.
                root.cacheAccent(root.effectiveMode, accent);
            }
        }
    }

    Process {
        id: ensureCacheDir
        command: ["mkdir", "-p", root.cacheDir]
    }

    // Per-mode derived accent + the wallpaper path it came from, read
    // synchronously (blockLoading) so the wallpaperAccent binding has the color
    // before the first frame. We own this file, so no watchChanges. printErrors
    // off: a cold-cache miss is expected on first run.
    FileView {
        id: accentCache
        path: root.cacheDir + "/wallpaper-accent.json"
        blockLoading: true
        printErrors: false

        adapter: JsonAdapter {
            id: accentCacheData
            property string path: ""
            property string light: ""
            property string dark: ""
        }
    }

    // Pull colors.primary.<mode>.color out of matugen's JSON dump. Returns ""
    // on any malformed/missing input so callers can no-op safely.
    function parseAccent(jsonText, mode) {
        try {
            var primary = JSON.parse(jsonText).colors.primary[mode].color;
            return /^#[0-9a-fA-F]{6}$/.test(primary) ? primary : "";
        } catch (e) {
            return "";
        }
    }
}
