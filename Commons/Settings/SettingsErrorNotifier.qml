import Quickshell.Io

Process {
    id: root

    property string notificationTitle: "Lying Shell settings error"

    function notify(message) {
        if (root.running) {
            root.running = false;
        }

        root.command = ["notify-send", notificationTitle, message];
        root.running = true;
    }

    command: ["notify-send", root.notificationTitle, ""]
}
