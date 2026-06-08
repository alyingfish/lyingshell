import QtQuick
import Qcm.Material as MD
import qs.Commons.I18n
import qs.Services

Row {
    id: root

    readonly property string weekdayText: I18n.t("bar.weekdays." + Time.weekday)
    readonly property string dateText: Time.format(I18n.t("bar.dateFormat"))
    readonly property string timeText: Time.format(I18n.t("bar.timeFormat"))
    readonly property string temperatureText: I18n.t("bar.temperatureCelsius", {
        "temperature": Weather.temperatureCelsius
    })

    spacing: 8

    MD.Text {
        id: dateLabel

        anchors.baseline: timeLabel.baseline
        text: root.weekdayText + " " + root.dateText
        color: MD.Token.color.on_surface_variant
        typescale: MD.Token.typescale.title_small
        verticalAlignment: Text.AlignVCenter
    }

    MD.Text {
        id: timeLabel

        anchors.verticalCenter: parent.verticalCenter
        text: root.timeText
        color: MD.Token.color.on_surface
        typescale: MD.Token.typescale.label_large
        prominent: true
        verticalAlignment: Text.AlignVCenter
    }

    MD.Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: Weather.conditionIconName
        size: 18
        color: MD.Token.color.primary
    }

    MD.Text {
        anchors.baseline: timeLabel.baseline
        text: root.temperatureText
        color: MD.Token.color.on_surface_variant
        typescale: MD.Token.typescale.title_small
        verticalAlignment: Text.AlignVCenter
    }
}
