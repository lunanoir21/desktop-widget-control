import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell.Services.Mpris
import ".."
import "../controls"

// Whatever MPRIS player is running (Spotify, mpv, a browser tab…): cover,
// title, artist, progress and transport buttons. Small = cover with a title
// bar; medium = cover beside the text; large = cover on top.
//
// The visualizer is part of the card rather than a box on it: the progress bar
// itself becomes the live spectrum (played bars lit, the rest faint), and a
// soft spectrum can also rise behind the whole widget.
DwcWidget {
    id: root

    readonly property string pref: String(root.opt("player", "")).toLowerCase().trim()
    readonly property bool showArt: root.opt("art", true)
    readonly property bool showProgress: root.opt("progress", true)
    // "s", "m", "l" for the card; "w" (wide strip), "p" (pill) and "o" (oscilloscope)
    // need a card at least 12 cells long and fall back to the card below that.
    readonly property string look: root.opt("look", "card")
    readonly property string mode: root.small ? "s"
        : (root.cols >= 12 && root.look === "wide" ? "w"
        : (root.cols >= 12 && root.look === "pill" ? "p"
        : (root.cols >= 12 && root.look === "scope" ? "o" : (root.rows >= 8 ? "l" : "m"))))
    // The pill is a capsule: it asks the card for a fully rounded shape.
    cardRadius: root.mode === "p" ? 90 : -1

    // The player to show: the one that is playing, else the first that matches.
    readonly property var player: {
        var ps = Mpris.players.values;
        var best = null;
        for (var i = 0; i < ps.length; i++) {
            var p = ps[i];
            if (root.pref !== "" && String(p.identity).toLowerCase().indexOf(root.pref) < 0
                    && String(p.dbusName).toLowerCase().indexOf(root.pref) < 0)
                continue;
            if (p.isPlaying)
                return p;
            if (!best)
                best = p;
        }
        return best;
    }

    // A library thumbnail with nothing playing shows a made-up track instead of an empty box.
    readonly property bool fake: root.preview && !root.player
    readonly property bool has: root.player !== null || root.fake
    readonly property bool playing: root.player ? root.player.isPlaying : false
    readonly property string title: root.fake ? "Track title" : (root.player ? root.player.trackTitle : "")
    readonly property string artist: root.fake ? "Artist" : (root.player ? root.player.trackArtist : "")
    // Cover art is only read from local files. A player-supplied http(s) URL would
    // make the shell fetch whatever address a track's metadata names.
    readonly property string artUrl: {
        var u = root.player ? String(root.player.trackArtUrl) : "";
        return (u.indexOf("file:///") === 0 && u.length < 2048) ? u : "";
    }
    readonly property real length: root.player && root.player.lengthSupported ? root.player.length : 0
    readonly property real pos: root.player && root.player.positionSupported ? root.player.position : 0
    readonly property real frac: root.length > 0 ? Math.min(1, root.pos / root.length) : 0
    readonly property bool live: !root.preview

    // Visualizer: "wave" (the progress bar is the spectrum), "backdrop" (a soft
    // spectrum behind the card), "both" or "off". It needs cava; without it the
    // option is ignored and nothing extra runs. Older values ("bars"…) mean wave.
    readonly property string viz: {
        var v = root.opt("viz", "wave");
        return ["off", "wave", "backdrop", "both"].indexOf(v) >= 0 ? v : "wave";
    }
    readonly property bool vizAvailable: DwcData.cavaAvailable && root.has
    readonly property bool waveOn: root.vizAvailable && (root.viz === "wave" || root.viz === "both") && root.showProgress
    readonly property bool backdropOn: root.vizAvailable && (root.viz === "backdrop" || root.viz === "both")
    DwcNeed { source: "spectrum"; interval: 33; enabled: (root.waveOn || root.backdropOn) && root.playing && root.live }

    function mmss(s) {
        var t = Math.max(0, Math.round(s));
        var m = Math.floor(t / 60);
        var r = t % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }

    // `position` does not announce itself; nudge it once a second while playing.
    Timer {
        interval: 1000
        repeat: true
        running: root.playing && root.showProgress && root.live && !DwcData.idle
        onTriggered: root.player.positionChanged()
    }

    // ---- behind everything: a soft spectrum rising from the bottom ----
    DSpectrum {
        visible: root.backdropOn
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: Math.round(root.height * 0.62)
        values: DwcData.spectrum
        live: root.playing
        color: root.tone("color")
        barWidth: 7
        gap: 3
        z: -1
    }

    // ---- cover ----
    Item {
        id: art
        visible: root.has && (root.showArt || root.mode === "s") && root.mode !== "p" && root.mode !== "o"
        x: 0
        y: 0
        width: root.mode === "m" || root.mode === "w" ? root.height : root.width
        height: root.mode === "l" ? Math.round(root.height * 0.5) : root.height

        Rectangle {
            id: artMask
            anchors.fill: parent
            radius: 10
            layer.enabled: true
            visible: false
        }

        Item {
            id: artBody
            anchors.fill: parent
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: artMask
            }

            Rectangle {
                anchors.fill: parent
                color: DwcTheme.alt
                DIcon {
                    anchors.centerIn: parent
                    name: "music"
                    size: Math.min(parent.width, parent.height) * 0.3
                    color: DwcTheme.muted
                }
            }
            Image {
                anchors.fill: parent
                source: root.artUrl
                asynchronous: true
                cache: false
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(320, 320)
                visible: status === Image.Ready
            }
        }

        // Small: title bar over the bottom edge; the spectrum runs along its foot.
        Rectangle {
            visible: root.mode === "s"
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: root.waveOn ? 52 : 38
            color: DwcTheme.alpha(DwcTheme.card, 0.9)

            Column {
                anchors { left: parent.left; leftMargin: 8; right: playBtn.left; rightMargin: 6; top: parent.top; topMargin: 5 }
                DText { width: parent.width; font.pixelSize: 11; font.weight: Font.DemiBold; text: root.title }
                DText { width: parent.width; font.pixelSize: 10; color: DwcTheme.muted; text: root.artist }
            }
            Rectangle {
                id: playBtn
                anchors { right: parent.right; rightMargin: 6; top: parent.top; topMargin: 6 }
                width: 26
                height: 26
                radius: 13
                color: root.tone("color")
                DIcon { anchors.centerIn: parent; name: root.playing ? "pause" : "play"; filled: true; size: 12; color: DwcTheme.onAcc }
                MouseArea {
                    anchors.fill: parent
                    enabled: root.live && root.player !== null
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.player.togglePlaying()
                }
            }
            DWaveProgress {
                visible: root.waveOn
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 8; rightMargin: 8; bottomMargin: 5 }
                height: 12
                values: DwcData.spectrum
                live: root.playing
                progress: root.frac
                color: root.tone("color")
                barWidth: 2
                gap: 2
                minH: 2
            }
        }
    }

    // ---- text and controls (medium, large) ----
    Item {
        id: info
        visible: root.has && root.mode !== "s" && root.mode !== "w" && root.mode !== "p" && root.mode !== "o"
        x: root.mode === "m" ? (art.visible ? art.width + Math.round(root.height * 0.12) : 0) : 0
        y: root.mode === "l" ? art.height + 10 : 0
        width: root.width - x
        height: root.height - y

        Column {
            id: textCol
            width: parent.width
            spacing: 2
            DText {
                width: parent.width
                face: "display"
                font.pixelSize: root.mode === "l" ? 17 : 15
                font.weight: Font.DemiBold
                text: root.title
            }
            DText {
                width: parent.width
                font.pixelSize: 12
                color: DwcTheme.muted
                text: root.artist
            }
        }

        Item {
            id: bottom
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: progress.height + 6 + controls.height

            Item {
                id: progress
                visible: root.showProgress
                width: parent.width
                height: !visible ? 0 : (root.waveOn ? (root.mode === "l" ? 44 : 26) : (root.mode === "l" ? 28 : 10))

                // the plain thin bar, when the spectrum is off
                Rectangle {
                    id: bar
                    visible: !root.waveOn
                    anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 3 }
                    height: 3
                    radius: 2
                    color: DwcTheme.track
                    Rectangle {
                        width: parent.width * root.frac
                        height: parent.height
                        radius: 2
                        color: root.tone("color")
                    }
                }

                // the progress bar that is also the level meter
                DWaveProgress {
                    visible: root.waveOn
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: root.mode === "l" ? 28 : 24
                    values: DwcData.spectrum
                    live: root.playing
                    progress: root.frac
                    color: root.tone("color")
                    barWidth: 3
                    gap: 2
                    minH: 3
                }

                MouseArea {
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: root.waveOn ? (root.mode === "l" ? 28 : 24) : 14
                    enabled: root.live && root.player !== null && root.player.canSeek && root.length > 0
                    cursorShape: Qt.PointingHandCursor
                    onClicked: m => root.player.position = Math.max(0, Math.min(1, m.x / width)) * root.length
                }

                DText {
                    visible: root.mode === "l"
                    anchors { left: parent.left; bottom: parent.bottom }
                    face: "mono"
                    font.pixelSize: 10
                    color: DwcTheme.muted
                    text: root.mmss(root.pos)
                }
                DText {
                    visible: root.mode === "l"
                    anchors { right: parent.right; bottom: parent.bottom }
                    face: "mono"
                    font.pixelSize: 10
                    color: DwcTheme.muted
                    text: root.mmss(root.length)
                }
            }

            Row {
                id: controls
                anchors.bottom: parent.bottom
                x: root.mode === "l" ? (parent.width - width) / 2 : 0
                spacing: root.mode === "l" ? 22 : 14
                height: 34

                MouseArea {
                    width: 28; height: 34
                    enabled: root.live && root.player !== null && root.player.canGoPrevious
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.player.previous()
                    DIcon { anchors.centerIn: parent; name: "prev"; filled: true; size: 16; color: DwcTheme.fg }
                }
                Rectangle {
                    width: 34; height: 34; radius: 17
                    color: root.tone("color")
                    DIcon { anchors.centerIn: parent; name: root.playing ? "pause" : "play"; filled: true; size: 16; color: DwcTheme.onAcc }
                    MouseArea {
                        anchors.fill: parent
                        enabled: root.live && root.player !== null
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.player.togglePlaying()
                    }
                }
                MouseArea {
                    width: 28; height: 34
                    enabled: root.live && root.player !== null && root.player.canGoNext
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.player.next()
                    DIcon { anchors.centerIn: parent; name: "next"; filled: true; size: 16; color: DwcTheme.fg }
                }
            }
        }
    }

    // ---- wide strip: cover, text, a long progress bar that is the spectrum, transport ----
    Item {
        id: wide
        visible: root.has && root.mode === "w"
        x: art.visible ? art.width + 22 : 0
        width: root.width - x
        height: root.height

        Column {
            id: wText
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: Math.min(250, parent.width * 0.3)
            spacing: 4
            DText {
                width: parent.width
                face: "display"
                font.pixelSize: 20
                font.weight: Font.DemiBold
                text: root.title
            }
            DText {
                width: parent.width
                font.pixelSize: 13
                color: DwcTheme.muted
                text: root.artist
            }
            DText {
                width: parent.width
                face: "mono"
                font.pixelSize: 11
                color: DwcTheme.faint
                text: root.mmss(root.pos) + " / " + root.mmss(root.length)
            }
        }

        Row {
            id: wControls
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 14

            MouseArea {
                anchors.verticalCenter: parent.verticalCenter
                width: 32; height: 44
                enabled: root.live && root.player !== null && root.player.canGoPrevious
                cursorShape: Qt.PointingHandCursor
                onClicked: root.player.previous()
                DIcon { anchors.centerIn: parent; name: "prev"; filled: true; size: 20; color: DwcTheme.fg }
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 52; height: 52; radius: 26
                color: root.tone("color")
                DIcon { anchors.centerIn: parent; name: root.playing ? "pause" : "play"; filled: true; size: 22; color: DwcTheme.onAcc }
                MouseArea {
                    anchors.fill: parent
                    enabled: root.live && root.player !== null
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.player.togglePlaying()
                }
            }
            MouseArea {
                anchors.verticalCenter: parent.verticalCenter
                width: 32; height: 44
                enabled: root.live && root.player !== null && root.player.canGoNext
                cursorShape: Qt.PointingHandCursor
                onClicked: root.player.next()
                DIcon { anchors.centerIn: parent; name: "next"; filled: true; size: 20; color: DwcTheme.fg }
            }
        }

        // The progress bar, as long as the space allows; click to seek.
        Item {
            id: wTrack
            anchors { left: wText.right; leftMargin: 30; right: wControls.left; rightMargin: 30; verticalCenter: parent.verticalCenter }
            height: 60

            DWaveProgress {
                visible: root.waveOn
                anchors.fill: parent
                values: DwcData.spectrum
                live: root.playing
                progress: root.frac
                color: root.tone("color")
                barWidth: 3
                gap: 3
                minH: 4
            }
            Rectangle {
                visible: !root.waveOn
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                height: 4
                radius: 2
                color: DwcTheme.track
                Rectangle {
                    width: parent.width * root.frac
                    height: parent.height
                    radius: 2
                    color: root.tone("color")
                }
            }
            MouseArea {
                anchors.fill: parent
                enabled: root.live && root.player !== null && root.player.canSeek && root.length > 0
                cursorShape: Qt.PointingHandCursor
                onClicked: m => root.player.position = Math.max(0, Math.min(1, m.x / width)) * root.length
            }
        }
    }

    // previous / play / next, for the pill and the oscilloscope
    component Transport: Row {
        property real scaleBy: 1
        spacing: 12 * scaleBy
        MouseArea {
            anchors.verticalCenter: parent.verticalCenter
            width: 28 * scaleBy; height: 40
            enabled: root.live && root.player !== null && root.player.canGoPrevious
            cursorShape: Qt.PointingHandCursor
            onClicked: root.player.previous()
            DIcon { anchors.centerIn: parent; name: "prev"; filled: true; size: 18 * scaleBy; color: DwcTheme.sub }
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 50 * scaleBy; height: width; radius: width / 2
            color: root.tone("color")
            DIcon { anchors.centerIn: parent; name: root.playing ? "pause" : "play"; filled: true; size: 22 * scaleBy; color: DwcTheme.onAcc }
            MouseArea {
                anchors.fill: parent
                enabled: root.live && root.player !== null
                cursorShape: Qt.PointingHandCursor
                onClicked: root.player.togglePlaying()
            }
        }
        MouseArea {
            anchors.verticalCenter: parent.verticalCenter
            width: 28 * scaleBy; height: 40
            enabled: root.live && root.player !== null && root.player.canGoNext
            cursorShape: Qt.PointingHandCursor
            onClicked: root.player.next()
            DIcon { anchors.centerIn: parent; name: "next"; filled: true; size: 18 * scaleBy; color: DwcTheme.sub }
        }
    }

    // ---- pill: a round cover in a progress ring, the title, a little equaliser, transport ----
    Item {
        id: pillBox
        visible: root.has && root.mode === "p"
        anchors.fill: parent

        Item {
            id: pArt
            width: parent.height
            height: parent.height

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: DwcTheme.track
                    strokeWidth: 5
                    fillColor: "transparent"
                    PathAngleArc { centerX: pArt.width / 2; centerY: pArt.height / 2; radiusX: pArt.width / 2 - 4; radiusY: pArt.height / 2 - 4; startAngle: -90; sweepAngle: 359.9 }
                }
                ShapePath {
                    strokeColor: root.tone("color")
                    strokeWidth: 5
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc { centerX: pArt.width / 2; centerY: pArt.height / 2; radiusX: pArt.width / 2 - 4; radiusY: pArt.height / 2 - 4; startAngle: -90; sweepAngle: Math.max(0.1, 359.9 * root.frac) }
                }
            }

            Rectangle {
                id: pMask
                anchors { fill: parent; margins: 13 }
                radius: width / 2
                layer.enabled: true
                visible: false
            }
            Item {
                anchors { fill: parent; margins: 13 }
                layer.enabled: true
                layer.effect: MultiEffect { maskEnabled: true; maskSource: pMask }
                Rectangle {
                    anchors.fill: parent
                    color: DwcTheme.alt
                    DIcon { anchors.centerIn: parent; name: "music"; size: parent.width * 0.3; color: DwcTheme.muted }
                }
                Image {
                    anchors.fill: parent
                    source: root.artUrl
                    asynchronous: true
                    cache: false
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(240, 240)
                    visible: status === Image.Ready
                }
            }
        }

        Column {
            id: pText
            anchors { left: pArt.right; leftMargin: 22; verticalCenter: parent.verticalCenter }
            width: Math.min(240, parent.width * 0.3)
            spacing: 3
            DText { width: parent.width; face: "display"; font.pixelSize: 21; font.weight: Font.DemiBold; text: root.title }
            DText { width: parent.width; font.pixelSize: 14; color: DwcTheme.muted; text: root.artist }
            DText { width: parent.width; face: "mono"; font.pixelSize: 11; color: DwcTheme.faint; text: root.mmss(root.pos) + " / " + root.mmss(root.length) }
        }

        Transport {
            id: pControls
            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
        }

        // the equaliser: only when cava is there, and only as wide as the room left
        DWaveProgress {
            visible: root.vizAvailable && root.viz !== "off"
            anchors { left: pText.right; leftMargin: 26; right: pControls.left; rightMargin: 26; verticalCenter: parent.verticalCenter }
            height: 56
            values: DwcData.spectrum
            live: root.playing
            progress: 1
            color: root.tone("color")
            barWidth: 3
            gap: 3
            minH: 4
        }
    }

    // ---- oscilloscope: mono readout, a live trace with a graticule, transport ----
    Item {
        id: scopeBox
        visible: root.has && root.mode === "o"
        anchors.fill: parent

        Column {
            id: oText
            anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
            width: Math.min(220, parent.width * 0.28)
            spacing: 4
            DText { width: parent.width; face: "mono"; font.pixelSize: 10; font.letterSpacing: 2; color: root.tone("color"); opacity: 0.6; text: "NOW PLAYING" }
            DText { width: parent.width; face: "mono"; font.pixelSize: 17; color: root.tone("color"); text: root.title }
            DText { width: parent.width; face: "mono"; font.pixelSize: 12; color: root.tone("color"); opacity: 0.75; text: root.artist }
            DText { width: parent.width; face: "mono"; font.pixelSize: 11; color: root.tone("color"); opacity: 0.55; topPadding: 10; text: root.mmss(root.pos) + " / " + root.mmss(root.length) }
        }

        Transport {
            id: oControls
            scaleBy: 0.9
            anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
        }

        Item {
            id: trace
            anchors { left: oText.right; leftMargin: 26; right: oControls.left; rightMargin: 26; top: parent.top; bottom: parent.bottom; topMargin: 4; bottomMargin: 4 }

            // graticule: 8 × 4 divisions
            Repeater {
                model: 7
                delegate: Rectangle { required property int index; x: (index + 1) * trace.width / 8; width: 1; height: trace.height; color: DwcTheme.alpha(root.tone("color"), 0.1) }
            }
            Repeater {
                model: 3
                delegate: Rectangle { required property int index; y: (index + 1) * trace.height / 4; width: trace.width; height: 1; color: DwcTheme.alpha(root.tone("color"), index === 1 ? 0.28 : 0.1) }
            }

            // The trace runs through the spectrum's bands; with nothing playing it is a flat line.
            // The part already played is lit, the rest left as a faint echo.
            readonly property var points: {
                var n = 72;
                var v = DwcData.spectrum;
                var out = [];
                for (var i = 0; i < n; i++) {
                    var t = i / (n - 1);
                    var lvl = 0;
                    if (root.playing && v.length > 0) {
                        var f = t * (v.length - 1);
                        var a = Math.floor(f);
                        var b = Math.min(v.length - 1, a + 1);
                        lvl = v[a] + (v[b] - v[a]) * (f - a);
                    }
                    out.push(Qt.point(t * trace.width, trace.height / 2 + (i % 2 ? 1 : -1) * lvl * trace.height * 0.42));
                }
                return out;
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: DwcTheme.alpha(root.tone("color"), 0.26)
                    strokeWidth: 1.6
                    fillColor: "transparent"
                    joinStyle: ShapePath.RoundJoin
                    PathPolyline { path: trace.points }
                }
            }
            Item {
                width: trace.width * root.frac
                height: trace.height
                clip: true
                Shape {
                    width: trace.width
                    height: trace.height
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: root.tone("color")
                        strokeWidth: 2.2
                        fillColor: "transparent"
                        joinStyle: ShapePath.RoundJoin
                        PathPolyline { path: trace.points }
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                enabled: root.live && root.player !== null && root.player.canSeek && root.length > 0
                cursorShape: Qt.PointingHandCursor
                onClicked: m => root.player.position = Math.max(0, Math.min(1, m.x / width)) * root.length
            }
        }
    }

    // ---- nothing playing ----
    Column {
        visible: !root.has
        anchors.centerIn: parent
        spacing: 8
        DIcon { anchors.horizontalCenter: parent.horizontalCenter; name: "music"; size: 26; color: DwcTheme.muted }
        DText { anchors.horizontalCenter: parent.horizontalCenter; color: DwcTheme.muted; text: Str.t("w.noPlayer") }
    }
}
