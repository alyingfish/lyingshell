import QtQuick
import Qcm.Material as MD
import qs.Material
import qs.Services
import qs.Modules.QuickSettings.Widgets
import "../../Material/Motion.js" as Motion

// Quick-settings panel content mirroring the web prototype: a 344px card
// (12px padding, 10px section gap) of header actions + battery pill, two
// expandable rows (tools, power mode), expressive sliders, a horizontally
// paged toggle-tile grid with page dots, and sliding detail views (Wi-Fi /
// Bluetooth / Sound output / Keyboard). System state lives in Quickshell
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

    // Mirrors the menu's open state so the staggered entrance can run at the
    // start of the card's open transform.
    property bool open: false

    // "" | "wifi" | "bluetooth" | "output" | "kbd". Settable command AND a
    // reflection of the stack (the back button pops directly); kept for the
    // external contract (serializeState / setDetail / e2e).
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
    readonly property real compactContentHeight: mainPage.compactContentHeight
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
            "output": outputComp,
            "kbd": kbdComp
        })

    Component {
        id: wifiComp

        WifiDetailPage {}
    }

    Component {
        id: btComp

        BluetoothDetailPage {}
    }

    Component {
        id: outputComp

        OutputDetailPage {}
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
        // Lock the compact height and drop the session card before the detail
        // page replaces the main view 1:1 (prototype collapseRowsInstant).
        mainPage.collapseRowsInstant();
        // Freeze the compact height now, while MainPage is still visible: once
        // the StackView puts the detail on top it sets mainPage.visible=false,
        // which cascades to descendants (e.g. the page dots), collapsing any
        // live measurement of MainPage and shrinking the panel. Prototype:
        // qs.style.height = getBoundingClientRect().height.
        detailHeight = mainPage.compactContentHeight;
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

    // Frozen compact height used while a detail is shown. Snapshotted in
    // reconcileStack() before the StackView hides MainPage, so navigation never
    // resizes the panel. Live-bound (and thus correct) until the first push
    // reassigns it to a constant.
    property real detailHeight: mainPage.compactContentHeight

    implicitWidth: contentWidth + pad * 2
    implicitHeight: pad * 2 + (detail !== "" ? detailHeight : mainPage.implicitHeight)

    // Refresh process-backed state whenever the panel becomes visible.
    onVisibleChanged: {
        if (visible) {
            Brightness.refresh();
            Airplane.refresh();
            DoNotDisturb.refresh();
        } else {
            detail = "";
            mainPage.toolsOpen = false;
            mainPage.pmodeOpen = false;
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

    // ======================================================================
    // Navigation stack: MainPage (initial) + pushed DetailPages
    // ======================================================================
    MD.StackView {
        id: stack

        x: root.pad
        y: root.pad
        width: root.contentWidth
        // Detail pages lock the frozen compact height; main drives it otherwise.
        height: root.detail !== "" ? root.detailHeight : mainPage.implicitHeight

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
