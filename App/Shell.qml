import Quickshell
import qs.Commons.I18n
import qs.Commons.Settings
import qs.Commons.Theme
import qs.Modules.Wallpaper
import qs.Modules.Bar

Scope {
    id: root

    readonly property bool ready: Settings.isLoaded && I18n.isLoaded
    readonly property string activeThemeMode: Theme.effectiveMode

    // Wallpaper surfaces handle their own per-output Variants/Loaders.
    Background {}

    Overview {}

    Variants {
        model: root.ready ? Quickshell.screens : []

        Bar {
            required property var modelData

            screen: modelData
        }
    }
}
