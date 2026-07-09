import QtQuick
import qs.Services.Niri

// Tools row (prototype #rowTools): one-shot utility chips packed edge to edge.
// Colour picker and screenshot are wired; screen recording, clipboard history
// and on-screen keyboard are placeholders (dimmed "coming soon" chips) until
// their backends land in later tasks. Chips fold the row away
// (`collapseRequested`); tools that hand off to another surface also close the
// whole panel (`closeRequested`).
Row {
    id: root

    signal collapseRequested
    signal closeRequested

    // Chip count is fixed here (keep in sync with the chips below); the row
    // width is split evenly across them.
    readonly property int chipCount: 5
    readonly property real chipWidth: (width - (chipCount - 1) * spacing) / chipCount

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

    // --- placeholder tools (backends land in later tasks) -------------------
    ToolChip {
        width: root.chipWidth
        icon.name: "screen_record"
        alt: false
        tooltipKey: "quickSettings.tool.screenRecord"
        comingSoon: true
    }

    ToolChip {
        width: root.chipWidth
        icon.name: "content_paste"
        alt: true
        tooltipKey: "quickSettings.tool.clipboard"
        comingSoon: true
    }

    ToolChip {
        width: root.chipWidth
        icon.name: "keyboard"
        alt: false
        tooltipKey: "quickSettings.tool.keyboard"
        comingSoon: true
    }
}
