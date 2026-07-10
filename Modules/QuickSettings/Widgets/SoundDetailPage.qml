import QtQuick
import Qcm.Material as MD
import qs.Commons.I18n
import qs.Commons.Theme
import qs.Material
import qs.Services
import "../../../Commons/Icons/StatusIcons.js" as StatusIcons

// Sound detail page (web-prototype sound detail): labelled Output / Input
// device sections and a per-app volume mixer, in that order. Each section
// hides itself when it has nothing to show, and one entrance stagger walks
// every subheader and row on the page. Reached from the volume slider's
// trailing mixer button (prototype `tune` glyph).
DetailPage {
    id: root

    detailName: "sound"
    title: I18n.t("quickSettings.sound")

    // MD3 list subheader between the sections (prototype .dv-sec): a small
    // emphasized on-surface-variant caption, indented 8px, joining the rows'
    // entrance stagger.
    component SectionLabel: Item {
        id: sectionLabel

        property alias text: sectionText.text
        property int order: 0

        width: parent ? parent.width : 0
        implicitHeight: sectionText.implicitHeight

        MD.Text {
            id: sectionText

            x: 8
            width: parent.width - 8
            color: MD.Token.color.on_surface_variant
            typescale: MD.Token.typescale.label_medium
            prominent: true
            font.family: Theme.textTypeface
            elide: Text.ElideRight
            maximumLineCount: 1
            wrapMode: Text.NoWrap
        }

        transform: Translate {
            id: sectionTy
        }

        Component.onCompleted: sectionIn.restart()

        DetailRise {
            id: sectionIn

            target: sectionLabel
            translate: sectionTy
            order: sectionLabel.order
        }
    }

    // Per-app mixer row (prototype .dva): a DetailRow-shaped vessel holding
    // the app's mute button (spanning both lines), its name over a live
    // percent readout, and a compact expressive slider. The 7px inset
    // centers the mute glyph on the device rows' icon column (14 + 18/2);
    // the body sits just past the device rows' text column (14 + 18 + 10 =
    // 42) so the name lines up with them yet clears the filled mute pill.
    component MixerRow: Rectangle {
        id: mixerRow

        required property var node
        property int order: 0

        readonly property bool streamMuted: mixerRow.node.audio !== null && mixerRow.node.audio.muted
        readonly property real streamVolume: mixerRow.node.audio !== null ? mixerRow.node.audio.volume : 0

        width: parent ? parent.width : 0
        implicitHeight: mixerBody.implicitHeight + 12
        radius: 15
        color: MD.Token.color.surface_container_high

        transform: Translate {
            id: mixerTy
        }

        Component.onCompleted: mixerIn.restart()

        DetailRise {
            id: mixerIn

            target: mixerRow
            translate: mixerTy
            order: mixerRow.order
        }

        // The app's mute toggle, filling primary while muted (prototype
        // `.dva .ib.on`). Like QuickSlider's icon slot, the 32px box centers
        // the button so its 4px touch-target insets overflow the slot and
        // the visual pill/glyph land exactly on the device rows' icon column.
        Item {
            x: 7
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32

            ReactiveIconButton {
                anchors.centerIn: parent
                iconName: StatusIcons.volumeIcon(mixerRow.streamVolume, mixerRow.streamMuted)
                checked: mixerRow.streamMuted
                tooltipKey: mixerRow.streamMuted ? "quickSettings.unmute" : "quickSettings.mute"
                onClicked: Audio.toggleStreamMuted(mixerRow.node)
            }
        }

        Column {
            id: mixerBody

            anchors.left: parent.left
            anchors.leftMargin: 44
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter

            Item {
                width: parent.width
                implicitHeight: nameText.implicitHeight

                MD.Text {
                    id: nameText

                    anchors.left: parent.left
                    anchors.right: percentText.left
                    anchors.rightMargin: 8
                    text: {
                        const props = mixerRow.node.properties;
                        const app = props ? props["application.name"] : "";
                        if (app && app.length > 0) {
                            return app;
                        }
                        return mixerRow.node.description.length > 0 ? mixerRow.node.description : mixerRow.node.name;
                    }
                    // Muted rows hand the name to on-surface-variant
                    // (prototype `.dva.muted .anm`).
                    color: mixerRow.streamMuted ? MD.Token.color.on_surface_variant : MD.Token.color.on_surface
                    typescale: MD.Token.typescale.label_medium
                    prominent: true
                    font.family: Theme.textTypeface
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    wrapMode: Text.NoWrap

                    Behavior on color {
                        MotionColorAnimation {}
                    }
                }

                // Live level readout standing in for the drag pill the
                // compact slider drops (prototype `.dva-nm .pc`).
                MD.Text {
                    id: percentText

                    anchors.right: parent.right
                    anchors.baseline: nameText.baseline
                    text: mixerRow.streamMuted ? I18n.t("quickSettings.muted") : I18n.t("quickSettings.volumePercent", {
                        "percent": Math.round(mixerRow.streamVolume * 100)
                    })
                    color: MD.Token.color.on_surface_variant
                    typescale: MD.Token.typescale.label_small
                    prominent: true
                    font.family: Theme.textTypeface
                }
            }

            QuickSlider {
                width: parent.width
                compact: true
                hasIcon: false
                hasTrailing: false
                iconName: ""
                value: mixerRow.streamVolume
                dimmed: mixerRow.streamMuted

                onMoved: newValue => Audio.setStreamVolume(mixerRow.node, newValue)
            }
        }
    }

    bodyContent: Component {
        Column {
            id: page

            property real viewportHeight: 0

            // Between sections: the 5px list gap plus the 5px the prototype
            // adds above a later section's label (.dv-sec ~ .dv-sec).
            spacing: 10

            // One entrance-stagger counter walks the whole page, skipping
            // hidden sections (prototype: the dvIn delay indexes every
            // rendered subheader and row in turn).
            readonly property int inputOrder: 1 + Audio.sinkDevices.length
            readonly property int appsOrder: inputOrder + (Audio.sourceDevices.length > 0 ? 1 + Audio.sourceDevices.length : 0)

            // --- Output devices ------------------------------------------------
            Column {
                width: parent.width
                spacing: 5

                SectionLabel {
                    order: 0
                    text: I18n.t("quickSettings.soundOutputs")
                }

                Repeater {
                    model: Audio.sinkDevices

                    DetailRow {
                        id: sinkRow

                        required property var modelData
                        required property int index

                        // Description + name feed the icon/type keyword scans.
                        readonly property string deviceLabel: sinkRow.modelData.description + " " + sinkRow.modelData.name
                        readonly property string typeToken: "quickSettings.outputType." + StatusIcons.audioSinkType(sinkRow.deviceLabel)

                        order: 1 + index
                        text: sinkRow.modelData.description.length > 0 ? sinkRow.modelData.description : sinkRow.modelData.name
                        subText: I18n.t(sinkRow.typeToken)
                        current: Audio.sink !== null && sinkRow.modelData.id === Audio.sink.id
                        leadingIcon: StatusIcons.audioSinkIcon(sinkRow.deviceLabel)

                        onClicked: Audio.setPreferredSink(sinkRow.modelData)
                    }
                }
            }

            // --- Input devices -------------------------------------------------
            Column {
                width: parent.width
                spacing: 5
                visible: Audio.sourceDevices.length > 0

                SectionLabel {
                    order: page.inputOrder
                    text: I18n.t("quickSettings.soundInputs")
                }

                Repeater {
                    model: Audio.sourceDevices

                    DetailRow {
                        id: sourceRow

                        required property var modelData
                        required property int index

                        // Description + name feed the icon/type keyword scans.
                        readonly property string deviceLabel: sourceRow.modelData.description + " " + sourceRow.modelData.name
                        readonly property string typeToken: "quickSettings.inputType." + StatusIcons.audioSourceType(sourceRow.deviceLabel)

                        order: page.inputOrder + 1 + index
                        text: sourceRow.modelData.description.length > 0 ? sourceRow.modelData.description : sourceRow.modelData.name
                        subText: I18n.t(sourceRow.typeToken)
                        current: Audio.source !== null && sourceRow.modelData.id === Audio.source.id
                        leadingIcon: StatusIcons.audioSourceIcon(sourceRow.deviceLabel)

                        onClicked: Audio.setPreferredSource(sourceRow.modelData)
                    }
                }
            }

            // --- Per-app volume mixer -----------------------------------------
            Column {
                width: parent.width
                spacing: 5
                visible: Audio.playbackStreams.length > 0

                SectionLabel {
                    order: page.appsOrder
                    text: I18n.t("quickSettings.soundApps")
                }

                Repeater {
                    model: Audio.playbackStreams

                    MixerRow {
                        required property var modelData
                        required property int index

                        node: modelData
                        order: page.appsOrder + 1 + index
                    }
                }
            }
        }
    }
}
