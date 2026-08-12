pragma Singleton

import QtQml
import Quickshell
import qs.Services

// One-shot session actions for the quick-settings system row. Commands are
// detached launches, not state: nothing here is polled or parsed. Niri IPC
// actions (screenshot, color pick, quit) live on the Niri service directly.
Singleton {
    id: root

    function lock() {
        // The shell is its own ext-session-lock client now (Services/Lock.qml
        // + Modules/Lock). `loginctl lock-session` is still not used: it only
        // works when an idle daemon subscribes to the lock signal, which this
        // session does not guarantee.
        Lock.lock();
    }

    function suspend() {
        Quickshell.execDetached(["systemctl", "suspend"]);
    }

    function reboot() {
        Quickshell.execDetached(["systemctl", "reboot"]);
    }

    function powerOff() {
        Quickshell.execDetached(["systemctl", "poweroff"]);
    }

    function openSettings() {
        // ponytail: gnome-control-center until the planned Lying Shell
        // settings window exists.
        Quickshell.execDetached(["gnome-control-center"]);
    }
}
