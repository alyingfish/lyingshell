import QtQuick
import Quickshell
import Qcm.Material as MD
import qs.Commons.Settings
import qs.Material
import qs.Services
import qs.Services.Niri
import qs.Modules.QuickSettings.Main
import qs.Modules.QuickSettings.Detail
import qs.Modules.QuickSettings.Detail.Pages
import "../../Material/Motion.js" as Motion

// Quick-settings panel content mirroring the web prototype: a 344px card
// (12px padding, 10px section gap) of header actions + battery pill, two
// expandable rows (tools, power mode), expressive sliders, a horizontally
// paged toggle-tile grid with page dots, and sliding detail views (Wi-Fi /
// Bluetooth / Sound / Keyboard). System state lives in Quickshell
// services and the qs.Services boundaries; this module only wires state to
// MD3 controls.
//
// Navigation is an MD.StackView: MainPage is the initial item, each detail is a
// self-contained DetailPage pushed on top. The stack owns page
// visibility/input/lifecycle, so switching views can never grey a control
// (the old `enabled`-gated crossfade bug) and nested drill-downs are free.
// Motion map: the prototype's `--spring-soft` is Motion.spatialDefault, its
// short standard fades are the effects springs. This file owns panel state and
// composition; the pieces live in Widgets/.
Item {
    id: root

    signal closeRequested
    // Asks the host (QuickSettingsButton via the popup) to reopen the panel;
    // emitted when a colour pick completes while the panel is closed.
    signal openRequested

    // Mirrors the menu's open state so the staggered entrance can run at the
    // start of the card's open transform.
    property bool open: false

    // "" | "wifi" | "bluetooth" | "sound" | "kbd" | "color". Settable command
    // AND a reflection of the stack (the back button pops directly); kept for
    // the external contract (serializeState / setDetail / e2e).
    property string detail: ""

    // Session-menu card (prototype #pmenu) floats over the panel at top-right.
    property bool sessionMenuOpen: false

    // Layout metrics (web prototype: 344px panel, 12px padding, 10px section gap).
    readonly property real pad: 12
    readonly property real sectionGap: 10
    readonly property real contentWidth: 344 - pad * 2

    // Expandable-row state lives in the header; aliased here for tests/e2e.
    property alias toolsOpen: mainPage.toolsOpen
    property alias pmodeOpen: mainPage.pmodeOpen
    // Unified reveal (0 closed, 1 open) driving the row-switcher height.
    property alias switchReveal: mainPage.switchReveal

    // Test/e2e surface (tests/e2e/QuickSettingsIpcDriver.qml,
    // tests/qml/tst_quicksettings_motion.qml).
    readonly property int page: mainPage.page
    readonly property int pageCount: mainPage.pageCount
    readonly property Item tileArea: mainPage.tileArea
    readonly property Item volumeRow: mainPage.volumeRow
    readonly property real switchSlideProbe: mainPage.switchSlideProbe
    readonly property real headerOpacityProbe: mainPage.headerOpacityProbe
    readonly property real pagerOpacityProbe: mainPage.pagerOpacityProbe
    readonly property Item tileTrackProbe: mainPage.tileTrackProbe
    // Slide probes read the stack items' transform (StackView drives x/opacity).
    readonly property real mainSlideProbe: mainPage.x
    readonly property real detailSlideProbe: (stack.depth > 1 && stack.currentItem) ? stack.currentItem.x : 0

    function setPage(page: int) {
        mainPage.setPage(page);
    }

    // Detail name -> page component (add a panel = new DetailPage + one entry).
    readonly property var detailMap: ({
            "wifi": wifiComp,
            "bluetooth": btComp,
            "sound": soundComp,
            "kbd": kbdComp,
            "color": colorComp
        })

    Component {
        id: wifiComp

        WifiDetailPage {}
    }

    Component {
        id: colorComp

        ColorDetailPage {
            onPickRequested: root.beginColorPick()
        }
    }

    Component {
        id: btComp

        BluetoothDetailPage {}
    }

    Component {
        id: soundComp

        SoundDetailPage {}
    }

    Component {
        id: kbdComp

        KbdDetailPage {}
    }

    // Reconcile the stack to match `detail` (idempotent so it composes with the
    // back button's direct pop() + the stack->detail sync below without looping).
    function reconcileStack() {
        const cur = (stack.depth > 1 && stack.currentItem) ? (stack.currentItem.detailName ?? "") : "";
        if (cur === detail) {
            return;
        }
        if (detail === "") {
            stack.pop(null);
            return;
        }
        const comp = detailMap[detail];
        if (!comp) {
            return;
        }
        // Drop the session card; the expandable rows keep their toggle state
        // behind the detail (mainPage.lastShownHeight locks the panel to the
        // height they gave it, so the swap stays 1:1).
        sessionMenuOpen = false;
        if (stack.depth > 1) {
            stack.replace(comp);
        } else {
            stack.push(comp);
        }
    }

    function syncDetailFromStack() {
        const name = (stack.depth > 1 && stack.currentItem) ? (stack.currentItem.detailName ?? "") : "";
        if (detail !== name) {
            detail = name;
        }
    }

    onDetailChanged: reconcileStack()

    implicitWidth: contentWidth + pad * 2
    // Detail pages lock the height the main view last had on screen (open
    // rows included, via mainPage.lastShownHeight — the StackView's hide
    // collapses any live measurement), so navigation never resizes the panel.
    implicitHeight: pad * 2 + (detail !== "" ? mainPage.lastShownHeight : mainPage.implicitHeight)

    // Colour-pick handoff (tools row + the readout page's "pick again"): the
    // target pixel may sit behind the card, so the panel closes for the aim
    // while pickPending keeps its state (open rows, current detail) through
    // the hide; the reply reopens it on the readout page. A cancelled pick
    // (Esc) never replies — the panel just stays closed with its state
    // intact, and the handoff ends on the next open.
    property bool pickPending: false

    function beginColorPick() {
        pickPending = true;
        if (!Niri.pickColor()) {
            pickPending = false;
            return;
        }
        closeRequested();
    }

    // Refresh process-backed state whenever the panel becomes visible; reset
    // the navigation/row state on close (skipped while a pick is pending, so
    // the reopened panel resumes where the user left it).
    onVisibleChanged: {
        if (visible) {
            pickPending = false;
            Brightness.refresh();
            Airplane.refresh();
            DoNotDisturb.refresh();
        } else if (!pickPending) {
            detail = "";
            mainPage.collapseRowsInstant();
            sessionMenuOpen = false;
            mainPage.setPage(0);
        }
    }

    // Wi-Fi scanning only while the network detail is open (kept here so it
    // outlives the pushed page's lifecycle).
    Binding {
        target: SystemStatus.wifiDevice
        property: "scannerEnabled"
        value: root.detail === "wifi"
        when: SystemStatus.wifiDevice !== null
    }

    // Bluetooth discovery + discoverability only while the bluetooth detail
    // is open (BlueZ StartDiscovery; GNOME Settings makes the adapter
    // discoverable while its page is up).
    Binding {
        target: SystemStatus.btAdapter
        property: "discovering"
        value: root.detail === "bluetooth" && SystemStatus.btEnabled
        when: SystemStatus.btAdapter !== null
    }

    Binding {
        target: SystemStatus.btAdapter
        property: "discoverable"
        value: root.detail === "bluetooth" && SystemStatus.btEnabled
        when: SystemStatus.btAdapter !== null
    }

    // Connect/pair failure toasts fire only while the matching detail page
    // is not on screen (the page shows the error inline).
    Binding {
        target: ConnectFeedback
        property: "visibleDetail"
        value: root.visible ? root.detail : ""
    }

    // Recent-colors history behind the readout page's grid. Recorded here,
    // not in the page: the page is rebuilt on every push, but the panel hears
    // every pick. The readout's slot count mirrors this cap.
    readonly property int maxRecentColors: 8

    function recordRecentColor(hex) {
        const prior = Settings.options.quickSettings.colorPicker.recentColors || [];
        Settings.options.quickSettings.colorPicker.recentColors = [hex].concat(prior.filter(c => c !== hex)).slice(0, maxRecentColors);
    }

    // A completed color pick reopens the panel on its readout page (the
    // handoff closed it for the aim). The hex also lands on the clipboard,
    // GNOME-picker style; the page copies other formats. Copy via a detached
    // wl-copy rather than Quickshell.clipboardText: the latter stops serving
    // the selection once no shell surface is focused, so a paste after the
    // panel closes would come up empty.
    Connections {
        target: Niri

        function onColorPicked(hex) {
            Quickshell.execDetached(["wl-copy", hex]);
            root.recordRecentColor(hex);
            root.pickPending = false;
            root.detail = "color";
            root.openRequested();
        }
    }

    // ======================================================================
    // Navigation stack: MainPage (initial) + pushed DetailPages
    // ======================================================================
    MD.StackView {
        id: stack

        x: root.pad
        y: root.pad
        width: root.contentWidth
        // Detail pages lock the last shown main height; main drives it otherwise.
        height: root.detail !== "" ? mainPage.lastShownHeight : mainPage.implicitHeight

        initialItem: mainPage

        // Keep the back button's pop() and setDetail() as one source of truth.
        onCurrentItemChanged: root.syncDetailFromStack()

        // Prototype crossfade: incoming detail slides in from +44, the outgoing
        // main slides to -28, opacity crosses on the effects spring; reversed on
        // pop. Same offsets/springs as the hand-rolled version it replaces.
        pushEnter: Transition {
            MotionAnimation {
                property: "x"
                from: 44
                to: 0
                spring: Motion.spatialDefault
            }

            MotionAnimation {
                property: "opacity"
                from: 0
                to: 1
                spring: Motion.effectsDefault
            }
        }

        pushExit: Transition {
            MotionAnimation {
                property: "x"
                from: 0
                to: -28
                spring: Motion.spatialDefault
            }

            MotionAnimation {
                property: "opacity"
                from: 1
                to: 0
                spring: Motion.effectsDefault
            }
        }

        popEnter: Transition {
            MotionAnimation {
                property: "x"
                from: -28
                to: 0
                spring: Motion.spatialDefault
            }

            MotionAnimation {
                property: "opacity"
                from: 0
                to: 1
                spring: Motion.effectsDefault
            }
        }

        popExit: Transition {
            MotionAnimation {
                property: "x"
                from: 0
                to: 44
                spring: Motion.spatialDefault
            }

            MotionAnimation {
                property: "opacity"
                from: 1
                to: 0
                spring: Motion.effectsDefault
            }
        }

        replaceEnter: stack.pushEnter
        replaceExit: stack.pushExit
    }

    MainPage {
        id: mainPage

        sectionGap: root.sectionGap
        open: root.open
        powerMenuOpen: root.sessionMenuOpen

        onCloseRequested: root.closeRequested()
        onDetailRequested: name => root.detail = name
        onPowerRequested: root.sessionMenuOpen = !root.sessionMenuOpen
        onPickRequested: root.beginColorPick()
    }

    // ======================================================================
    // Session menu (prototype #pmenu): a card over the panel + a catcher that
    // dismisses it on any press elsewhere in the panel.
    // ======================================================================
    MouseArea {
        anchors.fill: parent
        z: 5
        visible: root.sessionMenuOpen
        acceptedButtons: Qt.AllButtons

        onPressed: root.sessionMenuOpen = false
    }

    SessionMenu {
        id: sessionMenu

        z: 6
        open: root.sessionMenuOpen
        // Prototype #pmenu: right edge flush with the content's right edge,
        // 6px below the 32px header row.
        x: root.pad + root.contentWidth - width
        y: root.pad + 32 + 6

        onPanelCloseRequested: root.closeRequested()
    }
}
