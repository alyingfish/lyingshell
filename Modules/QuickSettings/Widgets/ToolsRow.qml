import QtQuick
import qs.Services
import qs.Services.Niri

// Tools row (prototype #rowTools): color picker, screenshot, calculator.
// Chips fold the row away (`collapseRequested`); tools that hand off to
// another surface also close the whole panel (`closeRequested`).
Row {
    id: root

    signal collapseRequested
    signal closeRequested

    readonly property real chipWidth: (width - 2 * spacing) / 3

    height: 40
    spacing: 8

    // Delays niri's screenshot UI until the panel's close animation cleared
    // the frame it freezes.
    Timer {
        id: screenshotDelay

        interval: 300

        onTriggered: Niri.takeScreenshot()
    }

    // Colour picker: niri's interactive pick. The result opens the colour
    // readout page (wired in QuickSettingsPanel) instead of a dead-end swatch.
    ToolChip {
        width: root.chipWidth
        icon.name: "colorize"
        alt: false
        tooltipKey: "quickSettings.tool.colorPicker"

        onClicked: {
            root.collapseRequested();
            Niri.pickColor();
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
