import QtQuick
import Quickshell
import Qcm.Material as MD
import qs.Services
import qs.Services.Niri

// Tools row (prototype #rowTools): color picker, screenshot, calculator.
// Chips fold the row away (`collapseRequested`); tools that hand off to
// another surface also close the whole panel (`closeRequested`).
Row {
    id: root

    signal collapseRequested
    signal closeRequested

    // Last color-picker result, shown as a swatch on the picker chip.
    property color pickedColor: "transparent"
    property bool hasPickedColor: false

    readonly property real chipWidth: (width - 2 * spacing) / 3

    height: 40
    spacing: 8

    Connections {
        target: Niri

        function onColorPicked(hex) {
            root.pickedColor = hex;
            root.hasPickedColor = true;
            // The picked color lands on the clipboard, GNOME-picker style.
            Quickshell.clipboardText = hex;
        }
    }

    // Delays niri's screenshot UI until the panel's close animation cleared
    // the frame it freezes.
    Timer {
        id: screenshotDelay

        interval: 300

        onTriggered: Session.takeScreenshot()
    }

    ToolChip {
        width: root.chipWidth
        icon.name: "colorize"
        alt: false
        tooltipKey: "quickSettings.tool.colorPicker"

        onClicked: {
            root.collapseRequested();
            Session.pickColor();
        }

        // Picked-color swatch (prototype .cdot).
        Rectangle {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 6
            width: 11
            height: 11
            radius: 5.5
            visible: root.hasPickedColor
            color: root.pickedColor
            border.width: 2
            border.color: MD.Token.color.surface_container_low
        }
    }

    ToolChip {
        width: root.chipWidth
        icon.name: "screenshot_monitor"
        alt: true
        tooltipKey: "quickSettings.tool.screenshot"

        onClicked: {
            root.collapseRequested();
            root.closeRequested();
            screenshotDelay.restart();
        }
    }

    ToolChip {
        width: root.chipWidth
        icon.name: "calculate"
        alt: false
        tooltipKey: "quickSettings.tool.calculator"

        onClicked: {
            root.collapseRequested();
            root.closeRequested();
            Session.openCalculator();
        }
    }
}
