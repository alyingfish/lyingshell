pragma Singleton

import QtQml

// Test stand-in for Services/HiddenNetwork.qml: records the last join.
QtObject {
    property bool busy: false
    property string pendingSsid: ""
    property string lastSsid: ""
    property string lastPsk: ""

    signal succeeded(string ssid)
    signal failed(string ssid)

    function join(ssid, psk) {
        lastSsid = ssid;
        lastPsk = psk;
    }
}
