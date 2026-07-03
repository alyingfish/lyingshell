//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=5000
// QApplication mode: required by QsMenuAnchor (tray context menus).
//@ pragma UseQApplication

import Quickshell
import qs.App

ShellRoot {
    id: root

    Shell {}
}
