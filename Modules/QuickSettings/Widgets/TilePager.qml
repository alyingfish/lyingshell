import QtQuick
import Quickshell.Networking
import qs.Commons.I18n
import qs.Commons.Settings
import qs.Material
import qs.Services
import "../../../Material/Wheel.js" as Wheel
import "../../../Commons/Icons/StatusIcons.js" as StatusIcons

// Horizontally paged toggle-tile grid (prototype .tiles-track): 2 columns x
// 3 rows per page, tiles packed in shown order. Connectivity cluster first
// (wifi | bluetooth, wired | airplane), then appearance and page-2 extras.
//
// The tile set is availability-filtered into `shownComps` and chunked
// 6-per-page; each page's slots are Loaders pulling from that list, so pages
// reflow as devices appear/disappear. All pages sit side by side on a single
// track (prototype .tiles-track) translated by one panel width per page.
//
// The flip is a full-width slide on the prototype's exact page-turn curve:
// `.tiles-track { transition: transform .5s var(--spring-soft) }`, i.e.
// cubic-bezier(.38, 1.21, .22, 1) over 500ms (see `springSoft`). This is NOT
// an MD3 spring token: those overshoot late (~82% of the timeline), while the
// prototype front-loads the travel (~92% done by 160ms) and peaks its ~1.4%
// overshoot near 56%, so spatialDefault/Slow drift 20-60px off the prototype
// mid-slide (measured; the slow token was the worse of the two). It stays a
// pure spatial slide -- opacity is left alone, as the prototype cross-fades
// nothing here. A strict-range SwipeView snaps contentX and fixup-fights any
// overshoot, so it could never trace this. Pages flip by wheel or the dots.
//
// ponytail: dropped the SwipeView finger-drag swipe. Both target machines are
// pointer-driven (mouse + touchpad), so the real page inputs are the wheel and
// the dots; add a DragHandler + drag-gated Behavior if a touchscreen lands.
Item {
    id: pager

    property real tileGap: 6
    readonly property real cellWidth: (width - tileGap) / 2

    // Prototype --spring-soft as a MotionAnimation spring (duration + Bezier
    // control points): the literal cubic-bezier(.38,1.21,.22,1) at .5s. One
    // cubic segment ending at (1,1); the 1.21 control-y is the overshoot.
    readonly property var springSoft: ({
            "duration": 500,
            "curve": [0.38, 1.21, 0.22, 1.0, 1.0, 1.0]
        })

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
    property int page: 0

    // Follow the count down when a device disappears out from under us.
    onPageCountChanged: if (page > pageCount - 1) {
        setPage(pageCount - 1);
    }

    // Motion-test probe (tests/qml/tst_quicksettings_motion.qml): the sliding
    // page track. Its x runs 0 -> -page*width with the spring rebound.
    readonly property Item trackItem: track

    function setPage(target: int) {
        page = Math.max(0, Math.min(pageCount - 1, target));
    }

    function movePage(delta: int) {
        setPage(page + delta);
    }

    height: firstPageRows * 44 + (firstPageRows - 1) * tileGap
    clip: true

    // Prototype .tiles-track: every page side by side, the whole track slid
    // one panel width per page on the exact prototype curve; the overshoot then
    // settle is the rebound.
    Item {
        id: track

        width: pager.width * pager.pageCount
        height: pager.height
        x: -pager.page * pager.width

        Behavior on x {
            MotionAnimation {
                spring: pager.springSoft
            }
        }

        Repeater {
            model: pager.pageCount

            Item {
                id: pageItem

                required property int index

                x: index * pager.width
                width: pager.width
                height: track.height

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
    // MouseArea over the track: wheel lands here (and is consumed), clicks fall
    // through to the tiles. Qt's wheel sign is inverted relative to the web's
    // deltaX/deltaY.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton

        property real acc: 0

        onWheel: function (wheel) {
            // niri owns scroll-direction (natural scroll); take the wheel at
            // face value. Dominant axis so a horizontal wheel or two-finger
            // swipe pages too: up/left = previous page, down/right = next page.
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
            // Prototype tile-dark: sun at rest, moon when on; filled glyphs.
            icon.name: "dark_mode"
            offIconName: "light_mode"
            alwaysFill: true
            checked: Settings.options.appearance.mode === "dark"

            onClicked: Settings.options.appearance.mode = checked ? "light" : "dark"
        }
    }

    Component {
        id: nightTileComp

        QuickToggle {
            width: pager.cellWidth
            labelKey: "quickSettings.nightLight"
            // wb_twilight at rest, nightlight (moon) when on; filled glyphs.
            icon.name: "nightlight"
            offIconName: "wb_twilight"
            alwaysFill: true
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
            // Backlight glyphs, not an input-device keyboard. Track the level
            // like the detail page: off / low (below max) / high (at max).
            iconName: Brightness.kbdLevel >= Brightness.kbdMax ? "backlight_high" : "backlight_low"
            offIconName: "backlight_high_off"
            checked: Brightness.kbdLevel > 0

            onClicked: Brightness.toggleKbd()
            onExpandRequested: pager.detailRequested("kbd")
        }
    }
}
