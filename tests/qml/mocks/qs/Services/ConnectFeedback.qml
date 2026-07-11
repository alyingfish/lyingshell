pragma Singleton

import QtQml

// Test stand-in for Services/ConnectFeedback.qml: records the watched
// targets; tests emit the failure signals directly.
QtObject {
    property string visibleDetail: ""
    property var wifiPending: null
    property var btPending: null

    signal wifiFailed(var network, int reason)
    signal btFailed(var device)

    function watchWifi(network) {
        wifiPending = network;
    }

    function watchBt(device) {
        btPending = device;
    }
}
