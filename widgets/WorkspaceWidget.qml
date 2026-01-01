import QtQuick
import qs.services

Text {
    text: `${NiriService.focusedWorkspace.idx}/${NiriService.focusedWindow?.title ?? "None"}`
}
