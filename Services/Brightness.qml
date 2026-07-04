pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io

// Screen backlight + keyboard backlight over brightnessctl. Documented
// Quickshell API gap: there is no backlight service module and niri exposes
// no brightness IPC, so this is a command-execution boundary, not polling —
// state refreshes on demand (panel open) and after each write.
// ponytail: internal backlight only; add ddcutil external-monitor support if
// a desktop monitor ever needs it.
Singleton {
    id: root

    property bool available: false
    property real percent: 0
    property string _device: ""
    property real _max: 1

    property bool kbdAvailable: false
    property int kbdLevel: 0
    property int kbdMax: 1
    property string _kbdDevice: ""

    property real _pendingPercent: -1
    property int _pendingKbdLevel: -1

    function refresh() {
        if (!listProcess.running) {
            listProcess.running = true;
        }
    }

    function setPercent(value: real) {
        if (!available) {
            return;
        }
        percent = Math.max(0, Math.min(1, value));
        _pendingPercent = percent;
        applyTimer.restart();
    }

    function setKbdLevel(level: int) {
        if (!kbdAvailable) {
            return;
        }
        kbdLevel = Math.max(0, Math.min(kbdMax, level));
        _pendingKbdLevel = kbdLevel;
        applyTimer.restart();
    }

    function toggleKbd() {
        setKbdLevel(kbdLevel > 0 ? 0 : kbdMax);
    }

    function _parseDeviceLine(line) {
        // brightnessctl -m: device,class,current,percent%,max
        const parts = line.split(",");
        if (parts.length < 5) {
            return;
        }
        const deviceClass = parts[1];
        const current = Number(parts[2]);
        const max = Number(parts[4]);
        if (!Number.isFinite(current) || !Number.isFinite(max) || max <= 0) {
            return;
        }
        if (deviceClass === "backlight") {
            _device = parts[0];
            _max = max;
            percent = current / max;
            available = true;
        } else if (deviceClass === "leds" && parts[0].indexOf("kbd_backlight") >= 0) {
            _kbdDevice = parts[0];
            kbdMax = max;
            kbdLevel = current;
            kbdAvailable = true;
        }
    }

    Component.onCompleted: refresh()

    Timer {
        id: applyTimer

        // Coalesce slider drags into one write per tick.
        interval: 60
        repeat: false

        onTriggered: {
            if (setProcess.running) {
                applyTimer.restart();
                return;
            }
            if (root._pendingPercent >= 0 && root._device.length > 0) {
                setProcess.command = ["brightnessctl", "-m", "-d", root._device, "s", String(Math.round(root._pendingPercent * root._max))];
                root._pendingPercent = -1;
                setProcess.running = true;
            } else if (root._pendingKbdLevel >= 0 && root._kbdDevice.length > 0) {
                setProcess.command = ["brightnessctl", "-m", "-d", root._kbdDevice, "s", String(root._pendingKbdLevel)];
                root._pendingKbdLevel = -1;
                setProcess.running = true;
            }
        }
    }

    Process {
        id: listProcess

        command: ["brightnessctl", "-m", "-l"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    if (lines[i].length > 0) {
                        root._parseDeviceLine(lines[i]);
                    }
                }
            }
        }
    }

    Process {
        id: setProcess

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    root._parseDeviceLine(text.trim());
                }
            }
        }

        onExited: {
            // Apply any write queued while this one ran.
            if (root._pendingPercent >= 0 || root._pendingKbdLevel >= 0) {
                applyTimer.restart();
            }
        }
    }
}
