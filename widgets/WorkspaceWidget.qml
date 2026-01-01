
import QtQuick
import qs.services

Text {
    text: `${NiriService.focusedWorkspace.id}/${NiriService.focusedWindow?.title ?? "None"}`
}
