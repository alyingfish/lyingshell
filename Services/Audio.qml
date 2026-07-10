pragma Singleton

import QtQml
import Quickshell
import Quickshell.Services.Pipewire

// Audio service boundary over Quickshell Pipewire: default sink/source
// volume + mute, output/input device switching, per-app playback streams,
// and privacy signals (recording streams / camera links) for the
// quick-settings pill and panel.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property bool hasSink: sink !== null && sink.audio !== null
    readonly property bool hasSource: source !== null && source.audio !== null

    readonly property real volume: hasSink ? sink.audio.volume : 0
    readonly property bool muted: hasSink ? sink.audio.muted : false
    readonly property real inputVolume: hasSource ? source.audio.volume : 0
    readonly property bool inputMuted: hasSource ? source.audio.muted : false

    // Physical output devices for the sound detail's Output list.
    readonly property var sinkDevices: Pipewire.nodes.values.filter(node => node !== null && node.isSink && !node.isStream && node.audio !== null)

    // Physical input (microphone) devices for the sound detail's Input list.
    readonly property var sourceDevices: Pipewire.nodes.values.filter(node => node !== null && !node.isSink && !node.isStream && node.audio !== null)

    // Apps currently playing audio, for the sound detail's per-app mixer.
    readonly property var playbackStreams: Pipewire.nodes.values.filter(node => node !== null && (node.type & PwNodeType.AudioOutStream) === PwNodeType.AudioOutStream && node.audio !== null)

    // Apps currently recording audio; GNOME shows the input slider and the
    // mic privacy indicator exactly while such streams exist.
    readonly property var recordingStreams: Pipewire.nodes.values.filter(node => node !== null && (node.type & PwNodeType.AudioInStream) === PwNodeType.AudioInStream)
    readonly property bool microphoneInUse: recordingStreams.length > 0

    // Camera privacy indicator: any pipewire link pulling from a Video/Source
    // node means some app is consuming a camera.
    readonly property bool cameraInUse: Pipewire.links.values.some(link => link !== null && link.source !== null && (link.source.type & PwNodeType.VideoSource) === PwNodeType.VideoSource)

    function setVolume(value: real) {
        if (!hasSink) {
            return;
        }
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1, value));
    }

    function toggleMuted() {
        if (hasSink) {
            sink.audio.muted = !sink.audio.muted;
        }
    }

    function setInputVolume(value: real) {
        if (!hasSource) {
            return;
        }
        source.audio.muted = false;
        source.audio.volume = Math.max(0, Math.min(1, value));
    }

    function toggleInputMuted() {
        if (hasSource) {
            source.audio.muted = !source.audio.muted;
        }
    }

    function setPreferredSink(node: PwNode) {
        Pipewire.preferredDefaultAudioSink = node;
    }

    function setPreferredSource(node: PwNode) {
        Pipewire.preferredDefaultAudioSource = node;
    }

    function setStreamVolume(node: PwNode, value: real) {
        if (node === null || node.audio === null) {
            return;
        }
        node.audio.muted = false;
        node.audio.volume = Math.max(0, Math.min(1, value));
    }

    function toggleStreamMuted(node: PwNode) {
        if (node !== null && node.audio !== null) {
            node.audio.muted = !node.audio.muted;
        }
    }

    // Node audio properties are only live while tracked.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    PwObjectTracker {
        objects: root.sinkDevices
    }

    PwObjectTracker {
        objects: root.sourceDevices
    }

    PwObjectTracker {
        objects: root.playbackStreams
    }
}
