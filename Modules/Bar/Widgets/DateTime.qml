import QtQuick
import Qcm.Material as MD
import qs.Commons.I18n
import qs.Services

Item {
    id: root

    readonly property string weekdayText: I18n.t("bar.weekdays." + Time.weekday)
    readonly property string dateText: Time.format(I18n.t("bar.dateFormat"))
    readonly property string timeText: Time.format(I18n.t("bar.timeFormat"))
    readonly property string temperatureText: I18n.t("bar.temperatureCelsius", {
        "temperature": Weather.temperatureCelsius
    })
    readonly property real sideSpacing: 8
    readonly property real sideExtent: Math.max(dateLabel.implicitWidth, weatherLabel.implicitWidth) + sideSpacing

    implicitWidth: timeLabel.implicitWidth + sideExtent * 2
    implicitHeight: Math.max(dateLabel.implicitHeight, timeLabel.implicitHeight, weatherLabel.implicitHeight)

    MD.Text {
        id: dateLabel

        anchors.right: timeLabel.left
        anchors.rightMargin: root.sideSpacing
        anchors.verticalCenter: parent.verticalCenter
        text: root.weekdayText + " " + root.dateText
        color: MD.Token.color.on_surface_variant
        typescale: MD.Token.typescale.label_large
        verticalAlignment: Text.AlignVCenter
    }

    MD.Text {
        id: timeLabel

        anchors.centerIn: parent
        text: root.timeText
        color: MD.Token.color.on_surface
        typescale: MD.Token.typescale.label_large
        prominent: true
        verticalAlignment: Text.AlignVCenter
    }

    MD.IconLabel {
        id: weatherLabel

        anchors.left: timeLabel.right
        anchors.leftMargin: root.sideSpacing
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        text: root.temperatureText
        color: MD.Token.color.on_surface_variant
        icon.name: Weather.conditionIconName
        icon.size: 18
        icon.color: MD.Token.color.primary
        label.typescale: MD.Token.typescale.label_large
        label.useTypescale: true
    }
}
