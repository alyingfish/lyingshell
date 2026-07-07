import QtQuick
import Quickshell.Services.UPower
import Qcm.Material as MD
import qs.Commons.I18n
import qs.Commons.Theme
import qs.Material
import qs.Services

// Power-mode row (prototype #rowPmode): battery time estimate + an M3E
// connected button group of the available power profiles.
Rectangle {
    id: root

    // Estimate text: "5h 12m" with an hour, else minutes only ("30m", "1m")
    // floored to 1 so a live estimate never renders a dead "0h" or "0h 0m".
    function estimate(seconds, hoursToken, minutesToken) {
        if (seconds >= 3600) {
            return I18n.t(hoursToken, {
                "hours": Math.floor(seconds / 3600),
                "minutes": Math.floor(seconds % 3600 / 60)
            });
        }
        return I18n.t(minutesToken, {
            "minutes": Math.max(1, Math.floor(seconds / 60))
        });
    }

    // Battery first: while a battery exists the row describes it, never a
    // power-profile name. Profile name / "AC" is only the no-battery fallback.
    readonly property string label: {
        if (SystemStatus.hasBattery) {
            if (SystemStatus.batteryFull) {
                return I18n.t("quickSettings.batteryFull");
            }
            // Plugged in but held below full (charge limit / hysteresis wait).
            if (SystemStatus.batteryNotCharging) {
                return I18n.t("quickSettings.batteryNotCharging");
            }
            // Active charge/discharge: show the time estimate, or "Estimating…"
            // until UPower computes one.
            if (SystemStatus.batteryCharging) {
                return SystemStatus.battery.timeToFull > 0 ? estimate(SystemStatus.battery.timeToFull, "quickSettings.timeUntilFull", "quickSettings.minutesUntilFull") : I18n.t("quickSettings.estimating");
            }
            if (SystemStatus.battery.state === UPowerDeviceState.Discharging) {
                return SystemStatus.battery.timeToEmpty > 0 ? estimate(SystemStatus.battery.timeToEmpty, "quickSettings.timeLeft", "quickSettings.minutesLeft") : I18n.t("quickSettings.estimating");
            }
            // Empty / Unknown: no estimate applies, read the raw percentage.
            return I18n.t("quickSettings.batteryPercent", {
                "percent": SystemStatus.batteryPercent
            });
        }
        // No battery: read out AC, or the current profile when a daemon exists.
        if (!PowerMode.available) {
            return I18n.t("quickSettings.acPower");
        }
        if (PowerMode.profile === PowerProfile.Performance) {
            return I18n.t("quickSettings.powerProfile.performance");
        }
        if (PowerMode.profile === PowerProfile.PowerSaver) {
            return I18n.t("quickSettings.powerProfile.powerSaver");
        }
        return I18n.t("quickSettings.powerProfile.balanced");
    }

    // Test-only surface (tests/qml/tst_powermode_matrix.qml).
    readonly property bool groupVisibleProbe: pmodeGroup.visible
    readonly property int segmentCountProbe: pmodeGroup.count
    readonly property bool noticeVisibleProbe: noticeText.visible

    height: 40
    radius: 20
    color: MD.Token.color.surface_container

    MD.IconLabel {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: pmodeGroup.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Qt.AlignLeft
        spacing: 10
        icon.name: "schedule"
        icon.size: 18
        icon.color: MD.Token.color.on_surface_variant
        color: MD.Token.color.on_surface
        text: root.label
        label.typescale: MD.Token.typescale.label_large
        label.prominent: true
        label.useTypescale: true
        label.font.family: Theme.textTypeface
    }

    // Soft notice in the space the profile group vacates when no daemon
    // implements net.hadess.PowerProfiles.
    MD.Text {
        id: noticeText

        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        visible: !PowerMode.available
        text: I18n.t("quickSettings.powerProfile.unavailable")
        color: MD.Token.color.on_surface_variant
        typescale: MD.Token.typescale.label_medium
        font.family: Theme.textTypeface
    }

    ConnectedButtonGroup {
        id: pmodeGroup

        visible: PowerMode.available
        anchors.right: parent.right
        anchors.rightMargin: 3
        anchors.verticalCenter: parent.verticalCenter
        // Prototype .pmode: 42px icon-only segments, the selected one
        // springs to 52px.
        width: 142
        implicitHeight: 34
        gap: 3
        innerCorner: 6
        selectedWeight: 52 / 42
        labelStyle: MD.Enum.IconOnly
        textTypeface: Theme.textTypeface
        model: [
            {
                "icon": "energy_savings_leaf",
                "text": I18n.t("quickSettings.powerProfile.powerSaver"),
                "value": PowerProfile.PowerSaver,
                "available": true
            },
            {
                "icon": "speed",
                "text": I18n.t("quickSettings.powerProfile.balanced"),
                "value": PowerProfile.Balanced,
                "available": true
            },
            {
                "icon": "bolt",
                "text": I18n.t("quickSettings.powerProfile.performance"),
                "available": PowerMode.hasPerformanceProfile,
                "value": PowerProfile.Performance
            }
        ].filter(profile => profile.available)
        current: PowerMode.profile

        onSelected: value => PowerMode.setProfile(value)
    }
}
