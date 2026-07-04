pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Power profiles via Quickshell's UPower module. PowerProfiles silently
// no-ops when no daemon implements net.hadess.PowerProfiles, so a one-shot
// bus probe (diagnostic, not polling) decides whether the toggle exists at
// all — GNOME hides the Power Mode toggle the same way.
Singleton {
    id: root

    property bool available: false
    readonly property var profile: PowerProfiles.profile
    readonly property bool hasPerformanceProfile: PowerProfiles.hasPerformanceProfile

    readonly property string iconName: {
        if (profile === PowerProfile.Performance) {
            return "speed";
        }
        if (profile === PowerProfile.PowerSaver) {
            return "energy_savings_leaf";
        }
        return "balance";
    }

    function setProfile(newProfile) {
        PowerProfiles.profile = newProfile;
    }

    Process {
        id: probe

        running: true
        command: ["busctl", "--no-pager", "status", "net.hadess.PowerProfiles"]

        onExited: function (exitCode) {
            root.available = exitCode === 0;
        }
    }
}
