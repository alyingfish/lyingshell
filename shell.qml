//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=5000
// QApplication mode: required by QsMenuAnchor (tray context menus).
//@ pragma UseQApplication
// Without a Qt platform-theme plugin, QIcon falls back to hicolor, so themed
// tray icons that live only in the desktop theme (e.g. fcitx's
// input-keyboard-symbolic in Adwaita) fail to load. Pin the process icon theme.
//@ pragma IconTheme Adwaita

import Quickshell
import qs.App

ShellRoot {
    id: root

    Shell {}
}
