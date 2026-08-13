import QtQml

// Test stand-in for Quickshell.Services.Pam.PamContext under plain qml6:
// enough surface for Services/Lock.qml to load and for a flow test to walk
// the auth phases by hand. start() pretends the conversation began and then
// stays quiet — the test drives Lock.beginUnlock()/failed() directly, the
// way the real onCompleted handler would.
QtObject {
    property string config: ""
    property string configDirectory: ""
    property string user: ""
    property bool active: false
    property bool responseRequired: false
    property string message: ""

    signal completed(var result)
    signal error(var err)

    function start() {
        active = true;
        return true;
    }

    function abort() {
        active = false;
    }

    function respond(text) {
    }
}
