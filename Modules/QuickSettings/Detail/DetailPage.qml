import QtQuick
import QtQuick.Controls as QC
import Qcm.Material as MD
import qs.Commons.Theme
import qs.Material
import qs.Modules.QuickSettings.Controls

// Reusable detail-page chrome for the quick-settings StackView (prototype
// #viewDetail): back + title + optional radio switch header, then a scrolling
// device list. A concrete page (WifiDetailPage, ...) sets `title`/`showSwitch`/
// `switchChecked`/`onSwitchToggled` and supplies its list as `bodyContent`.
//
// The page fills the StackView; the stack owns the slide/opacity transition and
// visibility, so this carries NO enabled/opacity gating of its own (that was
// the greying-flash trap). `bodyContent` is incubated asynchronously so the
// push slide starts on the click frame and the list fills in behind it.
Item {
    id: root

    // Detail identity, set by the panel on push; reflected back into
    // QuickSettingsPanel.detail so the external contract keeps working.
    property string detailName: ""

    property string title: ""
    property bool showSwitch: false
    property bool switchChecked: false
    signal switchToggled(bool checked)

    // Optional header refresh action (Wi-Fi rescan / Bluetooth re-poll). The
    // concrete page opts in with `showRefresh` and does the work in
    // `onRefreshRequested`; the button spins on tap for feedback since a
    // re-read may surface no visible change.
    property bool showRefresh: false
    signal refreshRequested()

    // The list body (a Column). Loaded async; exposed for tests/plumbing.
    property Component bodyContent: null
    readonly property alias bodyItem: bodyLoader.item

    // The list flickable extends this far past the content, into the card's
    // right padding, so its floating scrollbar rides in that empty gutter
    // instead of over the rows. Matches QuickSettingsPanel's `pad` (the content
    // inset), so the flickable's right edge meets the card edge; the card wraps
    // the panel in a clip at the full card width, so the bar is not cut off.
    // The list body keeps the content width, so the rows themselves don't move.
    readonly property real scrollGutter: 12

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

                onClicked: root.QC.StackView.view.pop()
            }

            MD.Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.title
                color: MD.Token.color.on_surface
                typescale: MD.Token.typescale.title_medium
                prominent: true
                font.family: Theme.textTypeface
            }
        }

        // Right cluster: the optional refresh button ahead of the radio
        // switch. Row skips hidden items, so a page using only one of them
        // gets no phantom gap.
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            MD.IconButton {
                id: refreshButton

                anchors.verticalCenter: parent.verticalCenter
                visible: root.showRefresh
                // Nothing to scan while the radio is off.
                enabled: !root.showSwitch || root.switchChecked
                mdState.type: MD.Enum.IBtStandard
                mdState.size: MD.Enum.XS
                icon.name: "refresh"
                icon.width: 18
                icon.height: 18
                scale: down ? 0.88 : 1

                Behavior on scale {
                    MotionAnimation {}
                }

                onClicked: {
                    spin.restart();
                    root.refreshRequested();
                }

                // One-shot full turn; a multiple of 360 rests upright.
                NumberAnimation {
                    id: spin

                    target: refreshButton
                    property: "rotation"
                    from: 0
                    to: 360
                    duration: 500
                    easing.type: Easing.OutCubic
                }
            }

            // Prototype .swt mini switch: gates the wifi/bluetooth radios.
            MiniSwitch {
                id: dvSwitch

                anchors.verticalCenter: parent.verticalCenter
                visible: root.showSwitch
                checkedState: root.switchChecked

                onToggled: root.switchToggled(checked)
            }
        }
    }

    // --- device list (prototype .dv-list) -----------------------------------
    Item {
        id: detailListArea

        y: detailHead.height + 8
        width: parent.width
        height: parent.height - y

        // Base flickable (MD.VerticalFlickable minus its glued-to-edge
        // scrollbar) so we can attach a floating overlay bar instead.
        MD.Flickable {
            id: detailFlick

            // Stretch the (transparent) viewport into the card's right padding
            // so the overlay scrollbar sits in that gutter, clear of the rows.
            anchors.fill: parent
            anchors.rightMargin: -root.scrollGutter
            contentHeight: contentItem.childrenRect.height

            Loader {
                id: bodyLoader

                // Incubate the list across frames so the push slide starts on
                // the click frame and rows fill in behind it. Pinned to the
                // content width (not the widened viewport) so rows stay put.
                asynchronous: true
                width: detailListArea.width
                sourceComponent: root.bodyContent
            }

            // Every page carries a `viewportHeight` used by its empty state to
            // center in the list viewport.
            Binding {
                target: bodyLoader.item
                property: "viewportHeight"
                value: detailListArea.height
                when: bodyLoader.item !== null
            }

            // Floating overlay scrollbar: a thin pill riding in the card's
            // right padding (the viewport is stretched into that gutter), so
            // rows stay full-width and centered while the bar clears them. It
            // fades in while scrolling and auto-hides. Mirrors MD.ScrollBar's
            // hold-then-fade.
            QC.ScrollBar.vertical: QC.ScrollBar {
                id: detailScroll

                // Bias the 4px pill toward the inner side of the card's right
                // padding so it is not jammed against the outer edge: ~6px shy
                // of the card edge, still clear of the rows on the left.
                rightPadding: 6
                policy: QC.ScrollBar.AsNeeded
                opacity: 0

                contentItem: Rectangle {
                    implicitWidth: 4
                    radius: width / 2
                    color: MD.Util.transparent(MD.Token.color.on_surface, detailScroll.pressed ? 0.7 : 0.38)
                }

                states: State {
                    name: "shown"
                    when: detailScroll.active && detailScroll.size < 1
                }

                transitions: [
                    Transition {
                        to: "shown"
                        NumberAnimation {
                            target: detailScroll
                            property: "opacity"
                            to: 1
                            duration: 150
                        }
                    },
                    Transition {
                        from: "shown"
                        SequentialAnimation {
                            PauseAnimation {
                                duration: 1200
                            }
                            NumberAnimation {
                                target: detailScroll
                                property: "opacity"
                                to: 0
                                duration: 400
                            }
                        }
                    }
                ]
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
