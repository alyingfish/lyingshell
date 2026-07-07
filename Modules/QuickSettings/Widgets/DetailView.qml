import QtQuick
import Quickshell.Networking
import Qcm.Material as MD
import qs.Commons.I18n
import qs.Commons.Theme
import qs.Material
import qs.Services
import "../../../Material/Motion.js" as Motion

// Detail view (prototype #viewDetail): slides in over the locked-height
// panel; back + title + radio-switch header, then a scrolling device list
// loaded from the sibling *DetailPage files.
Item {
    id: root

    // Live detail target: "" | "wifi" | "bluetooth" | "output" | "kbd".
    property string detail: ""
    // The mounted page: lags `detail` on close so the exit slide has content
    // to fade out (the panel owns the lag timer).
    property string shownDetail: ""

    signal backRequested

    // Motion probe (tests/qml/tst_quicksettings_motion.qml).
    readonly property real slideX: detailTx.x

    visible: shownDetail !== ""
    // Input is gated by pointer-events (detailCatch below), NOT `enabled`:
    // disabling would grey the back button / switch during the fade, a flash
    // the prototype's pure crossfade never has.
    opacity: detail !== "" ? 1 : 0

    // Prototype #viewDetail pointer-events: swallow stray input over the covered
    // main view while the detail is active; its own controls sit above this.
    MouseArea {
        anchors.fill: parent
        enabled: root.detail !== ""
        acceptedButtons: Qt.AllButtons
        onWheel: wheel => wheel.accepted = true
    }

    transform: Translate {
        id: detailTx

        x: root.detail !== "" ? 0 : 44

        Behavior on x {
            MotionAnimation {
                spring: Motion.spatialDefault
            }
        }
    }

    Behavior on opacity {
        MotionAnimation {
            spring: Motion.effectsDefault
        }
    }

    // Wifi scanning only while the network list is open.
    Binding {
        target: SystemStatus.wifiDevice
        property: "scannerEnabled"
        value: root.detail === "wifi"
        when: SystemStatus.wifiDevice !== null
    }

    // --- detail header (prototype .dv-head) --------------------------------
    Item {
        id: detailHead

        width: parent.width
        height: 32

        Row {
            anchors.left: parent.left
            anchors.leftMargin: -4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            MD.IconButton {
                id: backButton

                anchors.verticalCenter: parent.verticalCenter
                mdState.type: MD.Enum.IBtStandard
                mdState.size: MD.Enum.XS
                icon.name: "arrow_back"
                icon.width: 18
                icon.height: 18
                scale: down ? 0.88 : 1

                Behavior on scale {
                    MotionAnimation {}
                }

                onClicked: root.backRequested()

                MD.ToolTip {
                    y: parent.height + 4
                    text: I18n.t("quickSettings.back")
                    visible: backButton.hovered
                }
            }

            MD.Text {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    if (root.shownDetail === "wifi") {
                        return I18n.t("quickSettings.wifi");
                    }
                    if (root.shownDetail === "bluetooth") {
                        return I18n.t("quickSettings.bluetooth");
                    }
                    if (root.shownDetail === "kbd") {
                        return I18n.t("quickSettings.keyboardBacklight");
                    }
                    return I18n.t("quickSettings.outputDevice");
                }
                color: MD.Token.color.on_surface
                typescale: MD.Token.typescale.title_medium
                prominent: true
                font.family: Theme.textTypeface
            }
        }

        // Prototype .swt mini switch: gates the wifi/bluetooth radios.
        MD.Switch {
            id: dvSwitch

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.shownDetail === "wifi" || root.shownDetail === "bluetooth"

            // A Binding object re-asserts service state after user toggles
            // wrote `checked` directly.
            Binding {
                target: dvSwitch
                property: "checked"
                value: root.shownDetail === "wifi" ? Networking.wifiEnabled : SystemStatus.btEnabled
            }

            onToggled: {
                if (root.shownDetail === "wifi") {
                    Networking.wifiEnabled = checked;
                } else if (SystemStatus.btAdapter !== null) {
                    SystemStatus.btAdapter.enabled = checked;
                }
            }

            // Prototype 34x20 track, 10px outline thumb growing to a 15px
            // filled one; springs on the thumb travel and size.
            indicator: Rectangle {
                id: swtTrack

                width: 34
                height: 20
                radius: 10
                y: (dvSwitch.height - height) / 2
                color: dvSwitch.checked ? MD.Token.color.primary : MD.Token.color.surface_container_highest
                border.width: 2
                border.color: dvSwitch.checked ? MD.Token.color.primary : MD.Token.color.outline

                Behavior on color {
                    MotionColorAnimation {}
                }

                Behavior on border.color {
                    MotionColorAnimation {}
                }

                Rectangle {
                    readonly property real thumbSize: dvSwitch.checked ? 15 : dvSwitch.pressed ? 13 : 10

                    x: dvSwitch.checked ? swtTrack.width - width - 2.5 : 3
                    anchors.verticalCenter: parent.verticalCenter
                    width: thumbSize
                    height: thumbSize
                    radius: thumbSize / 2
                    color: dvSwitch.checked ? MD.Token.color.on_primary : MD.Token.color.outline

                    Behavior on x {
                        MotionAnimation {}
                    }

                    Behavior on width {
                        MotionAnimation {}
                    }

                    Behavior on color {
                        MotionColorAnimation {}
                    }
                }
            }
        }
    }

    // --- device list (prototype .dv-list) -----------------------------------
    Item {
        id: detailListArea

        y: detailHead.height + 8
        width: parent.width
        height: parent.height - y

        MD.VerticalFlickable {
            id: detailFlick

            anchors.fill: parent

            Loader {
                id: detailLoader

                // Incubate the page (and the Wi-Fi list's up-to-10 rows) across
                // frames instead of in one synchronous burst, so the detail
                // slide starts on the click frame and the list fills in behind
                // it rather than the transition waiting on the build.
                asynchronous: true
                // Never (async-)load an empty source; unload once the exit
                // slide has released the mounted page.
                active: root.shownDetail !== ""
                width: parent.width
                source: {
                    if (root.shownDetail === "wifi") {
                        return "WifiDetailPage.qml";
                    }
                    if (root.shownDetail === "bluetooth") {
                        return "BluetoothDetailPage.qml";
                    }
                    if (root.shownDetail === "output") {
                        return "OutputDetailPage.qml";
                    }
                    if (root.shownDetail === "kbd") {
                        return "KbdDetailPage.qml";
                    }
                    return "";
                }
            }

            // Every page carries a `viewportHeight` used by its empty state
            // to center in the list viewport.
            Binding {
                target: detailLoader.item
                property: "viewportHeight"
                value: detailListArea.height
                when: detailLoader.item !== null
            }
        }

        // Prototype edge fade: clipped rows read as "more to scroll".
        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 14
            visible: detailFlick.contentHeight > detailFlick.height && detailFlick.contentY > 1
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: MD.Token.color.surface_container_low
                }

                GradientStop {
                    position: 1
                    color: MD.Util.transparent(MD.Token.color.surface_container_low, 0)
                }
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 14
            visible: detailFlick.contentHeight > detailFlick.height && detailFlick.contentY < detailFlick.contentHeight - detailFlick.height - 1
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: MD.Util.transparent(MD.Token.color.surface_container_low, 0)
                }

                GradientStop {
                    position: 1
                    color: MD.Token.color.surface_container_low
                }
            }
        }
    }
}
