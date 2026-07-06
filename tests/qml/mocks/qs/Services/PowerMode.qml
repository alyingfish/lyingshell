pragma Singleton

import QtQml

QtObject {
    readonly property bool available: true
    property int profile: 1
    readonly property bool hasPerformanceProfile: true

    readonly property string iconName: {
        if (profile === 2) {
            return "bolt";
        }
        if (profile === 0) {
            return "energy_savings_leaf";
        }
        return "speed";
    }

    function setProfile(newProfile) {
        profile = newProfile;
    }
}
