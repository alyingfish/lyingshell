import QtQuick
import Qcm.Material as MD
import qs.Commons.I18n
import qs.Commons.Theme
import qs.Services

Row {
    id: root

    readonly property string weekdayText: I18n.t("bar.weekdays." + Time.weekday)
    readonly property string dateText: Time.format(I18n.t("bar.dateFormat"))
    readonly property string timeText: Time.format(I18n.t("bar.timeFormat"))
    readonly property string temperatureText: I18n.t("bar.temperatureCelsius", {
        "temperature": Weather.temperatureCelsius
    })

    spacing: 12

    MD.Text {
        id: dateLabel

        anchors.baseline: timeLabel.baseline
        text: root.weekdayText + " " + root.dateText
        color: MD.Token.color.on_surface_variant
        typescale: MD.Token.typescale.label_large
        font.family: Theme.textTypeface
        verticalAlignment: Text.AlignVCenter
    }

    MD.Text {
        id: timeLabel

        anchors.verticalCenter: parent.verticalCenter
        text: root.timeText
        color: MD.Token.color.on_surface
        typescale: MD.Token.typescale.label_large
        prominent: true
        font.family: Theme.textTypeface
        verticalAlignment: Text.AlignVCenter
    }

    MD.IconLabel {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        text: root.temperatureText
        color: MD.Token.color.on_surface_variant
        icon.name: Weather.conditionIconName
        icon.size: 16
        icon.color: MD.Token.color.tertiary
        label.typescale: MD.Token.typescale.label_large
        label.font.family: Theme.textTypeface
        label.useTypescale: true
    }
}
