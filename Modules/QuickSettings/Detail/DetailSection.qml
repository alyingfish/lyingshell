import QtQuick
import Qcm.Material as MD
import qs.Commons.Theme

// Detail-list section label (prototype .dv-sec): a small emphasized
// on-surface-variant caption, indented 8px, joining the rows' entrance
// stagger; `scanning` adds the mini activity indicator (the Wi-Fi scan /
// Bluetooth discovery cue).
Item {
    id: section

    property alias text: sectionText.text
    property int order: 0
    property bool scanning: false

    width: parent ? parent.width : 0
    implicitHeight: sectionText.implicitHeight + 3

    Row {
        x: 8
        y: 3
        width: parent.width - 8
        spacing: 8

        MD.Text {
            id: sectionText

            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, parent.width - (spinner.running ? spinner.width + parent.spacing : 0))
            color: MD.Token.color.on_surface_variant
            typescale: MD.Token.typescale.label_medium
            prominent: true
            font.family: Theme.textTypeface
            elide: Text.ElideRight
            maximumLineCount: 1
            wrapMode: Text.NoWrap
        }

        MD.BusyIndicator {
            id: spinner

            anchors.verticalCenter: parent.verticalCenter
            // running only; the control writes its own `visible`
            // (see DetailRow's spinner note).
            running: section.scanning
            // Prototype .ldi.mini is 12px; the control sizes the morphing
            // shape off indicatorSize, not the item box.
            indicatorSize: 12
            implicitWidth: 12
            implicitHeight: 12
        }
    }

    transform: Translate {
        id: sectionTy
    }

    Component.onCompleted: sectionIn.restart()

    DetailRise {
        id: sectionIn

        target: section
        translate: sectionTy
        order: section.order
    }
}
