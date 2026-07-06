import QtQuick
import qs.Commons.I18n
import qs.Services

// Keyboard-backlight levels: off / half / max mirror the old menu levels.
Column {
    id: page

    property real viewportHeight: 0

    spacing: 5

    Repeater {
        model: [
            {
                "level": 0,
                "token": "quickSettings.kbdBacklight.off",
                "icon": "backlight_high_off"
            },
            {
                "level": Math.max(1, Math.ceil(Brightness.kbdMax / 2)),
                "token": "quickSettings.kbdBacklight.low",
                "icon": "backlight_low"
            },
            {
                "level": Brightness.kbdMax,
                "token": "quickSettings.kbdBacklight.high",
                "icon": "backlight_high"
            }
        ]

        DetailRow {
            id: kbdRow

            required property var modelData
            required property int index

            order: index
            text: I18n.t(kbdRow.modelData.token)
            current: Brightness.kbdLevel === kbdRow.modelData.level
            leadingIcon: kbdRow.modelData.icon

            onClicked: Brightness.setKbdLevel(kbdRow.modelData.level)
        }
    }
}
