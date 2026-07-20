import QtQuick
import Quickshell
import Quickshell.Networking
import Qcm.Material as MD
import qs.Commons.I18n
import qs.Commons.Theme
import qs.Services
import qs.Modules.QuickSettings.Controls
import qs.Modules.QuickSettings.Detail
import "../../../../Commons/Icons/StatusIcons.js" as StatusIcons

// Wi-Fi detail page (prototype wifi.js): the connected network is a hero
// card above "Saved" / "Other networks" groups of expandable rows. A row
// click expands it in place — connecting happens only through the explicit
// button in the body (connected: props + auto-connect + forget/disconnect;
// saved: auto-connect + connect/forget; unknown secured: password form;
// open: notice), plus a trailing "Hidden network…" join row. While the
// hotspot is active the list is replaced by the share card (the radio can't
// scan in AP mode). The body is async-incubated by DetailPage.
DetailPage {
    id: root

    detailName: "wifi"
    title: I18n.t("quickSettings.wifi")
    showSwitch: true
    switchChecked: Networking.wifiEnabled
    onSwitchToggled: checked => Networking.wifiEnabled = checked

    // Force a fresh NetworkManager scan through WifiScan (Quickshell.Networking
    // exposes no rescan trigger, only the continuous `scannerEnabled`); the
    // scanner binding then folds the results in. Re-sort the current list at
    // once for immediate feedback while the scan runs.
    showRefresh: true
    onRefreshRequested: {
        if (Networking.wifiEnabled && SystemStatus.wifiDevice !== null && !SystemStatus.hotspotActive) {
            WifiScan.rescan();
        }
        if (bodyItem !== null) {
            bodyItem.refresh();
        }
    }



    bodyContent: Component {
        Column {
            id: page

            property real viewportHeight: 0
            // The one expanded row (a network object, or the hidden-join
            // sentinel); collapsing clears the inline error.
            property var expandedNetwork: null
            // Inline failure surfaced by ConnectFeedback (survives regroups).
            property var errorNetwork: null
            property string errorText: ""
            // The failure was NM need-secrets: reopen with the password form
            // even on a network that looked open (stale/unknown security).
            property bool errorSecrets: false
            // Row delegates, for tests asserting reuse across regroups.
            readonly property alias rows: listRepeater
            // Sizes of the hero / Saved / Other slices of listModel, written
            // by refresh() alongside the values so group bindings see them
            // atomically.
            property int heroCount: 0
            property int savedCount: 0
            property int otherCount: 0

            readonly property string hiddenSentinel: "__hidden__"
            // Which connected network LinkDetails was last fetched for.
            property string _linkFor: ""
            readonly property int otherOrder: 2 + savedCount

            // 2px row rhythm inside a group; group-leading wrappers open the
            // 5px group gap themselves (topPadding 3 above their header).
            spacing: 2

            function toggleRow(network) {
                if (expandedNetwork === network) {
                    expandedNetwork = null;
                } else {
                    expandedNetwork = network;
                }
                if (errorNetwork !== expandedNetwork) {
                    clearError();
                }
            }

            function clearError() {
                errorNetwork = null;
                errorText = "";
                errorSecrets = false;
            }

            function beginConnect(network) {
                clearError();
                ConnectFeedback.watchWifi(network);
            }

            function securityName(security) {
                switch (security) {
                case WifiSecurityType.Sae:
                case WifiSecurityType.Wpa3SuiteB192:
                    return "WPA3";
                case WifiSecurityType.Wpa2Psk:
                    return "WPA2";
                case WifiSecurityType.WpaPsk:
                    return "WPA";
                case WifiSecurityType.Wpa2Eap:
                case WifiSecurityType.WpaEap:
                    return "802.1X";
                case WifiSecurityType.StaticWep:
                case WifiSecurityType.DynamicWep:
                    return "WEP";
                case WifiSecurityType.Owe:
                    return "OWE";
                default:
                    return I18n.t("quickSettings.wifiOpen");
                }
            }

            // Lock badge / password-form gate. Live NetworkManager reports
            // plain open networks as Unknown (verified against a captive-
            // portal AP), and OWE is encrypted-open — neither warrants a
            // lock or a password form up front; a NoSecrets failure reopens
            // the form regardless (below).
            function isSecured(security) {
                return security !== WifiSecurityType.Open && security !== WifiSecurityType.Owe && security !== WifiSecurityType.Unknown;
            }

            function isPskSecurity(security) {
                return security === WifiSecurityType.WpaPsk || security === WifiSecurityType.Wpa2Psk || security === WifiSecurityType.Sae;
            }

            function isEapSecurity(security) {
                return security === WifiSecurityType.WpaEap || security === WifiSecurityType.Wpa2Eap;
            }

            // NM connection.autoconnect via the network's settings profile;
            // absent means the NM default (true).
            function autoconnectOf(net) {
                var profiles = net.nmSettings;
                if (!profiles || profiles.length === 0) {
                    return true;
                }
                var settings = profiles[0].read();
                if (!settings || !settings.connection) {
                    return true;
                }
                return settings.connection.autoconnect !== false;
            }

            function setAutoconnect(net, value) {
                var profiles = net.nmSettings;
                if (!profiles || profiles.length === 0) {
                    return;
                }
                profiles[0].write({
                    "connection": {
                        "autoconnect": value
                    }
                });
            }

            function forgetNetwork(net) {
                var name = net.name;
                expandedNetwork = null;
                net.forget();
                Toast.show(I18n.t("toast.wifiForgot", {
                    "name": name
                }));
                Qt.callLater(() => page.refresh());
            }

            function disconnectNetwork(net) {
                expandedNetwork = null;
                net.disconnect();
                Toast.show(I18n.t("toast.wifiDisconnected", {
                    "name": net.name
                }));
            }

            // ONE order-stable list drives ONE Repeater via a ScriptModel
            // (identity-diffed so unchanged networks keep their delegates;
            // destroying a row mid state-transition SIGSEGVs in Qt's
            // animation timer — see the DetailRow-era note in git history).
            // Hero / Saved / Other are contiguous slices of this single
            // model, so a connect or disconnect that regroups a row is a
            // delegate MOVE. Separate per-group Repeaters made that a
            // cross-model destroy+create of a row whose state-flip
            // animations were still running — the hotspot-vanish crash.
            ScriptModel {
                id: listModel
            }

            // Signal bar level (0..4), matching StatusIcons.wifiSignalIcon
            // thresholds, so ordering ignores sub-bar jitter.
            function _level(strength) {
                var n = strength > 1 ? strength / 100 : strength;
                return n > 0.8 ? 4 : n > 0.55 ? 3 : n > 0.3 ? 2 : n > 0.05 ? 1 : 0;
            }

            function refresh() {
                var dev = SystemStatus.wifiDevice;
                if (!Networking.wifiEnabled || !dev || SystemStatus.hotspotActive) {
                    heroCount = 0;
                    savedCount = 0;
                    otherCount = 0;
                    listModel.values = [];
                    return;
                }
                var byStrength = (a, b) => {
                    var la = page._level(a.signalStrength);
                    var lb = page._level(b.signalStrength);
                    if (la !== lb) {
                        return lb - la;
                    }
                    return a.name < b.name ? -1 : a.name > b.name ? 1 : 0;
                };
                var nets = dev.networks.values.filter(n => n !== null && n.name.length > 0);
                var hero = nets.filter(n => n.connected).slice(0, 1);
                var heroName = hero.length > 0 ? hero[0].name : "";
                if (heroName !== _linkFor) {
                    _linkFor = heroName;
                    if (heroName.length > 0) {
                        LinkDetails.refresh(dev.name);
                    }
                }
                var rest = nets.filter(n => !n.connected);
                var saved = rest.filter(n => n.known).sort(byStrength);
                var other = rest.filter(n => !n.known).sort(byStrength).slice(0, 10);
                heroCount = hero.length;
                savedCount = saved.length;
                otherCount = other.length;
                listModel.values = hero.concat(saved, other);
            }

            // Re-sort on structural changes only (wifi on/off, device, AP list
            // identity, hotspot flip); scan jitter never re-triggers this.
            property int _watch: {
                Networking.wifiEnabled;
                SystemStatus.hotspotActive;
                var dev = SystemStatus.wifiDevice;
                if (dev) {
                    dev.networks.values;
                }
                Qt.callLater(() => page.refresh());
                return 0;
            }

            // Coarse re-sort cadence: catches APs crossing a signal bar.
            // ScriptModel no-ops on ticks that change nothing.
            Timer {
                interval: 4000
                running: true
                repeat: true
                onTriggered: page.refresh()
            }

            // Inline failure: reopen the row with the message (the prototype
            // reopens even hidden-join failures); the service toasts when
            // this page is gone.
            Connections {
                target: ConnectFeedback

                function onWifiFailed(network: var, reason: int) {
                    page.errorNetwork = network;
                    page.errorSecrets = reason === ConnectionFailReason.NoSecrets;
                    page.errorText = page.errorSecrets ? I18n.t("quickSettings.wifiErrWrongPassword") : I18n.t("quickSettings.wifiErrFailed");
                    page.expandedNetwork = network;
                    page.refresh();
                }
            }

            // Hidden-join completion regroups the list; the toasts live in
            // ConnectFeedback so they fire even after the panel closes.
            Connections {
                target: HiddenNetwork

                function onSucceeded(ssid: string) {
                    page.refresh();
                }

                function onFailed(ssid: string) {
                    page.refresh();
                }
            }

            DetailEmpty {
                visible: !Networking.wifiEnabled
                name: I18n.t("quickSettings.wifi")
                viewportHeight: page.viewportHeight
            }

            // --- hotspot card (prototype renderHotspot) ---------------------
            Column {
                width: parent.width
                visible: Networking.wifiEnabled && SystemStatus.hotspotActive
                spacing: 5

                MD.Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: I18n.t("quickSettings.hotspotScanNote")
                    color: MD.Token.color.on_surface_variant
                    typescale: MD.Token.typescale.body_small
                    font.family: Theme.textTypeface
                    wrapMode: Text.Wrap
                }

                ExpandoRow {
                    hero: true
                    current: true
                    open: true
                    expandable: false
                    leadingIcon: "wifi_tethering"
                    text: Hotspot.ssid.length > 0 ? Hotspot.ssid : I18n.t("quickSettings.hotspot")
                    subText: [I18n.t("quickSettings.active"), Hotspot.security, Hotspot.band].filter(part => part.length > 0).join(" · ")

                    RowPropList {
                        onCurrent: true
                        entries: {
                            var list = [];
                            if (Hotspot.password.length > 0) {
                                list.push([I18n.t("quickSettings.wifiPassword"), Hotspot.password]);
                            }
                            if (Hotspot.security.length > 0) {
                                list.push([I18n.t("quickSettings.propSecurity"), Hotspot.security]);
                            }
                            if (Hotspot.band.length > 0) {
                                list.push([I18n.t("quickSettings.propBand"), Hotspot.band]);
                            }
                            return list;
                        }
                    }

                    RowActions {
                        rightData: [
                            ActionButton {
                                text: I18n.t("quickSettings.hotspotOffAction")

                                onClicked: Hotspot.stop()
                            }
                        ]
                    }
                }
            }

            // --- hero + Saved + Other: one Repeater over listModel -----------
            Repeater {
                id: listRepeater

                model: listModel

                // Wrapper so the first row of a group carries the group's
                // section header: headers can't sit between the rows of a
                // single Repeater any other way, and a single Repeater is
                // what turns a regroup into a delegate move.
                Column {
                    id: rowWrap

                    required property var modelData
                    required property int index

                    readonly property bool isHero: index < page.heroCount
                    readonly property bool isSaved: !isHero && index < page.heroCount + page.savedCount
                    readonly property int groupIndex: isHero ? index : isSaved ? index - page.heroCount : index - page.heroCount - page.savedCount
                    readonly property bool leadsGroup: !isHero && groupIndex === 0

                    width: parent.width
                    // Opens the 5px group gap over the page's 2px row rhythm.
                    topPadding: leadsGroup ? 3 : 0
                    spacing: 5

                    // Loader-gated so only the two group-leading rows pay for
                    // a section (its BusyIndicator is heavy; one per row
                    // stalls the push slide's first frames).
                    Loader {
                        width: parent.width
                        active: rowWrap.leadsGroup
                        visible: active

                        sourceComponent: DetailSection {
                            order: rowWrap.isSaved ? 1 : page.otherOrder
                            text: rowWrap.isSaved ? I18n.t("quickSettings.wifiSaved") : page.heroCount > 0 || page.savedCount > 0 ? I18n.t("quickSettings.wifiOtherNetworks") : I18n.t("quickSettings.wifiNetworks")
                            // Spin while the continuous scanner is live (only
                            // while this page is open, per the panel's
                            // scannerEnabled binding), not forever.
                            scanning: !rowWrap.isSaved && SystemStatus.wifiDevice !== null && SystemStatus.wifiDevice.scannerEnabled
                        }
                    }

                    WifiRow {
                        modelData: rowWrap.modelData
                        wifiPage: page
                        hero: rowWrap.isHero
                        order: rowWrap.isHero ? 0 : rowWrap.isSaved ? 2 + rowWrap.groupIndex : page.otherOrder + 1 + rowWrap.groupIndex
                        groupPos: rowWrap.isHero ? "single" : rowWrap.isSaved ? (page.savedCount === 1 ? "only" : rowWrap.groupIndex === 0 ? "first" : rowWrap.groupIndex === page.savedCount - 1 ? "last" : "mid") : rowWrap.groupIndex === 0 ? "first" : "mid"
                    }
                }
            }

            // With no unknown APs no repeater row leads the Other group, so
            // this standalone header keeps the section (and its scanning
            // cue) above the hidden-join row. Loader-gated like the per-row
            // headers.
            Loader {
                width: parent.width
                active: Networking.wifiEnabled && !SystemStatus.hotspotActive && page.otherCount === 0
                visible: active

                sourceComponent: Column {
                    topPadding: 3
                    bottomPadding: 3

                    DetailSection {
                        order: page.otherOrder
                        text: page.heroCount > 0 || page.savedCount > 0 ? I18n.t("quickSettings.wifiOtherNetworks") : I18n.t("quickSettings.wifiNetworks")
                        scanning: SystemStatus.wifiDevice !== null && SystemStatus.wifiDevice.scannerEnabled
                    }
                }
            }

            // Trailing "Hidden network…" join row (prototype HID).
            ExpandoRow {
                id: hiddenRow

                visible: Networking.wifiEnabled && !SystemStatus.hotspotActive
                groupPos: page.otherCount === 0 ? "only" : "last"
                order: page.otherOrder + 1 + page.otherCount
                leadingIcon: "add"
                text: I18n.t("quickSettings.wifiHidden")
                busy: HiddenNetwork.busy
                subText: HiddenNetwork.busy ? I18n.t("quickSettings.wifiConnecting") : ""
                open: page.expandedNetwork === page.hiddenSentinel

                onHeaderClicked: if (!HiddenNetwork.busy) {
                    page.toggleRow(page.hiddenSentinel);
                }

                Loader {
                    width: parent.width
                    active: hiddenRow.revealing
                    visible: active

                    sourceComponent: Column {
                        id: hiddenForm

                        property bool ssidError: false

                        spacing: 10

                        PasswordField {
                            id: hiddenSsid

                            placeholderText: I18n.t("quickSettings.wifiSsid")
                            error: hiddenForm.ssidError

                            onEdited: hiddenForm.ssidError = false
                            onAccepted: hiddenConnect.clicked()

                            Component.onCompleted: forceFocus()
                        }

                        PasswordField {
                            id: hiddenPsk

                            secret: true
                            placeholderText: I18n.t("quickSettings.wifiPassword")

                            onAccepted: hiddenConnect.clicked()
                        }

                        MD.Text {
                            width: parent.width
                            text: hiddenForm.ssidError ? I18n.t("quickSettings.wifiErrSsidRequired") : I18n.t("quickSettings.wifiHiddenHint")
                            color: hiddenForm.ssidError ? MD.Token.color.error : MD.Token.color.on_surface_variant
                            typescale: MD.Token.typescale.body_small
                            prominent: hiddenForm.ssidError
                            font.family: Theme.textTypeface
                            wrapMode: Text.Wrap
                        }

                        RowActions {
                            leftData: [
                                ActionButton {
                                    filled: false
                                    text: I18n.t("quickSettings.cancel")

                                    onClicked: page.toggleRow(page.hiddenSentinel)
                                }
                            ]
                            rightData: [
                                ActionButton {
                                    id: hiddenConnect

                                    text: I18n.t("quickSettings.connect")
                                    enabled: !HiddenNetwork.busy

                                    onClicked: {
                                        var ssid = hiddenSsid.text.trim();
                                        if (ssid.length === 0) {
                                            hiddenForm.ssidError = true;
                                            hiddenSsid.shake();
                                            hiddenSsid.forceFocus();
                                            return;
                                        }
                                        HiddenNetwork.join(ssid, hiddenPsk.text);
                                        page.toggleRow(page.hiddenSentinel);
                                    }
                                }
                            ]
                        }
                    }
                }
            }
        }
    }

    // ========================================================================
    // Network row: the ExpandoRow specialization with the per-state bodies.
    // ========================================================================
    component WifiRow: ExpandoRow {
        id: wifiRow

        required property var modelData
        required property var wifiPage

        readonly property var net: modelData
        // NM destroys a vanished AP's WifiNetwork object before the next
        // refresh() drops this delegate; every binding below guards on this
        // so the teardown tick doesn't spray TypeErrors.
        readonly property bool alive: net !== null && net !== undefined
        readonly property bool secured: alive && wifiPage.isSecured(net.security)
        readonly property bool showsError: alive && wifiPage.errorNetwork === net && wifiPage.errorText.length > 0

        text: alive ? net.name : ""
        current: alive && net.connected
        open: alive && wifiPage.expandedNetwork === net
        leadingIcon: alive ? StatusIcons.wifiSignalIcon(net.signalStrength) : ""
        nameBadgeIcon: secured ? "lock" : ""
        busy: alive && net.stateChanging
        subText: {
            if (!alive) {
                return "";
            }
            if (net.stateChanging) {
                return I18n.t("quickSettings.wifiConnecting");
            }
            if (!net.connected) {
                return "";
            }
            if (Networking.connectivity === NetworkConnectivity.Portal) {
                return I18n.t("quickSettings.wifiSignInRequired");
            }
            if (SystemStatus.wifiNoInternet) {
                return I18n.t("quickSettings.wifiNoInternetSub");
            }
            return I18n.t("quickSettings.wifiConnected") + (LinkDetails.band.length > 0 ? " · " + LinkDetails.band : "");
        }

        onHeaderClicked: if (alive && !net.stateChanging) {
            wifiPage.toggleRow(net);
        }

        // Regroup when this row's connection state flips (success moves it
        // to the hero slot; disconnect moves it back down).
        onCurrentChanged: {
            if (current && wifiPage.expandedNetwork === net) {
                wifiPage.expandedNetwork = null;
            }
            Qt.callLater(() => wifiRow.wifiPage.refresh());
        }

        // A dead expanded/error network would strand the page state.
        onAliveChanged: if (!alive) {
            if (wifiPage.expandedNetwork === net) {
                wifiPage.expandedNetwork = null;
            }
            if (wifiPage.errorNetwork === net) {
                wifiPage.clearError();
            }
        }

        Loader {
            width: parent.width
            // Stay loaded through the collapse reveal (prototype fades the
            // body out; unloading on the open flip would blank it mid-anim).
            active: wifiRow.revealing && wifiRow.alive
            visible: active
            // NoSecrets on an open-looking network still reopens the
            // password form (NM need-secrets, prototype stale-secrets path).
            sourceComponent: !wifiRow.alive ? null : wifiRow.net.connected ? connectedBody : wifiRow.net.known ? savedBody : wifiRow.wifiPage.isEapSecurity(wifiRow.net.security) ? eapBody : (wifiRow.secured || (wifiRow.showsError && wifiRow.wifiPage.errorSecrets)) ? pskBody : openBody

            // --- connected: props + auto-connect + forget / disconnect;
            // a captive portal adds the note and the Sign in action.
            Component {
                id: connectedBody

                Column {
                    spacing: 10

                    // Band / IP / link speed come from the LinkDetails
                    // service (not in Quickshell.Networking), fetched fresh
                    // on every expand.
                    Component.onCompleted: LinkDetails.refresh(wifiRow.net.device !== null ? wifiRow.net.device.name : "")

                    RowPropList {
                        onCurrent: true
                        entries: {
                            var strength = wifiRow.net.signalStrength;
                            var pct = Math.round(strength > 1 ? strength : strength * 100);
                            var level = wifiRow.wifiPage._level(strength);
                            var grade = I18n.t(level >= 4 ? "quickSettings.signalExcellent" : level >= 3 ? "quickSettings.signalGood" : level >= 2 ? "quickSettings.signalFair" : "quickSettings.signalWeak");
                            var internet = Networking.connectivity === NetworkConnectivity.Portal ? I18n.t("quickSettings.wifiSignInRequired") : Networking.connectivity === NetworkConnectivity.Limited || Networking.connectivity === NetworkConnectivity.None ? I18n.t("quickSettings.noInternet") : I18n.t("quickSettings.wifiConnected");
                            var list = [[I18n.t("quickSettings.propSignal"), grade + " · " + pct + "%"], [I18n.t("quickSettings.propSecurity"), wifiRow.secured ? wifiRow.wifiPage.securityName(wifiRow.net.security) : I18n.t("quickSettings.securityNone")]];
                            if (LinkDetails.band.length > 0) {
                                list.push([I18n.t("quickSettings.propBand"), LinkDetails.band]);
                            }
                            list.push([I18n.t("quickSettings.propInternet"), internet]);
                            if (LinkDetails.ipAddress.length > 0) {
                                list.push([I18n.t("quickSettings.propIpAddress"), LinkDetails.ipAddress]);
                            }
                            if (LinkDetails.linkRate.length > 0) {
                                list.push([I18n.t("quickSettings.propLinkSpeed"), LinkDetails.linkRate]);
                            }
                            return list;
                        }
                    }

                    MD.Text {
                        width: parent.width
                        visible: Networking.connectivity === NetworkConnectivity.Portal
                        text: I18n.t("quickSettings.wifiPortalNote")
                        color: MD.Util.transparent(MD.Token.color.on_secondary_container, 0.88)
                        typescale: MD.Token.typescale.body_small
                        font.family: Theme.textTypeface
                        wrapMode: Text.Wrap
                    }

                    RowAutoConnect {
                        onCurrent: true
                        checked: wifiRow.wifiPage.autoconnectOf(wifiRow.net)

                        onToggled: checked => wifiRow.wifiPage.setAutoconnect(wifiRow.net, checked)
                    }

                    RowActions {
                        leftData: [
                            ActionButton {
                                filled: false
                                danger: true
                                text: I18n.t("quickSettings.forget")

                                onClicked: wifiRow.wifiPage.forgetNetwork(wifiRow.net)
                            }
                        ]
                        rightData: [
                            ActionButton {
                                visible: Networking.connectivity === NetworkConnectivity.Portal
                                filled: false
                                text: I18n.t("quickSettings.disconnect")

                                onClicked: wifiRow.wifiPage.disconnectNetwork(wifiRow.net)
                            },
                            ActionButton {
                                visible: Networking.connectivity === NetworkConnectivity.Portal
                                text: I18n.t("quickSettings.signIn")

                                // GNOME spawns its portal helper; open the
                                // sign-in probe in the browser instead.
                                onClicked: {
                                    Quickshell.execDetached(["xdg-open", "http://networkcheck.kde.org"]);
                                    Toast.show(I18n.t("toast.wifiOpeningSignIn"));
                                }
                            },
                            ActionButton {
                                visible: Networking.connectivity !== NetworkConnectivity.Portal
                                text: I18n.t("quickSettings.disconnect")

                                onClicked: wifiRow.wifiPage.disconnectNetwork(wifiRow.net)
                            }
                        ]
                    }
                }
            }

            // --- saved, not connected: note + auto-connect + forget/connect
            Component {
                id: savedBody

                Column {
                    spacing: 10

                    MD.Text {
                        width: parent.width
                        text: wifiRow.secured ? wifiRow.wifiPage.securityName(wifiRow.net.security) : I18n.t("quickSettings.wifiOpen")
                        color: MD.Token.color.on_surface_variant
                        typescale: MD.Token.typescale.body_small
                        font.family: Theme.textTypeface
                        wrapMode: Text.Wrap
                    }

                    RowAutoConnect {
                        checked: wifiRow.wifiPage.autoconnectOf(wifiRow.net)

                        onToggled: checked => wifiRow.wifiPage.setAutoconnect(wifiRow.net, checked)
                    }

                    RowActions {
                        leftData: [
                            ActionButton {
                                visible: !wifiRow.net.stateChanging
                                filled: false
                                danger: true
                                text: I18n.t("quickSettings.forget")

                                onClicked: wifiRow.wifiPage.forgetNetwork(wifiRow.net)
                            },
                            ActionButton {
                                visible: wifiRow.net.stateChanging
                                filled: false
                                text: I18n.t("quickSettings.cancel")

                                onClicked: wifiRow.net.disconnect()
                            }
                        ]
                        rightData: [
                            ActionButton {
                                enabled: !wifiRow.net.stateChanging
                                text: wifiRow.net.stateChanging ? I18n.t("quickSettings.wifiConnecting") : I18n.t("quickSettings.connect")

                                onClicked: {
                                    wifiRow.wifiPage.beginConnect(wifiRow.net);
                                    wifiRow.net.connect();
                                }
                            }
                        ]
                    }
                }
            }

            // --- unknown + secured: the password form -----------------------
            Component {
                id: pskBody

                Column {
                    spacing: 10

                    PasswordField {
                        id: pskField

                        secret: true
                        placeholderText: I18n.t("quickSettings.wifiPassword")
                        error: wifiRow.showsError

                        // Optimistic-clear: the first edit after a failed
                        // submit dismisses the error in place.
                        onEdited: if (wifiRow.showsError) {
                            wifiRow.wifiPage.clearError();
                        }
                        onAccepted: pskConnect.clicked()

                        Component.onCompleted: {
                            forceFocus();
                            if (wifiRow.showsError) {
                                shake();
                            }
                        }
                    }

                    MD.Text {
                        width: parent.width
                        text: wifiRow.showsError ? wifiRow.wifiPage.errorText : wifiRow.secured ? wifiRow.wifiPage.securityName(wifiRow.net.security) + " · " + I18n.t("quickSettings.wifiPskHint") : I18n.t("quickSettings.wifiPskHint")
                        color: wifiRow.showsError ? MD.Token.color.error : MD.Token.color.on_surface_variant
                        typescale: MD.Token.typescale.body_small
                        prominent: wifiRow.showsError
                        font.family: Theme.textTypeface
                        wrapMode: Text.Wrap
                    }

                    RowActions {
                        leftData: [
                            ActionButton {
                                filled: false
                                text: I18n.t("quickSettings.cancel")

                                onClicked: {
                                    if (wifiRow.net.stateChanging) {
                                        wifiRow.net.disconnect();
                                    } else {
                                        wifiRow.wifiPage.toggleRow(wifiRow.net);
                                    }
                                }
                            }
                        ]
                        rightData: [
                            ActionButton {
                                id: pskConnect

                                enabled: !wifiRow.net.stateChanging
                                text: wifiRow.net.stateChanging ? I18n.t("quickSettings.wifiConnecting") : I18n.t("quickSettings.connect")

                                onClicked: {
                                    // WPA-PSK minimum; SAE shares it.
                                    if (wifiRow.wifiPage.isPskSecurity(wifiRow.net.security) && pskField.text.length < 8) {
                                        wifiRow.wifiPage.errorNetwork = wifiRow.net;
                                        wifiRow.wifiPage.errorText = I18n.t("quickSettings.wifiErrTooShort", {
                                            "security": wifiRow.wifiPage.securityName(wifiRow.net.security)
                                        });
                                        pskField.shake();
                                        pskField.forceFocus();
                                        return;
                                    }
                                    wifiRow.wifiPage.beginConnect(wifiRow.net);
                                    wifiRow.net.connectWithPsk(pskField.text);
                                }
                            }
                        ]
                    }
                }
            }

            // --- unknown + 802.1X: needs the full EAP secret agent (deferred)
            Component {
                id: eapBody

                Column {
                    spacing: 10

                    MD.Text {
                        width: parent.width
                        text: I18n.t("quickSettings.wifiEnterpriseNote")
                        color: MD.Token.color.on_surface_variant
                        typescale: MD.Token.typescale.body_small
                        font.family: Theme.textTypeface
                        wrapMode: Text.Wrap
                    }

                    RowActions {
                        leftData: [
                            ActionButton {
                                filled: false
                                text: I18n.t("quickSettings.cancel")

                                onClicked: wifiRow.wifiPage.toggleRow(wifiRow.net)
                            }
                        ]
                    }
                }
            }

            // --- unknown + open: notice --------------------------------------
            Component {
                id: openBody

                Column {
                    spacing: 10

                    MD.Text {
                        width: parent.width
                        text: wifiRow.showsError ? wifiRow.wifiPage.errorText : I18n.t("quickSettings.wifiOpenNote")
                        color: wifiRow.showsError ? MD.Token.color.error : MD.Token.color.on_surface_variant
                        typescale: MD.Token.typescale.body_small
                        prominent: wifiRow.showsError
                        font.family: Theme.textTypeface
                        wrapMode: Text.Wrap
                    }

                    RowActions {
                        leftData: [
                            ActionButton {
                                filled: false
                                text: I18n.t("quickSettings.cancel")

                                onClicked: {
                                    if (wifiRow.net.stateChanging) {
                                        wifiRow.net.disconnect();
                                    } else {
                                        wifiRow.wifiPage.toggleRow(wifiRow.net);
                                    }
                                }
                            }
                        ]
                        rightData: [
                            ActionButton {
                                enabled: !wifiRow.net.stateChanging
                                text: wifiRow.net.stateChanging ? I18n.t("quickSettings.wifiConnecting") : I18n.t("quickSettings.connect")

                                onClicked: {
                                    wifiRow.wifiPage.beginConnect(wifiRow.net);
                                    wifiRow.net.connect();
                                }
                            }
                        ]
                    }
                }
            }
        }
    }
}
