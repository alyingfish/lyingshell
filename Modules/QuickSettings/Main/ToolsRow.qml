import QtQuick
import qs.Services.Niri

// Tools row (prototype #rowTools): one-shot utility chips packed edge to edge.
// Colour picker and screenshot are wired; screen recording, clipboard history
// and on-screen keyboard are placeholders (dimmed "coming soon" chips) until
// their backends land in later tasks. Chips never fold the row away — tools
// that hand off to another surface close the whole panel instead
// (`closeRequested`, or `pickRequested` when the panel must reopen on the
// result), and the row keeps its toggle state for the next open.
Row {
    id: root

    // Colour pick handoff: the panel closes for the aim (the target pixel may
    // sit behind the card) and reopens on the readout page when niri replies.
    signal pickRequested
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

    // Colour picker: niri's interactive pick, owned by QuickSettingsPanel
    // (beginColorPick) so the close-for-the-aim and the reopen onto the
    // readout page live in one place.
    ToolChip {
        width: root.chipWidth
        icon.name: "colorize"
        alt: false
        tooltipKey: "quickSettings.tool.colorPicker"

        onClicked: root.pickRequested()
    }

    ToolChip {
        width: root.chipWidth
        icon.name: "screenshot_monitor"
        alt: true
        tooltipKey: "quickSettings.tool.screenshot"

        onClicked: {
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
