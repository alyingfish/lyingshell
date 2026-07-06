import QtQuick
import Quickshell.Networking
import qs.Commons.I18n
import qs.Commons.Settings
import qs.Material
import qs.Services
import "../../../Material/Motion.js" as Motion
import "../../../Material/Wheel.js" as Wheel
import "../../../Commons/Icons/StatusIcons.js" as StatusIcons

// Horizontally paged toggle-tile grid (prototype .tiles-track): 2 columns x
// 3 rows per page, slots packed in shown order. Connectivity cluster first
// (wifi | bluetooth, wired | airplane), then appearance and page-2 extras.
// Pages flip by pointer drag, wheel/touchpad, or the dots below (PageDots).
Item {
    id: pager

    property real tileGap: 6
    readonly property real cellWidth: (width - tileGap) / 2

    // Detail-page navigation ("wifi" | "bluetooth" | "kbd").
    signal detailRequested(string name)

    readonly property var shownTiles: [wifiTile, btTile, wiredTile, airplaneTile, darkTile, nightTile, dndTile, kbdTile].filter(tile => tile.shown)
    readonly property int pageCount: Math.max(1, Math.ceil(shownTiles.length / 6))
    readonly property int firstPageRows: Math.ceil(Math.min(Math.max(shownTiles.length, 1), 6) / 2)
    property int page: 0
    // Live drag offset from the swipe handler (prototype .tiles-track.drag
    // follows the pointer 1:1).
    property real dragOffset: 0

    // Motion-test probe (tests/qml/tst_quicksettings_motion.qml).
    readonly property Item trackItem: tileTrack

    function setPage(target: int) {
        page = Math.max(0, Math.min(pageCount - 1, target));
    }

    function movePage(delta: int) {
        setPage(page + delta);
    }

    function slotX(index: int): real {
        if (index < 0) {
            return 0;
        }
        return Math.floor(index / 6) * width + (index % 2) * (cellWidth + tileGap);
    }

    function slotY(index: int): real {
        if (index < 0) {
            return 0;
        }
        return Math.floor((index % 6) / 2) * (44 + tileGap);
    }

    height: firstPageRows * 44 + (firstPageRows - 1) * tileGap
    clip: true

    onPageCountChanged: page = Math.min(page, pageCount - 1)

    Item {
        id: tileTrack

        width: pager.pageCount * pager.width
        height: pager.height
        x: -pager.page * pager.width + pager.dragOffset

        Behavior on x {
            enabled: !tileSwipe.active

            MotionAnimation {
                spring: Motion.spatialDefault
            }
        }

        QuickMenuToggle {
            id: wifiTile

            readonly property bool shown: SystemStatus.wifiDevice !== null

            x: pager.slotX(pager.shownTiles.indexOf(wifiTile))
            y: pager.slotY(pager.shownTiles.indexOf(wifiTile))
            width: pager.cellWidth
            visible: shown
            labelKey: "quickSettings.wifi"
            iconName: SystemStatus.activeWifiNetwork ? StatusIcons.wifiSignalIcon(SystemStatus.activeWifiNetwork.signalStrength) : "wifi"
            offIconName: "signal_wifi_off"
            statusText: SystemStatus.activeWifiNetwork ? SystemStatus.activeWifiNetwork.name : ""
            checked: Networking.wifiEnabled

            onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
            onExpandRequested: pager.detailRequested("wifi")
        }

        QuickMenuToggle {
            id: btTile

            readonly property bool shown: SystemStatus.btAdapter !== null

            x: pager.slotX(pager.shownTiles.indexOf(btTile))
            y: pager.slotY(pager.shownTiles.indexOf(btTile))
            width: pager.cellWidth
            visible: shown
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

        QuickToggle {
            id: wiredTile

            readonly property bool shown: SystemStatus.wiredDevice !== null && (SystemStatus.wiredDevice.connected || SystemStatus.wiredDevice.networks.values.length > 0)

            x: pager.slotX(pager.shownTiles.indexOf(wiredTile))
            y: pager.slotY(pager.shownTiles.indexOf(wiredTile))
            width: pager.cellWidth
            visible: shown
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

        QuickToggle {
            id: airplaneTile

            readonly property bool shown: Airplane.available

            x: pager.slotX(pager.shownTiles.indexOf(airplaneTile))
            y: pager.slotY(pager.shownTiles.indexOf(airplaneTile))
            width: pager.cellWidth
            visible: shown
            labelKey: "quickSettings.airplaneMode"
            icon.name: "airplanemode_active"
            checked: Airplane.enabled

            onClicked: Airplane.toggle()
        }

        QuickToggle {
            id: darkTile

            readonly property bool shown: true

            x: pager.slotX(pager.shownTiles.indexOf(darkTile))
            y: pager.slotY(pager.shownTiles.indexOf(darkTile))
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

        QuickToggle {
            id: nightTile

            readonly property bool shown: true

            x: pager.slotX(pager.shownTiles.indexOf(nightTile))
            y: pager.slotY(pager.shownTiles.indexOf(nightTile))
            width: pager.cellWidth
            visible: shown
            labelKey: "quickSettings.nightLight"
            icon.name: "wb_twilight"
            checked: NightLight.enabled

            onClicked: NightLight.toggle()
        }

        QuickToggle {
            id: dndTile

            readonly property bool shown: DoNotDisturb.available

            x: pager.slotX(pager.shownTiles.indexOf(dndTile))
            y: pager.slotY(pager.shownTiles.indexOf(dndTile))
            width: pager.cellWidth
            visible: shown
            labelKey: "quickSettings.doNotDisturb"
            icon.name: "do_not_disturb_on"
            checked: DoNotDisturb.enabled

            onClicked: DoNotDisturb.toggle()
        }

        QuickMenuToggle {
            id: kbdTile

            readonly property bool shown: Brightness.kbdAvailable

            x: pager.slotX(pager.shownTiles.indexOf(kbdTile))
            y: pager.slotY(pager.shownTiles.indexOf(kbdTile))
            width: pager.cellWidth
            visible: shown
            labelKey: "quickSettings.keyboardBacklight"
            // Backlight glyphs, not an input-device keyboard.
            iconName: "backlight_high"
            offIconName: "backlight_low"
            checked: Brightness.kbdLevel > 0

            onClicked: Brightness.toggleKbd()
            onExpandRequested: pager.detailRequested("kbd")
        }
    }

    // Pointer-drag swipe between pages (prototype tiles-track drag): passive
    // until the drag threshold, then it takes the grab from the pressed tile
    // so the release cannot also toggle it.
    DragHandler {
        id: tileSwipe

        target: null
        xAxis.enabled: true
        yAxis.enabled: false

        onActiveTranslationChanged: if (active)
            pager.dragOffset = activeTranslation.x
        onActiveChanged: {
            if (!active) {
                const moved = pager.dragOffset;
                pager.dragOffset = 0;
                if (Math.abs(moved) > 45) {
                    pager.movePage(moved < 0 ? 1 : -1);
                }
            }
        }
    }

    // Wheel/touchpad anywhere over the tile area flips pages, one per
    // accumulated notch on the dominant scroll axis. Topmost button-less
    // MouseArea: wheel lands here first, clicks fall through to the tiles
    // (WheelHandler gets no wheel events on the live compositor). Qt's wheel
    // sign is inverted relative to the web's deltaX/deltaY.
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
}
