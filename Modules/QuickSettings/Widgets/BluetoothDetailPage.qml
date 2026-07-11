import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Qcm.Material as MD
import qs.Commons.I18n
import qs.Commons.Theme
import qs.Services
import "../../../Commons/Icons/StatusIcons.js" as StatusIcons

// Bluetooth detail page (prototype bt.js): connected devices as hero cards
// over "Paired" / "Nearby devices" groups of expandable rows. Expanding a row
// shows the GNOME device dialog's content — Battery / Type / Address /
// Paired, a trusted switch ("Connect automatically" = BlueZ Trusted), and
// Remove / Disconnect / Connect / Pair actions; connecting and pairing run
// only from those explicit buttons. Discovery runs while the view is open
// and the adapter is discoverable, both bound by QuickSettingsPanel.
DetailPage {
    id: root

    detailName: "bluetooth"
    title: I18n.t("quickSettings.bluetooth")
    showSwitch: true
    switchChecked: SystemStatus.btEnabled
    onSwitchToggled: checked => {
        if (SystemStatus.btAdapter !== null) {
            SystemStatus.btAdapter.enabled = checked;
        }
    }

    bodyContent: Component {
        Column {
            id: page

            property real viewportHeight: 0
            // The one expanded row; collapsing clears the inline error.
            property var expandedDevice: null
            // Inline pair/connect failure surfaced by ConnectFeedback.
            property var errorDevice: null
            // Row delegates, for tests asserting reuse across a re-sort.
            readonly property alias rows: nearbyRepeater
            readonly property alias pairedRows: pairedRepeater
            readonly property alias heroRows: connectedRepeater

            readonly property int pairedOrder: 1 + connectedModel.values.length
            readonly property int nearbyOrder: pairedOrder + 1 + pairedModel.values.length

            spacing: 5

            function toggleRow(device) {
                if (expandedDevice === device) {
                    expandedDevice = null;
                } else {
                    expandedDevice = device;
                }
                if (errorDevice !== expandedDevice) {
                    errorDevice = null;
                }
            }

            function deviceName(device) {
                return device.name.length > 0 ? device.name : device.address;
            }

            ScriptModel {
                id: connectedModel
            }

            ScriptModel {
                id: pairedModel
            }

            ScriptModel {
                id: nearbyModel
            }

            function refresh() {
                var adapter = SystemStatus.btAdapter;
                if (!SystemStatus.btEnabled || !adapter) {
                    connectedModel.values = [];
                    pairedModel.values = [];
                    nearbyModel.values = [];
                    return;
                }
                var byName = (a, b) => {
                    var na = page.deviceName(a);
                    var nb = page.deviceName(b);
                    return na < nb ? -1 : na > nb ? 1 : 0;
                };
                var devices = adapter.devices.values.filter(d => d !== null);
                connectedModel.values = devices.filter(d => d.connected).sort(byName);
                pairedModel.values = devices.filter(d => !d.connected && (d.paired || d.bonded)).sort(byName);
                // Discovery surfaces plenty of nameless addresses; named
                // devices first, capped like the Wi-Fi list.
                nearbyModel.values = devices.filter(d => !d.connected && !d.paired && !d.bonded).sort((a, b) => {
                    var namedA = a.name.length > 0 ? 0 : 1;
                    var namedB = b.name.length > 0 ? 0 : 1;
                    if (namedA !== namedB) {
                        return namedA - namedB;
                    }
                    return byName(a, b);
                }).slice(0, 10);
            }

            // Regroup on structural changes (adapter on/off, device list
            // identity); per-device state flips regroup via the rows below.
            property int _watch: {
                SystemStatus.btEnabled;
                var adapter = SystemStatus.btAdapter;
                if (adapter) {
                    adapter.devices.values;
                }
                Qt.callLater(() => page.refresh());
                return 0;
            }

            Timer {
                interval: 4000
                running: true
                repeat: true
                onTriggered: page.refresh()
            }

            // Inline pair/connect failure: reopen the row with the message;
            // the service toasts when this page is gone.
            Connections {
                target: ConnectFeedback

                function onBtFailed(device: var) {
                    page.errorDevice = device;
                    page.expandedDevice = device;
                    page.refresh();
                }
            }

            DetailEmpty {
                visible: !SystemStatus.btEnabled
                name: I18n.t("quickSettings.bluetooth")
                viewportHeight: page.viewportHeight
            }

            // The adapter is discoverable while the view is open, like GNOME
            // Settings (prototype dv-note).
            MD.Text {
                width: parent.width
                visible: SystemStatus.btEnabled && SystemStatus.btAdapter !== null
                horizontalAlignment: Text.AlignHCenter
                text: I18n.t("quickSettings.btDiscoverableAs", {
                    "name": SystemStatus.btAdapter !== null ? SystemStatus.btAdapter.name : ""
                })
                color: MD.Token.color.on_surface_variant
                typescale: MD.Token.typescale.body_small
                font.family: Theme.textTypeface
                wrapMode: Text.Wrap
            }

            // --- connected devices: hero cards -------------------------------
            Repeater {
                id: connectedRepeater

                model: connectedModel

                BtRow {
                    required property int index

                    btPage: page
                    hero: true
                    order: 1 + index
                }
            }

            // --- Paired group -------------------------------------------------
            DetailSection {
                visible: pairedModel.values.length > 0
                order: page.pairedOrder
                text: I18n.t("quickSettings.btPaired")
            }

            Column {
                width: parent.width
                visible: pairedModel.values.length > 0
                spacing: 2

                Repeater {
                    id: pairedRepeater

                    model: pairedModel

                    BtRow {
                        required property int index

                        btPage: page
                        order: page.pairedOrder + 1 + index
                        groupPos: pairedModel.values.length === 1 ? "only" : index === 0 ? "first" : index === pairedModel.values.length - 1 ? "last" : "mid"
                    }
                }
            }

            // --- Nearby devices -----------------------------------------------
            DetailSection {
                visible: SystemStatus.btEnabled
                order: page.nearbyOrder
                text: I18n.t("quickSettings.btNearbyDevices")
                scanning: SystemStatus.btAdapter !== null && SystemStatus.btAdapter.discovering
            }

            Column {
                width: parent.width
                visible: SystemStatus.btEnabled
                spacing: 2

                Repeater {
                    id: nearbyRepeater

                    model: nearbyModel

                    BtRow {
                        required property int index

                        btPage: page
                        order: page.nearbyOrder + 1 + index
                        groupPos: nearbyModel.values.length === 1 ? "only" : index === 0 ? "first" : index === nearbyModel.values.length - 1 ? "last" : "mid"
                    }
                }
            }
        }
    }

    // ========================================================================
    // Device row: the ExpandoRow specialization with the per-state bodies.
    // ========================================================================
    component BtRow: ExpandoRow {
        id: btRow

        required property var modelData
        required property var btPage

        readonly property var device: modelData
        // BlueZ can drop a discovered device's object before the next
        // refresh() removes this delegate; guard the bindings through that
        // teardown tick.
        readonly property bool alive: device !== null && device !== undefined
        readonly property bool connecting: alive && device.state === BluetoothDeviceState.Connecting
        readonly property bool showsError: alive && btPage.errorDevice === device

        text: alive ? btPage.deviceName(device) : ""
        current: alive && device.connected
        open: alive && btPage.expandedDevice === device
        leadingIcon: alive ? StatusIcons.btDeviceIcon(device.icon) : ""
        busy: connecting || (alive && device.pairing)
        subText: {
            if (!alive) {
                return "";
            }
            if (device.pairing) {
                return I18n.t("quickSettings.btPairing");
            }
            if (connecting) {
                return I18n.t("quickSettings.wifiConnecting");
            }
            if (!device.connected) {
                return "";
            }
            if (device.batteryAvailable) {
                return I18n.t("quickSettings.btConnectedBattery", {
                    "percent": Math.round(device.battery * 100)
                });
            }
            return I18n.t("quickSettings.btConnected");
        }

        onHeaderClicked: if (alive && !connecting && !device.pairing) {
            btPage.toggleRow(device);
        }

        // Regroup when this row's connection state flips (connect moves it
        // up to a hero card; disconnect moves it back down).
        onCurrentChanged: {
            if (current && btPage.expandedDevice === device) {
                btPage.expandedDevice = null;
            }
            Qt.callLater(() => btRow.btPage.refresh());
        }

        onAliveChanged: if (!alive) {
            if (btPage.expandedDevice === device) {
                btPage.expandedDevice = null;
            }
            if (btPage.errorDevice === device) {
                btPage.errorDevice = null;
            }
        }

        Loader {
            width: parent.width
            // Stay loaded through the collapse reveal (prototype fades the
            // body out; unloading on the open flip would blank it mid-anim).
            active: btRow.revealing && btRow.alive
            visible: active
            sourceComponent: !btRow.alive ? null : btRow.device.connected ? connectedBody : (btRow.device.paired || btRow.device.bonded) ? pairedBody : nearbyBody

            // Shared property rows (GNOME device dialog).
            function baseProps(device) {
                var typeToken = "quickSettings.btTypes." + StatusIcons.btDeviceType(device.icon);
                return [[I18n.t("quickSettings.propType"), I18n.t(typeToken)], [I18n.t("quickSettings.btAddress"), device.address]];
            }

            // --- connected: props + trusted + remove / disconnect ----------
            Component {
                id: connectedBody

                Column {
                    spacing: 10

                    RowPropList {
                        onCurrent: true
                        entries: {
                            var list = [];
                            if (btRow.device.batteryAvailable) {
                                list.push([I18n.t("quickSettings.btBattery"), Math.round(btRow.device.battery * 100) + "%"]);
                            }
                            return list.concat(baseProps(btRow.device)).concat([[I18n.t("quickSettings.btPairedProp"), I18n.t("quickSettings.yes")]]);
                        }
                    }

                    RowAutoConnect {
                        onCurrent: true
                        checked: btRow.device.trusted

                        onToggled: checked => btRow.device.trusted = checked
                    }

                    RowActions {
                        leftData: [
                            ActionButton {
                                filled: false
                                danger: true
                                text: I18n.t("quickSettings.btRemove")

                                onClicked: {
                                    var name = btRow.btPage.deviceName(btRow.device);
                                    btRow.btPage.expandedDevice = null;
                                    btRow.device.forget();
                                    Toast.show(I18n.t("toast.btRemoved", {
                                        "name": name
                                    }));
                                    Qt.callLater(() => btRow.btPage.refresh());
                                }
                            }
                        ]
                        rightData: [
                            ActionButton {
                                text: I18n.t("quickSettings.disconnect")

                                onClicked: {
                                    var name = btRow.btPage.deviceName(btRow.device);
                                    btRow.btPage.expandedDevice = null;
                                    btRow.device.disconnect();
                                    Toast.show(I18n.t("toast.btDisconnected", {
                                        "name": name
                                    }));
                                }
                            }
                        ]
                    }
                }
            }

            // --- paired, not connected: props + trusted + remove / connect --
            Component {
                id: pairedBody

                Column {
                    spacing: 10

                    RowPropList {
                        entries: baseProps(btRow.device)
                    }

                    RowAutoConnect {
                        checked: btRow.device.trusted

                        onToggled: checked => btRow.device.trusted = checked
                    }

                    MD.Text {
                        width: parent.width
                        visible: btRow.showsError
                        text: I18n.t("quickSettings.btErrConnectFailed")
                        color: MD.Token.color.error
                        typescale: MD.Token.typescale.body_small
                        prominent: true
                        font.family: Theme.textTypeface
                        wrapMode: Text.Wrap
                    }

                    RowActions {
                        leftData: [
                            ActionButton {
                                visible: !btRow.connecting
                                filled: false
                                danger: true
                                text: I18n.t("quickSettings.btRemove")

                                onClicked: {
                                    var name = btRow.btPage.deviceName(btRow.device);
                                    btRow.btPage.expandedDevice = null;
                                    btRow.device.forget();
                                    Toast.show(I18n.t("toast.btRemoved", {
                                        "name": name
                                    }));
                                    Qt.callLater(() => btRow.btPage.refresh());
                                }
                            },
                            ActionButton {
                                visible: btRow.connecting
                                filled: false
                                text: I18n.t("quickSettings.cancel")

                                onClicked: btRow.device.disconnect()
                            }
                        ]
                        rightData: [
                            ActionButton {
                                enabled: !btRow.connecting
                                text: btRow.connecting ? I18n.t("quickSettings.wifiConnecting") : I18n.t("quickSettings.connect")

                                onClicked: {
                                    btRow.btPage.errorDevice = null;
                                    ConnectFeedback.watchBt(btRow.device);
                                    btRow.device.connect();
                                }
                            }
                        ]
                    }
                }
            }

            // --- not set up: props + pair (BlueZ agent) ---------------------
            Component {
                id: nearbyBody

                Column {
                    spacing: 10

                    RowPropList {
                        entries: baseProps(btRow.device)
                    }

                    MD.Text {
                        width: parent.width
                        visible: btRow.showsError
                        text: I18n.t("quickSettings.btErrPairFailed")
                        color: MD.Token.color.error
                        typescale: MD.Token.typescale.body_small
                        prominent: true
                        font.family: Theme.textTypeface
                        wrapMode: Text.Wrap
                    }

                    RowActions {
                        leftData: [
                            ActionButton {
                                filled: false
                                text: I18n.t("quickSettings.cancel")

                                onClicked: {
                                    if (btRow.device.pairing) {
                                        btRow.device.cancelPair();
                                    } else {
                                        btRow.btPage.toggleRow(btRow.device);
                                    }
                                }
                            }
                        ]
                        rightData: [
                            ActionButton {
                                enabled: !btRow.device.pairing
                                text: btRow.device.pairing ? I18n.t("quickSettings.btPairing") : I18n.t("quickSettings.btPair")

                                onClicked: {
                                    btRow.btPage.errorDevice = null;
                                    ConnectFeedback.watchBt(btRow.device);
                                    btRow.device.pair();
                                }
                            }
                        ]
                    }
                }
            }
        }
    }


}
