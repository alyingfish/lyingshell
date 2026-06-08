pragma Singleton

import QtQml
import Quickshell
import Qcm.Material as MD
import qs.Commons.Settings

Singleton {
    id: root

    readonly property string requestedMode: Settings.themeMode
    readonly property string effectiveMode: requestedMode === "dark" ? "dark" : "light"

    Component.onCompleted: apply()

    Connections {
        target: Settings

        function onThemeModeChanged() {
            root.apply();
        }

        function onAccentColorChanged() {
            root.apply();
        }
    }

    function apply() {
        MD.Token.color.useSysColorSM = false;
        MD.Token.color.useSysAccentColor = false;
        MD.Token.color.accentColor = Settings.accentColor;
        MD.Token.color.paletteType = MD.Enum.PaletteTonalSpot;
        MD.Token.color.mode = effectiveMode === "dark" ? MD.Enum.Dark : MD.Enum.Light;
    }
}
