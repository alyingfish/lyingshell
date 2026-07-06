import QtQuick
import qs.Commons.I18n
import qs.Services
import "../../../Commons/Icons/StatusIcons.js" as StatusIcons

// Bluetooth device list: paired/bonded/connected devices only.
Column {
    id: page

    property real viewportHeight: 0

    spacing: 5

    DetailEmpty {
        visible: !SystemStatus.btEnabled
        name: I18n.t("quickSettings.bluetooth")
        viewportHeight: page.viewportHeight
    }

    Repeater {
        model: SystemStatus.btEnabled && SystemStatus.btAdapter ? SystemStatus.btAdapter.devices.values.filter(device => device !== null && (device.paired || device.bonded || device.connected)) : []

        DetailRow {
            id: btRow

            required property var modelData
            required property int index

            order: index
            text: btRow.modelData.name.length > 0 ? btRow.modelData.name : btRow.modelData.address
            current: btRow.modelData.connected
            leadingIcon: StatusIcons.btDeviceIcon(btRow.modelData.icon)
            subText: btRow.modelData.connected ? I18n.t("quickSettings.btConnected") : I18n.t("quickSettings.btNotConnected")

            onClicked: {
                if (btRow.modelData.connected) {
                    btRow.modelData.disconnect();
                } else {
                    btRow.modelData.connect();
                }
            }
        }
    }
}
