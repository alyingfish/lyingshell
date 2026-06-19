import Quickshell

ShellRoot {
    id: root

    Variants {
        model: Quickshell.screens

        WorkspacesIpcHarness {
            required property var modelData

            screen: modelData
        }
    }
}
