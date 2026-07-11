pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io

// Link properties for the connected network's card (web-prototype wifiProps:
// Band / IP address / Link speed). Documented gap: Quickshell.Networking
// exposes no IP address, frequency, or bitrate, so these come from iproute2
// (`ip -j`) and the NetworkManager CLI, refreshed on demand when the
// connected row expands.
Singleton {
    id: root

    property string ipAddress: ""
    property string band: ""
    property string linkRate: ""

    function refresh(ifname: string) {
        if (ifname.length === 0) {
            return;
        }
        ipAddress = "";
        band = "";
        linkRate = "";
        ipProcess.command = ["ip", "-j", "addr", "show", "dev", ifname];
        ipProcess.running = true;
        // --rescan no: read the cache — a forced scan here would churn the
        // AP list the page is currently showing.
        wifiProcess.command = ["nmcli", "-t", "-f", "ACTIVE,FREQ,RATE", "device", "wifi", "list", "--rescan", "no", "ifname", ifname];
        wifiProcess.running = true;
    }

    Process {
        id: ipProcess

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const devices = JSON.parse(text);
                    const info = devices.length > 0 ? devices[0].addr_info || [] : [];
                    const v4 = info.find(a => a.family === "inet");
                    root.ipAddress = v4 ? v4.local : (info.length > 0 ? info[0].local : "");
                } catch (error) {
                    root.ipAddress = "";
                }
            }
        }
    }

    Process {
        id: wifiProcess

        stdout: StdioCollector {
            onStreamFinished: {
                // "yes:5240 MHz:866 Mbit/s" for the AP in use.
                const active = text.split("\n").find(line => line.startsWith("yes:"));
                if (!active) {
                    return;
                }
                const fields = active.split(":");
                const mhz = parseInt(fields[1]);
                root.band = mhz >= 5925 ? "6 GHz" : mhz >= 4900 ? "5 GHz" : mhz > 0 ? "2.4 GHz" : "";
                const rate = parseInt(fields[2]);
                root.linkRate = rate > 0 ? rate + " Mbps" : "";
            }
        }
    }
}
