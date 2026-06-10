pragma Singleton

import QtQml
import Quickshell
import Qcm.Material as MD
import qs.Commons.Settings

Singleton {
    id: root

    readonly property string requestedMode: Settings.options.theme.mode
    readonly property string requestedAccentColor: Settings.options.theme.accentColor
    readonly property string effectiveMode: requestedMode === "dark" ? "dark" : "light"

    Component.onCompleted: apply()

    onEffectiveModeChanged: apply()
    onRequestedAccentColorChanged: apply()

    function apply() {
        MD.Token.color.useSysColorSM = false;
        MD.Token.color.useSysAccentColor = false;
        MD.Token.color.accentColor = requestedAccentColor;
        MD.Token.color.paletteType = MD.Enum.PaletteTonalSpot;
        MD.Token.color.mode = effectiveMode === "dark" ? MD.Enum.Dark : MD.Enum.Light;
    }
}
