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

    // Cached, order-stable network list driving the Repeater. Recomputed
    // imperatively (refresh()) off structural changes and a coarse timer
    // instead of a live sort binding: a live binding re-ran on every scan tick
    // and every signal-strength jitter, producing a fresh array that tore down
    // and re-animated all 10 delegates each time (open lag + periodic
    // full-list refresh). Now the same delegates persist and update their
    // icons in place; the list is only reassigned when the visible order or
    // membership actually changes.
    property var networkList: []
    property string _signature: ""

    spacing: 5

    // Signal bar level (0..4), matching StatusIcons.wifiSignalIcon thresholds,
    // so ordering and the change-signature ignore sub-bar jitter.
    function _level(strength) {
        var n = strength > 1 ? strength / 100 : strength;
        return n > 0.8 ? 4 : n > 0.55 ? 3 : n > 0.3 ? 2 : n > 0.05 ? 1 : 0;
    }

    function refresh() {
        var dev = SystemStatus.wifiDevice;
        if (!Networking.wifiEnabled || !dev) {
            if (page.networkList.length !== 0) {
                page.networkList = [];
                page._signature = "";
            }
            return;
        }
        var nets = dev.networks.values.slice().sort((a, b) => {
            if (a.connected !== b.connected) {
                return a.connected ? -1 : 1;
            }
            var la = page._level(a.signalStrength);
            var lb = page._level(b.signalStrength);
            if (la !== lb) {
                return lb - la;
            }
            return a.name < b.name ? -1 : a.name > b.name ? 1 : 0;
        }).slice(0, 10);
        var sig = nets.map(n => n.name + "|" + n.connected + "|" + page._level(n.signalStrength)).join("~");
        if (sig === page._signature) {
            return; // order + membership unchanged: keep the existing delegates
        }
        page._signature = sig;
        page.networkList = nets;
    }

    // Re-sort on structural changes only: wifi on/off, the device appearing,
    // or an AP being added/removed (networks.values identity). Reading
    // .values here does NOT subscribe to per-AP signal-strength changes, so
    // scan jitter never re-triggers this; deferred so it runs once after the
    // service singletons settle at startup.
    property int _watch: {
        Networking.wifiEnabled;
        var dev = SystemStatus.wifiDevice;
        if (dev) {
            dev.networks.values;
        }
        Qt.callLater(() => page.refresh());
        return 0;
    }

    // Coarse re-sort cadence: catches APs crossing a signal bar or the scanner
    // dropping/adding networks. The signature gate above keeps ticks that
    // change nothing from churning delegates.
    // ponytail: 4s poll; drop it if networks.values gains a per-AP change signal.
    Timer {
        interval: 4000
        running: true
        repeat: true
        onTriggered: page.refresh()
    }

    DetailEmpty {
        visible: !Networking.wifiEnabled
        name: I18n.t("quickSettings.wifi")
        viewportHeight: page.viewportHeight
    }

    MD.LinearIndicator {
        width: parent.width
        visible: Networking.wifiEnabled && SystemStatus.wifiDevice !== null && page.networkList.length === 0
    }

    Repeater {
        model: page.networkList

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
