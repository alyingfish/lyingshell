import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons.Settings
import qs.Services.Wallpaper

// Per-output wallpaper surface on the background layer, with the six ported
// GPU transition shaders. Trimmed from Noctalia: no resize cache, no compositor
// scale tracking, no solid-color mode (shaders still receive the isSolid/solid
// uniforms, pinned off, so the .qsb files are reused unmodified).
Variants {
    id: backgroundVariants
    model: Quickshell.screens

    delegate: Loader {
        required property ShellScreen modelData

        active: modelData && Settings.options.wallpaper.enabled

        sourceComponent: PanelWindow {
            id: root

            property string transitionType: "fade"
            property real transitionProgress: 0
            property bool isStartupTransition: true
            property bool wallpaperReady: false

            visible: wallpaperReady

            readonly property real edgeSmoothness: Settings.options.wallpaper.transitionEdgeSmoothness
            readonly property var allTransitions: Wallpaper.allTransitions
            readonly property bool transitioning: transitionAnimation.running

            // Wipe direction: 0=left, 1=right, 2=up, 3=down
            property real wipeDirection: 0
            // Disc
            property real discCenterX: 0.5
            property real discCenterY: 0.5
            // Stripe
            property real stripesCount: 16
            property real stripesAngle: 0
            // Pixelate
            property real pixelateMaxBlockSize: 64.0
            // Honeycomb
            property real honeycombCellSize: 0.04
            property real honeycombCenterX: 0.5
            property real honeycombCenterY: 0.5

            // Debounced future wallpaper + the path we're transitioning toward.
            property string futureWallpaper: ""
            property string transitioningToOriginalPath: ""

            property real fillMode: Wallpaper.getFillModeUniform()
            property color _fillColor: Qt.color(Settings.options.wallpaper.fillColor)
            property vector4d fillColor: Qt.vector4d(_fillColor.r, _fillColor.g, _fillColor.b, 1.0)

            // Solid-color mode is cut; keep the uniforms pinned off for the shaders.
            readonly property real isSolid1: 0.0
            readonly property real isSolid2: 0.0
            readonly property vector4d solidColor1: Qt.vector4d(0, 0, 0, 1)
            readonly property vector4d solidColor2: Qt.vector4d(0, 0, 0, 1)

            Component.onCompleted: setWallpaperInitial()

            Component.onDestruction: {
                transitionAnimation.stop();
                startupTransitionTimer.stop();
                debounceTimer.stop();
                shaderLoader.active = false;
                currentWallpaper.source = "";
                nextWallpaper.source = "";
            }

            Connections {
                target: Settings.options.wallpaper
                function onFillModeChanged() {
                    root.fillMode = Wallpaper.getFillModeUniform();
                }
            }

            Connections {
                target: Wallpaper
                function onWallpaperChanged(screenName, path) {
                    if (screenName === modelData.name) {
                        root.requestPreprocessedWallpaper(path);
                    }
                }
            }

            color: "transparent"
            screen: modelData
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "lyingshell-wallpaper-" + (screen?.name || "unknown")

            anchors {
                bottom: true
                top: true
                right: true
                left: true
            }

            Timer {
                id: debounceTimer
                interval: 333
                running: false
                repeat: false
                onTriggered: changeWallpaper()
            }

            // Delay startup transition until the compositor has mapped the window.
            Timer {
                id: startupTransitionTimer
                interval: 100
                running: false
                repeat: false
                onTriggered: _executeStartupTransition()
            }

            Image {
                id: currentWallpaper
                source: ""
                smooth: true
                mipmap: false
                visible: false
                cache: true // Cached so Overview can share the same texture
                asynchronous: true
                onStatusChanged: {
                    if (status === Image.Error) {
                        console.warn("[Background] current wallpaper failed:", source);
                    } else if (status === Image.Ready && !wallpaperReady) {
                        wallpaperReady = true;
                    }
                }
            }

            Image {
                id: nextWallpaper
                property bool pendingTransition: false
                source: ""
                smooth: true
                mipmap: false
                visible: false
                cache: false
                asynchronous: true
                onStatusChanged: {
                    if (status === Image.Error) {
                        console.warn("[Background] next wallpaper failed:", source);
                        pendingTransition = false;
                    } else if (status === Image.Ready) {
                        if (!wallpaperReady) {
                            wallpaperReady = true;
                        }
                        if (pendingTransition) {
                            pendingTransition = false;
                            currentWallpaper.asynchronous = false;
                            transitionAnimation.start();
                        }
                    }
                }
            }

            // Only the active transition's shader is loaded.
            Loader {
                id: shaderLoader
                anchors.fill: parent
                active: true
                sourceComponent: {
                    switch (transitionType) {
                    case "wipe":
                        return wipeShaderComponent;
                    case "disc":
                        return discShaderComponent;
                    case "stripes":
                        return stripesShaderComponent;
                    case "pixelate":
                        return pixelateShaderComponent;
                    case "honeycomb":
                        return honeycombShaderComponent;
                    case "fade":
                    case "none":
                    default:
                        return fadeShaderComponent;
                    }
                }
            }

            Component {
                id: fadeShaderComponent
                ShaderEffect {
                    anchors.fill: parent
                    property variant source1: currentWallpaper
                    property variant source2: nextWallpaper.status === Image.Ready ? nextWallpaper : currentWallpaper.status === Image.Ready ? nextWallpaper : currentWallpaper
                    property real progress: root.transitionProgress
                    property real fillMode: root.fillMode
                    property vector4d fillColor: root.fillColor
                    property real imageWidth1: source1.sourceSize.width
                    property real imageHeight1: source1.sourceSize.height
                    property real imageWidth2: source2.sourceSize.width
                    property real imageHeight2: source2.sourceSize.height
                    property real screenWidth: width
                    property real screenHeight: height
                    property real isSolid1: root.isSolid1
                    property real isSolid2: root.isSolid2
                    property vector4d solidColor1: root.solidColor1
                    property vector4d solidColor2: root.solidColor2
                    fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/wp_fade.frag.qsb")
                }
            }

            Component {
                id: wipeShaderComponent
                ShaderEffect {
                    anchors.fill: parent
                    property variant source1: currentWallpaper
                    property variant source2: nextWallpaper.status === Image.Ready ? nextWallpaper : currentWallpaper
                    property real progress: root.transitionProgress
                    property real smoothness: root.edgeSmoothness
                    property real direction: root.wipeDirection
                    property real fillMode: root.fillMode
                    property vector4d fillColor: root.fillColor
                    property real imageWidth1: source1.sourceSize.width
                    property real imageHeight1: source1.sourceSize.height
                    property real imageWidth2: source2.sourceSize.width
                    property real imageHeight2: source2.sourceSize.height
                    property real screenWidth: width
                    property real screenHeight: height
                    property real isSolid1: root.isSolid1
                    property real isSolid2: root.isSolid2
                    property vector4d solidColor1: root.solidColor1
                    property vector4d solidColor2: root.solidColor2
                    fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/wp_wipe.frag.qsb")
                }
            }

            Component {
                id: discShaderComponent
                ShaderEffect {
                    anchors.fill: parent
                    property variant source1: currentWallpaper
                    property variant source2: nextWallpaper.status === Image.Ready ? nextWallpaper : currentWallpaper
                    property real progress: root.transitionProgress
                    property real smoothness: root.edgeSmoothness
                    property real aspectRatio: root.width / root.height
                    property real centerX: root.discCenterX
                    property real centerY: root.discCenterY
                    property real fillMode: root.fillMode
                    property vector4d fillColor: root.fillColor
                    property real imageWidth1: source1.sourceSize.width
                    property real imageHeight1: source1.sourceSize.height
                    property real imageWidth2: source2.sourceSize.width
                    property real imageHeight2: source2.sourceSize.height
                    property real screenWidth: width
                    property real screenHeight: height
                    property real isSolid1: root.isSolid1
                    property real isSolid2: root.isSolid2
                    property vector4d solidColor1: root.solidColor1
                    property vector4d solidColor2: root.solidColor2
                    fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/wp_disc.frag.qsb")
                }
            }

            Component {
                id: stripesShaderComponent
                ShaderEffect {
                    anchors.fill: parent
                    property variant source1: currentWallpaper
                    property variant source2: nextWallpaper.status === Image.Ready ? nextWallpaper : currentWallpaper
                    property real progress: root.transitionProgress
                    property real smoothness: root.edgeSmoothness
                    property real aspectRatio: root.width / root.height
                    property real stripeCount: root.stripesCount
                    property real angle: root.stripesAngle
                    property real fillMode: root.fillMode
                    property vector4d fillColor: root.fillColor
                    property real imageWidth1: source1.sourceSize.width
                    property real imageHeight1: source1.sourceSize.height
                    property real imageWidth2: source2.sourceSize.width
                    property real imageHeight2: source2.sourceSize.height
                    property real screenWidth: width
                    property real screenHeight: height
                    property real isSolid1: root.isSolid1
                    property real isSolid2: root.isSolid2
                    property vector4d solidColor1: root.solidColor1
                    property vector4d solidColor2: root.solidColor2
                    fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/wp_stripes.frag.qsb")
                }
            }

            Component {
                id: pixelateShaderComponent
                ShaderEffect {
                    anchors.fill: parent
                    property variant source1: currentWallpaper
                    property variant source2: nextWallpaper.status === Image.Ready ? nextWallpaper : currentWallpaper
                    property real progress: root.transitionProgress
                    property real maxBlockSize: root.pixelateMaxBlockSize
                    property real fillMode: root.fillMode
                    property vector4d fillColor: root.fillColor
                    property real imageWidth1: source1.sourceSize.width
                    property real imageHeight1: source1.sourceSize.height
                    property real imageWidth2: source2.sourceSize.width
                    property real imageHeight2: source2.sourceSize.height
                    property real screenWidth: width
                    property real screenHeight: height
                    property real isSolid1: root.isSolid1
                    property real isSolid2: root.isSolid2
                    property vector4d solidColor1: root.solidColor1
                    property vector4d solidColor2: root.solidColor2
                    fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/wp_pixelate.frag.qsb")
                }
            }

            Component {
                id: honeycombShaderComponent
                ShaderEffect {
                    anchors.fill: parent
                    property variant source1: currentWallpaper
                    property variant source2: nextWallpaper.status === Image.Ready ? nextWallpaper : currentWallpaper
                    property real progress: root.transitionProgress
                    property real cellSize: root.honeycombCellSize
                    property real centerX: root.honeycombCenterX
                    property real centerY: root.honeycombCenterY
                    property real aspectRatio: root.width / root.height
                    property real fillMode: root.fillMode
                    property vector4d fillColor: root.fillColor
                    property real imageWidth1: source1.sourceSize.width
                    property real imageHeight1: source1.sourceSize.height
                    property real imageWidth2: source2.sourceSize.width
                    property real imageHeight2: source2.sourceSize.height
                    property real screenWidth: width
                    property real screenHeight: height
                    property real isSolid1: root.isSolid1
                    property real isSolid2: root.isSolid2
                    property vector4d solidColor1: root.solidColor1
                    property vector4d solidColor2: root.solidColor2
                    fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/wp_honeycomb.frag.qsb")
                }
            }

            NumberAnimation {
                id: transitionAnimation
                target: root
                property: "transitionProgress"
                from: 0.0
                to: 1.0
                duration: Settings.options.wallpaper.transitionDuration
                easing.type: Easing.InOutCubic
                onFinished: {
                    if (isStartupTransition) {
                        isStartupTransition = false;
                    }
                    transitioningToOriginalPath = "";

                    const tempSource = nextWallpaper.source;
                    currentWallpaper.source = tempSource;
                    transitionProgress = 0.0;

                    Qt.callLater(() => {
                        nextWallpaper.source = "";
                        Qt.callLater(() => {
                            currentWallpaper.asynchronous = true;
                        });
                    });
                }
            }

            // Normalize url/string for comparison (Image.source is a url type that
            // may carry a file:// prefix).
            function _pathStr(p) {
                var s = p.toString();
                if (s.startsWith("file://")) {
                    return s.substring(7);
                }
                return s;
            }

            // ------------------------------------------------------
            function setWallpaperInitial() {
                if (!Wallpaper.isInitialized) {
                    Qt.callLater(setWallpaperInitial);
                    return;
                }
                futureWallpaper = Wallpaper.getWallpaper(modelData.name);
                performStartupTransition();
                Wallpaper.wallpaperProcessingComplete(modelData.name, futureWallpaper, "");
            }

            // ------------------------------------------------------
            function requestPreprocessedWallpaper(originalPath) {
                if (transitioning && originalPath === transitioningToOriginalPath) {
                    return;
                }
                transitioningToOriginalPath = originalPath;
                futureWallpaper = originalPath;

                if (_pathStr(futureWallpaper) === _pathStr(currentWallpaper.source)) {
                    transitioningToOriginalPath = "";
                    Wallpaper.wallpaperProcessingComplete(modelData.name, originalPath, "");
                    return;
                }

                debounceTimer.restart();
                Wallpaper.wallpaperProcessingComplete(modelData.name, originalPath, "");
            }

            // ------------------------------------------------------
            function setWallpaperImmediate(source) {
                transitionAnimation.stop();
                transitionProgress = 0.0;
                nextWallpaper.source = "";
                currentWallpaper.source = "";
                Qt.callLater(() => {
                    currentWallpaper.source = source;
                });
            }

            // ------------------------------------------------------
            function setWallpaperWithTransition(source) {
                if (!source || _pathStr(source) === _pathStr(currentWallpaper.source)) {
                    return;
                }
                if (transitioning && source === nextWallpaper.source) {
                    return;
                }

                if (transitioning) {
                    transitionAnimation.stop();
                    transitionProgress = 0;
                    currentWallpaper.source = nextWallpaper.source;
                    Qt.callLater(() => {
                        nextWallpaper.source = "";
                        Qt.callLater(() => {
                            _startTransitionTo(source);
                        });
                    });
                    return;
                }

                _startTransitionTo(source);
            }

            function _startTransitionTo(source) {
                nextWallpaper.source = source;
                if (nextWallpaper.status === Image.Ready) {
                    if (!wallpaperReady) {
                        wallpaperReady = true;
                    }
                    currentWallpaper.asynchronous = false;
                    transitionAnimation.start();
                } else {
                    nextWallpaper.pendingTransition = true;
                }
            }

            // ------------------------------------------------------
            function _pickTransitionType() {
                var selected = Settings.options.wallpaper.transitionType;
                if (!selected || selected.length === 0) {
                    transitionType = "none";
                } else if (selected.length === 1) {
                    transitionType = selected[0];
                } else {
                    transitionType = selected[Math.floor(Math.random() * selected.length)];
                }
                if (transitionType !== "none" && !allTransitions.includes(transitionType)) {
                    transitionType = "fade";
                }
            }

            function changeWallpaper() {
                _pickTransitionType();
                switch (transitionType) {
                case "none":
                    setWallpaperImmediate(futureWallpaper);
                    break;
                case "wipe":
                    wipeDirection = Math.random() * 4;
                    setWallpaperWithTransition(futureWallpaper);
                    break;
                case "disc":
                    discCenterX = Math.random();
                    discCenterY = Math.random();
                    setWallpaperWithTransition(futureWallpaper);
                    break;
                case "stripes":
                    stripesCount = Math.round(Math.random() * 20 + 4);
                    stripesAngle = Math.random() * 360;
                    setWallpaperWithTransition(futureWallpaper);
                    break;
                case "pixelate":
                    pixelateMaxBlockSize = Math.round(Math.random() * 80 + 32);
                    setWallpaperWithTransition(futureWallpaper);
                    break;
                case "honeycomb":
                    honeycombCellSize = Math.random() * 0.04 + 0.02;
                    honeycombCenterX = Math.random();
                    honeycombCenterY = Math.random();
                    setWallpaperWithTransition(futureWallpaper);
                    break;
                default:
                    setWallpaperWithTransition(futureWallpaper);
                    break;
                }
            }

            // ------------------------------------------------------
            function performStartupTransition() {
                if (Settings.options.wallpaper.skipStartupTransition || !futureWallpaper) {
                    setWallpaperImmediate(futureWallpaper);
                    isStartupTransition = false;
                    return;
                }

                _pickTransitionType();
                switch (transitionType) {
                case "wipe":
                    wipeDirection = Math.random() * 4;
                    break;
                case "disc":
                    discCenterX = 0.5;
                    discCenterY = 0.5;
                    break;
                case "stripes":
                    stripesCount = Math.round(Math.random() * 20 + 4);
                    stripesAngle = Math.random() * 360;
                    break;
                case "pixelate":
                    pixelateMaxBlockSize = 64.0;
                    break;
                case "honeycomb":
                    honeycombCellSize = 0.04;
                    honeycombCenterX = 0.5;
                    honeycombCenterY = 0.5;
                    break;
                }

                startupTransitionTimer.start();
            }

            function _executeStartupTransition() {
                if (transitionType === "none") {
                    setWallpaperImmediate(futureWallpaper);
                    isStartupTransition = false;
                } else {
                    setWallpaperWithTransition(futureWallpaper);
                }
            }
        }
    }
}
