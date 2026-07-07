import QtQuick
import Quickshell
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
    // Row delegates, for tests asserting reuse across a re-sort.
    readonly property alias rows: netRepeater

    spacing: 5

    // Order-stable network list driving the Repeater via a ScriptModel.
    // Recomputed imperatively (refresh()) off structural changes and a coarse
    // timer instead of a live sort binding, and fed through ScriptModel so the
    // Repeater reuses row delegates: unchanged networks keep their delegate,
    // re-sorts move them, and only a network leaving the list destroys its row.
    //
    // Reassigning a plain-array model (the previous approach) reset the
    // Repeater and rebuilt ALL 10 rows on every re-sort. A scan-driven re-sort
    // while scrolling then destroyed a row mid MState state-transition
    // (press/hover), and Qt's animation timer later dereferenced the freed
    // delegate (QQuickTransitionManager::complete -> setBinding) -> shell
    // SIGSEGV. Identity-diffing the list keeps the interacted row alive.
    ScriptModel {
        id: wifiModel
    }

    // Signal bar level (0..4), matching StatusIcons.wifiSignalIcon thresholds,
    // so ordering ignores sub-bar jitter.
    function _level(strength) {
        var n = strength > 1 ? strength / 100 : strength;
        return n > 0.8 ? 4 : n > 0.55 ? 3 : n > 0.3 ? 2 : n > 0.05 ? 1 : 0;
    }

    function refresh() {
        var dev = SystemStatus.wifiDevice;
        if (!Networking.wifiEnabled || !dev) {
            wifiModel.values = [];
            return;
        }
        // ScriptModel diffs by object identity and no-ops on an unchanged
        // list, so reassigning every refresh is cheap.
        wifiModel.values = dev.networks.values.slice().sort((a, b) => {
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
    // dropping/adding networks. ScriptModel no-ops on ticks that change
    // nothing, so this never churns delegates on its own.
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
        visible: Networking.wifiEnabled && SystemStatus.wifiDevice !== null && wifiModel.values.length === 0
    }

    Repeater {
        id: netRepeater

        model: wifiModel

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
