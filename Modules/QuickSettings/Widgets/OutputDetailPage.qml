import QtQuick
import qs.Commons.I18n
import qs.Services
import "../../../Commons/Icons/StatusIcons.js" as StatusIcons

// Sound-output detail page: the body lists the Pipewire sinks.
DetailPage {
    id: root

    detailName: "output"
    title: I18n.t("quickSettings.outputDevice")

    bodyContent: Component {
        Column {
            id: page

            property real viewportHeight: 0

            spacing: 5

            Repeater {
                model: Audio.sinkDevices

                DetailRow {
                    id: sinkRow

                    required property var modelData
                    required property int index

                    order: index
                    text: sinkRow.modelData.description.length > 0 ? sinkRow.modelData.description : sinkRow.modelData.name
                    current: Audio.sink !== null && sinkRow.modelData.id === Audio.sink.id
                    leadingIcon: StatusIcons.audioSinkIcon(sinkRow.modelData.description + " " + sinkRow.modelData.name)

                    onClicked: Audio.setPreferredSink(sinkRow.modelData)
                }
            }
        }
    }
}
