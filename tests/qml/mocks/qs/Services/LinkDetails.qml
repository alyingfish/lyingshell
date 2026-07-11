pragma Singleton

import QtQml

// Test stand-in for Services/LinkDetails.qml with the web-prototype's demo
// link values.
QtObject {
    property string ipAddress: "192.168.1.85"
    property string band: "5 GHz"
    property string linkRate: "866 Mbps"

    function refresh(ifname) {
    }
}
