pragma Singleton

import QtQml

// Web-prototype audio demo: volume 65, four output devices, two input
// devices, three app playback streams. Nodes are plain JS objects because
// Pipewire nodes expose an `id` field, which QML reserves in object
// declarations; stream/source arrays are reassigned after a mutation so
// bindings on their contents refresh.
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

    readonly property var sourceDevices: [
        {
            "id": 11,
            "name": "alsa_input.analog-stereo",
            "description": "Internal Microphone"
        },
        {
            "id": 12,
            "name": "bluez_input.pixel_buds",
            "description": "Pixel Buds Pro"
        }
    ]
    property var source: sourceDevices[0]

    property var playbackStreams: [
        {
            "id": 21,
            "name": "spotify",
            "description": "Music",
            "properties": {
                "application.name": "Music"
            },
            "audio": {
                "volume": 0.8,
                "muted": false
            }
        },
        {
            "id": 22,
            "name": "firefox",
            "description": "Lo-fi radio",
            "properties": {
                "application.name": "Firefox"
            },
            "audio": {
                "volume": 0.65,
                "muted": false
            }
        },
        {
            "id": 23,
            "name": "discord",
            "description": "Discord",
            "properties": {
                "application.name": "Discord"
            },
            "audio": {
                "volume": 0.45,
                "muted": true
            }
        }
    ]

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
    function setPreferredSource(device) {
        source = device;
    }
    function setStreamVolume(node, v) {
        node.audio.muted = false;
        node.audio.volume = Math.max(0, Math.min(1, v));
        playbackStreams = playbackStreams.slice();
    }
    function toggleStreamMuted(node) {
        node.audio.muted = !node.audio.muted;
        playbackStreams = playbackStreams.slice();
    }
}
