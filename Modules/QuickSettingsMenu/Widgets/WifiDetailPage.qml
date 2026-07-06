import QtQuick
import Quickshell.Networking
import Qcm.Material as MD
import qs.Commons.I18n
import qs.Commons.Theme
import qs.Services
import "../../../Commons/Icons/StatusIcons.js" as StatusIcons

// Wi-Fi network list: top 10 networks by connection/signal, with an inline
// password field for unknown secured networks.
Column {
    id: page

    // Which network shows the inline password field.
    property var pendingNetwork: null
    property real viewportHeight: 0

    spacing: 5

    DetailEmpty {
        visible: !Networking.wifiEnabled
        name: I18n.t("quickSettings.wifi")
        viewportHeight: page.viewportHeight
    }

    MD.LinearIndicator {
        width: parent.width
        visible: Networking.wifiEnabled && SystemStatus.wifiDevice !== null && SystemStatus.wifiDevice.networks.values.length === 0
    }

    Repeater {
        model: Networking.wifiEnabled && SystemStatus.wifiDevice ? SystemStatus.wifiDevice.networks.values.slice().sort((a, b) => (b.connected ? 2 : b.signalStrength > 1 ? b.signalStrength / 100 : b.signalStrength) - (a.connected ? 2 : a.signalStrength > 1 ? a.signalStrength / 100 : a.signalStrength)).slice(0, 10) : []

        Column {
            id: wifiRow

            required property var modelData
            required property int index

            width: parent.width
            spacing: 5

            DetailRow {
                order: wifiRow.index
                text: wifiRow.modelData.name
                current: wifiRow.modelData.connected
                leadingIcon: StatusIcons.wifiSignalIcon(wifiRow.modelData.signalStrength)
                nameBadgeIcon: wifiRow.modelData.security !== WifiSecurityType.Open ? "lock" : ""
                busy: wifiRow.modelData.stateChanging
                subText: {
                    if (wifiRow.modelData.stateChanging) {
                        return I18n.t("quickSettings.wifiConnecting");
                    }
                    if (wifiRow.modelData.connected) {
                        return I18n.t("quickSettings.wifiConnected");
                    }
                    if (wifiRow.modelData.security !== WifiSecurityType.Open) {
                        return I18n.t("quickSettings.wifiSecured");
                    }
                    return I18n.t("quickSettings.wifiOpen");
                }

                onClicked: {
                    if (wifiRow.modelData.connected) {
                        wifiRow.modelData.disconnect();
                    } else if (wifiRow.modelData.known || wifiRow.modelData.security === WifiSecurityType.Open) {
                        wifiRow.modelData.connect();
                    } else {
                        page.pendingNetwork = page.pendingNetwork === wifiRow.modelData ? null : wifiRow.modelData;
                    }
                }
            }

            Row {
                visible: page.pendingNetwork === wifiRow.modelData
                width: parent.width
                spacing: 8

                MD.TextField {
                    id: pskField

                    // Compact 56dp field for the panel (outlined default is 64dp).
                    mdState.dense: true
                    width: parent.width - connectButton.width - 8
                    echoMode: TextInput.Password
                    placeholderText: I18n.t("quickSettings.wifiPassword")

                    onAccepted: connectButton.clicked()
                }

                MD.Button {
                    id: connectButton

                    anchors.verticalCenter: parent.verticalCenter
                    mdState.type: MD.Enum.BtFilledTonal
                    text: I18n.t("quickSettings.connect")
                    font.family: Theme.textTypeface

                    onClicked: {
                        wifiRow.modelData.connectWithPsk(pskField.text);
                        page.pendingNetwork = null;
                    }
                }
            }
        }
    }
}
