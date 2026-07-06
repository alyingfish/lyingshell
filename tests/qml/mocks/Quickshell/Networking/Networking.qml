pragma Singleton

import QtQml

// Test stand-in for Quickshell.Networking with the web-prototype's demo
// network list, so visual dumps mirror the reference screenshots.
QtObject {
    id: root

    property bool wifiEnabled: true

    component MockNetwork: QtObject {
        property string name
        property bool connected: false
        property bool known: false
        property int security: 1
        property real signalStrength: 0.5
        property bool stateChanging: false

        function connect() {
            root.wifiNets.forEach(n => n.connected = false);
            connected = true;
        }
        function disconnect() {
            connected = false;
        }
        function connectWithPsk(psk) {
            connect();
        }
    }

    readonly property list<QtObject> wifiNets: [
        MockNetwork { name: "Homelab-5G"; connected: true; known: true; signalStrength: 0.9 },
        MockNetwork { name: "Homelab"; known: true; signalStrength: 0.85 },
        MockNetwork { name: "Café Aurora Guest"; security: 0; signalStrength: 0.6 },
        MockNetwork { name: "FRITZ!Box 7590"; signalStrength: 0.2 },
        MockNetwork { name: "eduroam"; signalStrength: 0.5 },
        MockNetwork { name: "Pixel_9Pro_Hotspot"; signalStrength: 0.82 },
        MockNetwork { name: "TP-Link_Guest"; security: 0; signalStrength: 0.45 },
        MockNetwork { name: "Starlink-2A4F"; signalStrength: 0.18 },
        MockNetwork { name: "AndroidAP_5271"; signalStrength: 0.4 },
        MockNetwork { name: "Xfinity WiFi"; security: 0; signalStrength: 0.1 }
    ]

    readonly property QtObject wifiDevice: QtObject {
        readonly property int type: 1
        readonly property bool connected: true
        property bool scannerEnabled: false
        readonly property QtObject networks: QtObject {
            readonly property var values: root.wifiNets
        }
    }

    readonly property QtObject wiredDevice: QtObject {
        readonly property int type: 2
        readonly property bool connected: true
        readonly property QtObject networks: QtObject {
            readonly property var values: []
        }

        function disconnect() {
        }
    }

    readonly property QtObject devices: QtObject {
        readonly property var values: [root.wifiDevice, root.wiredDevice]
    }
}
