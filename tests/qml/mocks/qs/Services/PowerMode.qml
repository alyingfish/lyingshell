pragma Singleton

import QtQml

QtObject {
    // Writable so tst_powermode_matrix.qml can drive the daemon-present and
    // profile-count permutations; defaults match the other offscreen tests.
    property bool available: true
    property int profile: 1
    property bool hasPerformanceProfile: true

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
