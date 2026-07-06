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

    // Row label: remaining battery estimate when one exists, otherwise the
    // current profile name.
    readonly property string label: {
        if (SystemStatus.hasBattery && !SystemStatus.batteryCharging && SystemStatus.battery.timeToEmpty > 0) {
            return I18n.t("quickSettings.timeLeft", {
                "hours": Math.floor(SystemStatus.battery.timeToEmpty / 3600),
                "minutes": Math.floor(SystemStatus.battery.timeToEmpty % 3600 / 60)
            });
        }
        if (SystemStatus.hasBattery && SystemStatus.batteryCharging && SystemStatus.battery.timeToFull > 0) {
            return I18n.t("quickSettings.timeUntilFull", {
                "hours": Math.floor(SystemStatus.battery.timeToFull / 3600),
                "minutes": Math.floor(SystemStatus.battery.timeToFull % 3600 / 60)
            });
        }
        if (PowerMode.profile === PowerProfile.Performance) {
            return I18n.t("quickSettings.powerProfile.performance");
        }
        if (PowerMode.profile === PowerProfile.PowerSaver) {
            return I18n.t("quickSettings.powerProfile.powerSaver");
        }
        return I18n.t("quickSettings.powerProfile.balanced");
    }

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

    ConnectedButtonGroup {
        id: pmodeGroup

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
