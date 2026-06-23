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

    Component.onCompleted: {
        apply();
        pushSystemMode();
    }

    onEffectiveModeChanged: {
        apply();
        pushSystemMode();
    }
    onRequestedAccentColorChanged: apply()

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
}
