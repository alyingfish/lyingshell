pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import Qcm.Material as MD
import qs.Commons.Settings
import qs.Services.Wallpaper

Singleton {
    id: root

    readonly property string textTypeface: Settings.options.theme.font
    readonly property string requestedMode: Settings.options.theme.mode
    readonly property string requestedAccentColor: Settings.options.theme.accentColor
    readonly property string effectiveMode: requestedMode === "dark" ? "dark" : "light"

    // Source screen for wallpaper-derived accent: first screen.
    // ponytail: single source screen; add a setting if multi-monitor ever needs
    // separate accents.
    readonly property string colorSourceScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""

    // Shell-owned matugen config + templates live next to this file.
    readonly property string matugenDir: Qt.resolvedUrl("matugen").toString().replace(/^file:\/\//, "")

    Component.onCompleted: {
        apply();
        pushSystemMode();
        pushAccentColor();
    }

    onEffectiveModeChanged: {
        apply();
        pushSystemMode();
        pushAccentColor();
        // Primary differs per mode; re-extract if wallpaper colors are on.
        maybeExtractFromWallpaper();
    }
    onRequestedAccentColorChanged: {
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

    // Push mode onto the freedesktop color-scheme + adw-gtk3 theme name so
    // portal apps and legacy GTK3 follow. light maps to "default".
    // ponytail: gsettings/dconf only. Qt-non-portal and KDE are later phases.
    function pushSystemMode() {
        systemModePush.run(effectiveMode === "dark");
    }

    Process {
        id: systemModePush

        function run(dark) {
            const scheme = dark ? "prefer-dark" : "default";
            const gtk = dark ? "adw-gtk3-dark" : "adw-gtk3";
            const iface = "org.gnome.desktop.interface";
            if (running) {
                running = false;
            }
            command = ["sh", "-c", "if command -v gsettings >/dev/null 2>&1; then " + "gsettings set " + iface + " color-scheme '" + scheme + "'; " + "gsettings set " + iface + " gtk-theme '" + gtk + "'; " + "elif command -v dconf >/dev/null 2>&1; then " + "dconf write /org/gnome/desktop/interface/color-scheme \"'" + scheme + "'\"; " + "dconf write /org/gnome/desktop/interface/gtk-theme \"'" + gtk + "'\"; fi"];
            running = true;
        }
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
            command = ["sh", "-c", 'ACCENT="$1"; MODE="$2"; DIR="$3"; ' + "command -v matugen >/dev/null 2>&1 || exit 0; " + 'cd "$DIR" 2>/dev/null || exit 0; ' + 'if [ "$MODE" = "dark" ]; then ' + 'ANSI=\'{"red":"#f38ba8","green":"#a6e3a1","yellow":"#f9e2af","blue":"#89b4fa","magenta":"#f5c2e7","cyan":"#94e2d5"}\'; ' + 'else ' + 'ANSI=\'{"red":"#d20f39","green":"#40a02b","yellow":"#df8e1d","blue":"#1e66f5","magenta":"#ea76cb","cyan":"#179299"}\'; ' + 'fi; ' + 'gen() { matugen color hex "$ACCENT" -m "$MODE" -t scheme-tonal-spot -q -c "$1" --import-json-string "$ANSI"; }; ' + "command -v kitty >/dev/null 2>&1 && gen kitty.toml; " + "command -v ghostty >/dev/null 2>&1 && gen ghostty.toml; " + "command -v alacritty >/dev/null 2>&1 && gen alacritty.toml; " + "command -v niri >/dev/null 2>&1 && gen niri.toml; " + '[ -d "$HOME/.config/gtk-3.0" ] && gen gtk3.toml; ' + '[ -d "$HOME/.config/gtk-4.0" ] && gen gtk4.toml; ' + "exit 0", "sh", accent, mode, dir];
            running = true;
        }
    }

    // When useWallpaperColor is on, extract the wallpaper's matugen primary into
    // theme.accentColor (which drives apply()/pushAccentColor). mode stays manual.
    Connections {
        target: Settings.options.theme
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

    function maybeExtractFromWallpaper() {
        if (!Settings.options.theme.useWallpaperColor) {
            return;
        }
        // Debounce: picker drags can fire many wallpaperChanged in a row.
        extractDebounce.restart();
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
                Settings.options.theme.accentColor = accent;
            }
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
