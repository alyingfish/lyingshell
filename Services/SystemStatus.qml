pragma Singleton

import QtQml
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import "../Commons/Icons/StatusIcons.js" as StatusIcons

// Normalized network / bluetooth / battery state shared by the bar's
// quick-settings button and the quick-settings menu, so each surface does
// not re-derive devices from the raw Quickshell service models.
Singleton {
    id: root

    // --- network ----------------------------------------------------------
    readonly property var wifiDevice: Networking.devices.values.find(device => device !== null && device.type === DeviceType.Wifi) || null
    readonly property var wiredDevice: Networking.devices.values.find(device => device !== null && device.type === DeviceType.Wired) || null
    readonly property var activeWifiNetwork: wifiDevice ? wifiDevice.networks.values.find(network => network !== null && network.connected) || null : null
    readonly property bool wiredConnected: wiredDevice !== null && wiredDevice.connected
    readonly property string networkIconName: {
        if (wiredConnected) {
            return "lan";
        }
        if (!Networking.wifiEnabled) {
            return "signal_wifi_off";
        }
        if (activeWifiNetwork) {
            return StatusIcons.wifiSignalIcon(activeWifiNetwork.signalStrength);
        }
        return "signal_wifi_0_bar";
    }

    // --- bluetooth ---------------------------------------------------------
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btEnabled: btAdapter !== null && btAdapter.enabled
    readonly property var btConnectedDevices: Bluetooth.devices.values.filter(device => device !== null && device.connected)

    // --- battery -----------------------------------------------------------
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery !== null && battery.ready && battery.isLaptopBattery
    readonly property int batteryPercent: hasBattery ? Math.round(battery.percentage * 100) : 0
    readonly property bool batteryCharging: hasBattery && (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.PendingCharge || battery.state === UPowerDeviceState.FullyCharged)
    readonly property bool batteryFull: hasBattery && battery.state === UPowerDeviceState.FullyCharged
    // Low == the battery_alert icon threshold (StatusIcons.batteryCritical).
    readonly property bool batteryLow: hasBattery && StatusIcons.batteryCritical(batteryPercent, batteryCharging)
}
