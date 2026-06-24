pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import Qcm.Material as MD
import qs.Commons.Settings

Singleton {
    id: root

    readonly property string textTypeface: Settings.options.theme.font
    readonly property string requestedMode: Settings.options.theme.mode
    readonly property string requestedAccentColor: Settings.options.theme.accentColor
    readonly property string effectiveMode: requestedMode === "dark" ? "dark" : "light"

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

    // Lying Shell is the desktop, so its mode is authority: push it onto the
    // freedesktop color-scheme so portal-aware apps (libadwaita/GTK4, Qt6,
    // Electron) follow, plus the adw-gtk3 theme name so legacy GTK3 apps switch.
    // light maps to "default" (universally accepted; "prefer-light" is newer).
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

    // Push the accent out to external apps via matugen. matugen has no
    // conditional templates, so we run it once per *installed* app with a
    // per-app config (selective: absent apps get nothing written), injecting
    // the mode's fixed ANSI accent hues as JSON. Mirrors pushSystemMode.
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
            command = ["sh", "-c", 'ACCENT="$1"; MODE="$2"; DIR="$3"; ' + "command -v matugen >/dev/null 2>&1 || exit 0; " + 'cd "$DIR" 2>/dev/null || exit 0; ' + 'if [ "$MODE" = "dark" ]; then ' + 'ANSI=\'{"red":"#e06c75","green":"#98c379","yellow":"#e5c07b","blue":"#61afef","magenta":"#c678dd","cyan":"#56b6c2"}\'; ' + 'else ' + 'ANSI=\'{"red":"#d20f39","green":"#40a02b","yellow":"#df8e1d","blue":"#1e66f5","magenta":"#ea76cb","cyan":"#179299"}\'; ' + 'fi; ' + 'gen() { matugen color hex "$ACCENT" -m "$MODE" -t scheme-tonal-spot -q -c "$1" --import-json-string "$ANSI"; }; ' + "command -v kitty >/dev/null 2>&1 && gen kitty.toml; " + "command -v ghostty >/dev/null 2>&1 && gen ghostty.toml; " + "command -v alacritty >/dev/null 2>&1 && gen alacritty.toml; " + "command -v niri >/dev/null 2>&1 && gen niri.toml; " + '[ -d "$HOME/.config/gtk-3.0" ] && gen gtk3.toml; ' + '[ -d "$HOME/.config/gtk-4.0" ] && gen gtk4.toml; ' + "exit 0", "sh", accent, mode, dir];
            running = true;
        }
    }
}
