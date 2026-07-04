pragma Singleton

import QtQml
import Quickshell
import qs.Services.Niri

// One-shot session actions for the quick-settings system row. Commands are
// detached launches, not state: nothing here is polled or parsed.
Singleton {
    id: root

    function lock() {
        // Direct ext-session-lock client; `loginctl lock-session` only works
        // when an idle daemon subscribes to the lock signal, which this
        // session does not guarantee.
        Quickshell.execDetached(["swaylock", "-f"]);
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

    function logOut() {
        Niri.quitSession();
    }

    function takeScreenshot() {
        Niri.takeScreenshot();
    }

    function openSettings() {
        // ponytail: gnome-control-center until the planned Lying Shell
        // settings window exists.
        Quickshell.execDetached(["gnome-control-center"]);
    }
}
