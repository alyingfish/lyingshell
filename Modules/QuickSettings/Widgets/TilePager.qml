import QtQuick
import QtQuick.Controls as QC
import Quickshell.Networking
import qs.Commons.I18n
import qs.Commons.Settings
import qs.Material
import qs.Services
import "../../../Material/Motion.js" as Motion
import "../../../Material/Wheel.js" as Wheel
import "../../../Commons/Icons/StatusIcons.js" as StatusIcons

// Horizontally paged toggle-tile grid (prototype .tiles-track): 2 columns x
// 3 rows per page, tiles packed in shown order. Connectivity cluster first
// (wifi | bluetooth, wired | airplane), then appearance and page-2 extras.
//
// Built on a SwipeView: the tile set is availability-filtered into
// `shownComps` and chunked 6-per-page; each page's slots are Loaders pulling
// from that list, so pages reflow as devices appear/disappear. Pages flip by
// drag (SwipeView native), wheel/touchpad, or the dots below (PageDots).
Item {
    id: pager

    property real tileGap: 6
    readonly property real cellWidth: (width - tileGap) / 2

    // Detail-page navigation ("wifi" | "bluetooth" | "kbd").
    signal detailRequested(string name)

    // Availability-filtered tile components in prototype order. Recomputes when
    // any availability signal changes; drives page count + per-slot Loaders.
    readonly property var shownComps: {
        const list = [];
        if (SystemStatus.wifiDevice !== null) {
            list.push(wifiTileComp);
        }
        if (SystemStatus.btAdapter !== null) {
            list.push(btTileComp);
        }
        if (SystemStatus.wiredDevice !== null && (SystemStatus.wiredDevice.connected || SystemStatus.wiredDevice.networks.values.length > 0)) {
            list.push(wiredTileComp);
        }
        if (Airplane.available) {
            list.push(airplaneTileComp);
        }
        list.push(darkTileComp);
        list.push(nightTileComp);
        if (DoNotDisturb.available) {
            list.push(dndTileComp);
        }
        if (Brightness.kbdAvailable) {
            list.push(kbdTileComp);
        }
        return list;
    }

    readonly property int pageCount: Math.max(1, Math.ceil(shownComps.length / 6))
    readonly property int firstPageRows: Math.ceil(Math.min(Math.max(shownComps.length, 1), 6) / 2)
    readonly property int page: view.currentIndex

    // Motion-test probe (tests/qml/tst_quicksettings_motion.qml): SwipeView's
    // scrolling content flickable.
    readonly property Item trackItem: view.contentItem

    function setPage(target: int) {
        view.currentIndex = Math.max(0, Math.min(pageCount - 1, target));
    }

    function movePage(delta: int) {
        setPage(view.currentIndex + delta);
    }

    height: firstPageRows * 44 + (firstPageRows - 1) * tileGap
    clip: true

    QC.SwipeView {
        id: view

        anchors.fill: parent
        // Tiles handle their own press; horizontal drag past the threshold
        // takes the grab for the page swipe.
        clip: false

        Repeater {
            model: pager.pageCount

            Item {
                id: pageItem

                required property int index

                // Six slots, 2 columns x 3 rows; each loads the tile for its
                // absolute position in shownComps (empty past the end).
                Repeater {
                    model: 6

                    Loader {
                        id: slotLoader

                        required property int index
                        readonly property int slot: pageItem.index * 6 + index

                        active: slot < pager.shownComps.length
                        visible: active
                        width: pager.cellWidth
                        height: 44
                        x: (index % 2) * (pager.cellWidth + pager.tileGap)
                        y: Math.floor(index / 2) * (44 + pager.tileGap)
                        sourceComponent: active ? pager.shownComps[slot] : null
                    }
                }
            }
        }
    }

    // Wheel/touchpad anywhere over the tile area flips pages, one per
    // accumulated notch on the dominant scroll axis. Topmost button-less
    // MouseArea: wheel lands here first (and is consumed so SwipeView does not
    // also flick), clicks fall through to the tiles. Qt's wheel sign is
    // inverted relative to the web's deltaX/deltaY.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton

        property real acc: 0

        onWheel: function (wheel) {
            const angle = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y) ? wheel.angleDelta.x : wheel.angleDelta.y;
            const pixel = Math.abs(wheel.pixelDelta.x) > Math.abs(wheel.pixelDelta.y) ? wheel.pixelDelta.x : wheel.pixelDelta.y;
            const result = Wheel.wheelNotches(acc, angle, pixel);
            acc = result.acc;
            if (result.steps !== 0) {
                pager.movePage(-result.steps);
            }
            wheel.accepted = true;
        }
    }

    // --- tile components (packed by shownComps, positioned by the Loaders) ---
    Component {
        id: wifiTileComp

        QuickMenuToggle {
            width: pager.cellWidth
            labelKey: "quickSettings.wifi"
            iconName: SystemStatus.activeWifiNetwork ? StatusIcons.wifiSignalIcon(SystemStatus.activeWifiNetwork.signalStrength) : "wifi"
            offIconName: "signal_wifi_off"
            statusText: SystemStatus.activeWifiNetwork ? SystemStatus.activeWifiNetwork.name : ""
            checked: Networking.wifiEnabled

            onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
            onExpandRequested: pager.detailRequested("wifi")
        }
    }

    Component {
        id: btTileComp

        QuickMenuToggle {
            width: pager.cellWidth
            labelKey: "quickSettings.bluetooth"
            iconName: SystemStatus.btConnectedDevices.length > 0 ? "bluetooth_connected" : "bluetooth"
            offIconName: "bluetooth_disabled"
            statusText: SystemStatus.btConnectedDevices.length > 0 ? I18n.t("quickSettings.bluetoothConnectedCount", {
                "count": SystemStatus.btConnectedDevices.length
            }) : ""
            checked: SystemStatus.btEnabled

            onClicked: SystemStatus.btAdapter.enabled = !SystemStatus.btAdapter.enabled
            onExpandRequested: pager.detailRequested("bluetooth")
        }
    }

    Component {
        id: wiredTileComp

        QuickToggle {
            width: pager.cellWidth
            labelKey: "quickSettings.wired"
            icon.name: "lan"
            checked: SystemStatus.wiredConnected

            onClicked: {
                if (checked) {
                    SystemStatus.wiredDevice.disconnect();
                } else {
                    const known = SystemStatus.wiredDevice.networks.values.find(network => network !== null && network.known);
                    if (known) {
                        known.connect();
                    }
                }
            }
        }
    }

    Component {
        id: airplaneTileComp

        QuickToggle {
            width: pager.cellWidth
            labelKey: "quickSettings.airplaneMode"
            icon.name: "airplanemode_active"
            checked: Airplane.enabled

            onClicked: Airplane.toggle()
        }
    }

    Component {
        id: darkTileComp

        QuickToggle {
            width: pager.cellWidth
            labelKey: "quickSettings.darkStyle"
            // Prototype tile-dark: sun at rest, moon when on, outline glyphs
            // that fill on hover.
            icon.name: "dark_mode"
            offIconName: "light_mode"
            fillOnHover: true
            checked: Settings.options.appearance.mode === "dark"

            onClicked: Settings.options.appearance.mode = checked ? "light" : "dark"
        }
    }

    Component {
        id: nightTileComp

        QuickToggle {
            width: pager.cellWidth
            labelKey: "quickSettings.nightLight"
            icon.name: "wb_twilight"
            checked: NightLight.enabled

            onClicked: NightLight.toggle()
        }
    }

    Component {
        id: dndTileComp

        QuickToggle {
            width: pager.cellWidth
            labelKey: "quickSettings.doNotDisturb"
            icon.name: "do_not_disturb_on"
            checked: DoNotDisturb.enabled

            onClicked: DoNotDisturb.toggle()
        }
    }

    Component {
        id: kbdTileComp

        QuickMenuToggle {
            width: pager.cellWidth
            labelKey: "quickSettings.keyboardBacklight"
            // Backlight glyphs, not an input-device keyboard.
            iconName: "backlight_high"
            offIconName: "backlight_low"
            checked: Brightness.kbdLevel > 0

            onClicked: Brightness.toggleKbd()
            onExpandRequested: pager.detailRequested("kbd")
        }
    }
}
