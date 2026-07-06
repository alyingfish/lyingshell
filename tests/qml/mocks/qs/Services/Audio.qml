pragma Singleton

import QtQml

// Web-prototype audio demo: volume 65, four output devices. Sinks are plain
// JS objects because Pipewire nodes expose an `id` field, which QML reserves
// in object declarations.
QtObject {
    id: root

    property real volume: 0.65
    property bool muted: false
    property real inputVolume: 0.5
    property bool inputMuted: false
    readonly property bool hasSink: true
    readonly property bool hasSource: true
    property bool microphoneInUse: false
    property bool cameraInUse: false

    readonly property var sinkDevices: [
        {
            "id": 1,
            "name": "alsa_output.analog-stereo",
            "description": "Built-in Speakers"
        },
        {
            "id": 2,
            "name": "alsa_output.hdmi-stereo",
            "description": "DELL U2723QE"
        },
        {
            "id": 3,
            "name": "bluez_output.pixel_buds",
            "description": "Pixel Buds Pro"
        },
        {
            "id": 4,
            "name": "alsa_output.iec958-stereo",
            "description": "HDA Digital Out"
        }
    ]
    property var sink: sinkDevices[0]

    function setVolume(v) {
        volume = v;
    }
    function toggleMuted() {
        muted = !muted;
    }
    function setInputVolume(v) {
        inputVolume = v;
    }
    function toggleInputMuted() {
        inputMuted = !inputMuted;
    }
    function setPreferredSink(device) {
        sink = device;
    }
}
