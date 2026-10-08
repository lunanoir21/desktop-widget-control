import QtQuick
import QtQuick.Effects
import Quickshell.Io
import ".."
import "../controls"
import "../js/Github.js" as Github

// A GitHub profile: picture, name, the numbers (followers, repositories, stars),
// the contribution calendar, the languages used and the top repositories.
// Everything comes from public pages (see scripts/github.sh), read on a timer
// while the widget is visible and never when it is not; no token, no login.
//
// The card is composed from a few blocks (header, stats, graph, languages,
// repositories) that each size lays out differently: M is a header over the
// graph, W puts the profile beside the graph, L stacks everything, X adds a
// column of repositories. Nothing here is a fixed pixel size: `u` is 1 at the
// default cell size and follows the card.
DwcWidget {
    id: root

    readonly property string rawUser: String(root.opt("user", "")).trim().replace(/^@/, "")
    readonly property bool hasUser: Github.validName(root.rawUser)
    readonly property string layoutKey: ({ L: "l", W: "w", X: "x", B: "b", H: "h" })[root.sizeKey] || "m"
    // Each layout is drawn on a box of its own, measured in `u`; the card scales it to fit. The big
    // sizes use a box smaller than the card on purpose, so type and calendar squares come out large.
    readonly property var box: ({ m: [292, 132], w: [452, 132], l: [265, 265], x: [772, 132], b: [264, 170], h: [264, 214] })[layoutKey]
    readonly property real u: Math.min(root.width / box[0], root.height / box[1])

    readonly property bool showGraph: root.opt("graph", true)
    readonly property bool showLangs: root.opt("languages", true)
    readonly property bool byStars: root.opt("repoSort", "stars") === "stars"
    readonly property bool withForks: root.opt("forks", false)
    readonly property bool wantAvatar: root.opt("avatar", true)
    readonly property bool useLogin: root.opt("login", false)
    readonly property string script: Qt.resolvedUrl("../scripts/github.sh").toString().replace("file://", "")

    DwcNeed { source: "clock"; interval: 60000 }
    readonly property int nowS: Math.floor(DwcData.now.getTime() / 1000)

    // ---- the data ------------------------------------------------------------
    property var reading: null            // the last good Github.parse() result ...
    property string readingFor: ""        // ... and the name it was read for
    property string err: ""               // "", "notfound", "limited", "offline"
    property string asked: ""
    property real lastTry: 0
    property real fetchedAt: 0            // epoch seconds of the last good read
    property real limitedUntil: 0         // epoch seconds GitHub said the limit lifts (0 = unknown)

    // A library thumbnail gets made-up numbers so the card is not empty.
    readonly property var sampleData: Github.sample(Math.floor(Date.now() / 1000))
    readonly property var info: root.preview ? root.sampleData : (root.readingFor === root.rawUser ? root.reading : null)
    // "nouser" | "notfound" | "loading" | "offline" | "limited" | "ok"
    readonly property string shown: root.info ? "ok"
        : root.rawUser === "" ? "nouser"
        : !root.hasUser ? "notfound"
        : root.err !== "" ? root.err : "loading"

    readonly property var user: root.info ? root.info.user : null
    readonly property var days: root.info && root.showGraph ? root.info.days : []
    readonly property var gs: Github.graphStats(root.days)
    readonly property var rs: Github.repoStats(root.info ? root.info.repos : [], root.withForks)
    readonly property var topRepos: root.byStars ? root.rs.byStars : root.rs.byPush
    readonly property string picture: root.info && root.info.avatar !== "" && root.wantAvatar ? "file://" + root.info.avatar : ""

    function fetch(force) {
        if (root.preview || !root.hasUser || proc.running)
            return;
        // a hidden-and-shown widget would otherwise ask again at once; the API allows 60 reads an hour
        if (!force && root.reading && root.readingFor === root.rawUser && Date.now() - root.lastTry < 60000)
            return;
        // no point asking while GitHub has said it will not answer
        if (!force && root.limitedUntil > Date.now() / 1000)
            return;
        root.lastTry = Date.now();
        root.asked = root.rawUser;
        proc.command = ["sh", root.script, root.rawUser, root.wantAvatar ? "1" : "0", root.useLogin ? "1" : "0"];
        proc.running = true;
    }

    function got(text) {
        if (root.asked !== root.rawUser) {
            // the name was changed while this was running
            root.fetch(true);
            return;
        }
        var r = Github.parse(text);
        if (r.error) {
            root.err = r.error;
            root.limitedUntil = r.error === "limited" ? r.resetAt : 0;
            if (r.error === "notfound")
                root.readingFor = "";
            return;
        }
        root.reading = r;
        root.readingFor = root.asked;
        root.fetchedAt = Math.floor(Date.now() / 1000);
        root.limitedUntil = 0;
        root.err = "";
    }

    Process {
        id: proc
        stdout: StdioCollector { onStreamFinished: root.got(text) }
    }

    Timer {
        interval: root.opt("refresh", 30) * 60000
        running: root.hasUser && !root.preview && !DwcData.idle
        repeat: true
        triggeredOnStart: true
        onTriggered: root.fetch(false)
    }

    Timer {
        id: debounce
        interval: 800
        onTriggered: root.fetch(true)
    }
    onRawUserChanged: {
        root.err = "";
        debounce.restart();
    }
    onWantAvatarChanged: debounce.restart()
    onUseLoginChanged: debounce.restart()

    // ---- small helpers ---------------------------------------------------------
    function langTone(name) {
        var l = root.rs.languages;
        var c = root.tone("color");
        var c2 = root.tone("color2");
        var palette = [c, c2, DwcTheme.mix(c, DwcTheme.fg, 0.5), DwcTheme.mix(c2, DwcTheme.fg, 0.5), DwcTheme.sub];
        for (var i = 0; i < l.length; i++)
            if (l[i].name === name)
                return l[i].name === "" ? DwcTheme.muted : palette[Math.min(i, 4)];
        return DwcTheme.muted;
    }

    function agoText(at) {
        var a = Github.ago(at, root.nowS);
        return a.n + Str.t("gh." + a.unit);
    }

    function grouped(n) {
        return Number(n).toLocaleString(Str.locale, "f", 0);
    }

    // ---- message states --------------------------------------------------------
    Column {
        visible: root.shown !== "ok"
        anchors.centerIn: parent
        width: parent.width
        spacing: 4
        DLogo {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "github"
            size: 26 * root.u
            color: DwcTheme.muted
        }
        DText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            font.weight: Font.Medium
            font.pixelSize: Math.max(12, 12 * root.u)
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
            text: root.shown === "nouser" ? Str.t("gh.setUser")
                : root.shown === "notfound" ? Str.t("gh.notFound")
                : root.shown === "offline" ? Str.t("gh.offline")
                : root.shown === "limited" ? Str.t("gh.limited") + (root.limitedUntil > 0 ? " " + Str.t("gh.readyAt") + " " + Qt.formatTime(new Date(root.limitedUntil * 1000), "HH:mm") : "")
                : Str.t("gh.loading")
        }
        DText {
            visible: root.shown === "nouser" && root.height > 100
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            color: DwcTheme.muted
            font.pixelSize: Math.max(11, 11 * root.u)
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
            text: Str.t("gh.setUserSub")
        }
        // the quick way out of the limit: GitHub allows far more reads to a logged-in `gh`
        Rectangle {
            visible: !root.preview && root.shown === "limited" && !root.useLogin && root.wid !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            width: loginLabel.implicitWidth + 24 * root.u
            height: Math.max(24, 26 * root.u)
            radius: height / 2
            color: DwcTheme.acc
            DText {
                id: loginLabel
                anchors.centerIn: parent
                font.pixelSize: Math.max(11, 11 * root.u)
                color: DwcTheme.onAcc
                elide: Text.ElideNone
                text: Str.t("gh.useLogin")
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: DwcStore.setCfg(root.wid, "login", true)
            }
        }
        // a failed read can be tried again at once instead of waiting for the next refresh
        Rectangle {
            visible: !root.preview && (root.shown === "limited" || root.shown === "offline" || root.shown === "notfound")
            anchors.horizontalCenter: parent.horizontalCenter
            width: retryLabel.implicitWidth + 24 * root.u
            height: Math.max(24, 26 * root.u)
            radius: height / 2
            color: retry.containsMouse ? DwcTheme.hover : "transparent"
            border.width: 1
            border.color: retry.containsMouse ? DwcTheme.lineStrong : DwcTheme.line
            DText {
                id: retryLabel
                anchors.centerIn: parent
                font.pixelSize: Math.max(11, 11 * root.u)
                elide: Text.ElideNone
                text: proc.running ? Str.t("gh.loading") : Str.t("gh.retry")
            }
            MouseArea {
                id: retry
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.fetch(true)
            }
        }
    }

    Loader {
        anchors.fill: parent
        active: root.shown === "ok"
        sourceComponent: ({ l: layoutL, w: layoutW, x: layoutX, b: layoutB, h: layoutH })[root.layoutKey] || layoutM
    }

    // ---- refresh now -----------------------------------------------------------
    // Shown while the pointer is over the card (or a read is running): how old the numbers are and a
    // button that reads again at once, whatever the refresh option says.
    HoverHandler { id: hover }
    Rectangle {
        id: refreshBtn
        z: 10
        visible: root.hasUser && !root.preview && (hover.hovered || proc.running)
        anchors { top: parent.top; right: parent.right }
        height: Math.max(20, 22 * root.u)
        width: label.implicitWidth + icon.width + 18 * root.u
        radius: height / 2
        color: DwcTheme.alpha(DwcTheme.alt, 0.94)
        border.width: 1
        border.color: press.containsMouse ? DwcTheme.lineStrong : DwcTheme.line

        DText {
            id: label
            anchors { left: parent.left; leftMargin: 9 * root.u; verticalCenter: parent.verticalCenter }
            face: "mono"
            font.pixelSize: Math.max(10, 10 * root.u)
            color: DwcTheme.sub
            elide: Text.ElideNone
            text: proc.running ? Str.t("gh.loading")
                : root.useLogin && root.info && root.info.login === "none" ? Str.t("gh.noLogin")
                : root.useLogin && root.info && root.info.login === "bad" ? Str.t("gh.badLogin")
                : root.fetchedAt > 0 ? Str.t("gh.updated") + " " + root.agoText(root.fetchedAt) + " " + Str.t("gh.ago")
                : Str.t("gh.refresh")
        }
        DIcon {
            id: icon
            anchors { right: parent.right; rightMargin: 6 * root.u; verticalCenter: parent.verticalCenter }
            name: "reset"
            size: Math.max(12, 13 * root.u)
            color: DwcTheme.fg
            NumberAnimation on rotation {
                running: proc.running
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
            }
            onRotationChanged: if (!proc.running && rotation !== 0) rotation = 0
        }
        MouseArea {
            id: press
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.fetch(true)
        }
    }

    // ---- layouts ---------------------------------------------------------------
    // M: the header with two numbers at its right, the calendar underneath.
    Component {
        id: layoutM
        Item {
            Loader {
                id: head
                width: parent.width - 96 * root.u
                height: 44 * root.u
                sourceComponent: headC
            }
            Column {
                anchors { right: parent.right; top: parent.top }
                width: 88 * root.u
                spacing: 4 * root.u
                Loader { width: parent.width; height: 16 * root.u; sourceComponent: statC; property string icon: "users"; property string value: root.user ? Github.compact(root.user.followers) : ""; property color tint: DwcTheme.sub }
                Loader { width: parent.width; height: 16 * root.u; sourceComponent: statC; property string icon: "star"; property string value: Github.compact(root.rs.stars); property color tint: root.tone("color2") }
            }
            Loader {
                anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 52 * root.u; bottom: parent.bottom }
                sourceComponent: graphC
            }
        }
    }

    // W: the profile on the left, the calendar on the right.
    Component {
        id: layoutW
        Item {
            readonly property real side: Math.round(parent.width * 0.36)
            Loader {
                id: head
                width: parent.width * 0.36
                height: 44 * root.u
                sourceComponent: headC
            }
            Loader {
                anchors { left: parent.left; right: head.right; top: parent.top; topMargin: 54 * root.u }
                height: 40 * root.u
                sourceComponent: statsC
            }
            Rectangle { x: Math.round(parent.width * 0.375); width: 1; height: parent.height; color: DwcTheme.line }
            Loader {
                anchors { left: parent.left; leftMargin: Math.round(parent.width * 0.4); right: parent.right; top: parent.top; bottom: parent.bottom }
                sourceComponent: graphC
            }
        }
    }

    // L: everything in one column: header, bio, numbers, calendar, languages, repositories.
    Component {
        id: layoutL
        Item {
            Column {
                id: top
                width: parent.width
                spacing: 6 * root.u
                Loader { width: parent.width; height: 52 * root.u; sourceComponent: headC }
                DText {
                    visible: !!root.user && root.user.bio !== ""
                    width: parent.width
                    font.pixelSize: 11.5 * root.u
                    color: DwcTheme.sub
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    text: root.user ? root.user.bio : ""
                }
                Loader { width: parent.width; height: 16 * root.u; sourceComponent: statsC; property bool row: true }
                Loader { width: parent.width; height: 78 * root.u; sourceComponent: graphC; visible: root.showGraph; property real cell: 8 }
                Loader { width: parent.width; height: 28 * root.u; sourceComponent: langC; visible: root.showLangs }
            }
            Loader {
                anchors { left: parent.left; right: parent.right; top: top.bottom; topMargin: 4 * root.u; bottom: parent.bottom }
                sourceComponent: reposC
            }
        }
    }

    // B: the profile and its numbers on one row, a large calendar, the languages. H adds repositories.
    Component {
        id: layoutB
        Item {
            Loader {
                id: head
                width: parent.width * 0.63
                height: 44 * root.u
                sourceComponent: headC
            }
            Loader {
                anchors { left: head.right; right: parent.right; top: parent.top }
                height: 40 * root.u
                sourceComponent: statsC
            }
            Loader {
                anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 50 * root.u }
                height: 86 * root.u
                sourceComponent: graphC
                visible: root.showGraph
                property real cell: 8
            }
            Loader {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 28 * root.u
                visible: root.showLangs
                sourceComponent: langC
            }
        }
    }
    Component {
        id: layoutH
        Item {
            Loader {
                id: head
                width: parent.width * 0.63
                height: 44 * root.u
                sourceComponent: headC
            }
            Loader {
                anchors { left: head.right; right: parent.right; top: parent.top }
                height: 40 * root.u
                sourceComponent: statsC
            }
            Loader {
                id: cal
                anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 50 * root.u }
                height: 86 * root.u
                sourceComponent: graphC
                visible: root.showGraph
                property real cell: 8
            }
            Loader {
                id: lg
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 28 * root.u
                visible: root.showLangs
                sourceComponent: langC
            }
            Loader {
                anchors { left: parent.left; right: parent.right; top: cal.bottom; topMargin: 6 * root.u; bottom: root.showLangs ? lg.top : parent.bottom; bottomMargin: root.showLangs ? 6 * root.u : 0 }
                sourceComponent: reposC
            }
        }
    }

    // X: profile, calendar, then languages over the repositories.
    Component {
        id: layoutX
        Item {
            Loader {
                id: head
                width: parent.width * 0.25
                height: 44 * root.u
                sourceComponent: headC
            }
            Loader {
                anchors { left: parent.left; right: head.right; top: parent.top; topMargin: 54 * root.u }
                height: 40 * root.u
                sourceComponent: statsC
            }
            Rectangle { x: Math.round(parent.width * 0.27); width: 1; height: parent.height; color: DwcTheme.line }
            Loader {
                anchors { left: parent.left; leftMargin: Math.round(parent.width * 0.295); right: parent.right; rightMargin: Math.round(parent.width * 0.33); top: parent.top; bottom: parent.bottom }
                sourceComponent: graphC
                property real cell: 9
            }
            Rectangle { x: Math.round(parent.width * 0.69); width: 1; height: parent.height; color: DwcTheme.line }
            Loader {
                id: langs
                anchors { left: parent.left; leftMargin: Math.round(parent.width * 0.715); right: parent.right; bottom: parent.bottom }
                height: 30 * root.u
                visible: root.showLangs
                sourceComponent: langC
            }
            Loader {
                anchors { left: langs.left; right: parent.right; top: parent.top; bottom: root.showLangs ? langs.top : parent.bottom; bottomMargin: root.showLangs ? 6 * root.u : 0 }
                sourceComponent: reposC
            }
        }
    }

    // ---- blocks ----------------------------------------------------------------
    // the picture, or the first letter when there is none (yet)
    Component {
        id: avatarC
        Item {
            id: av
            Rectangle {
                id: mask
                anchors.fill: parent
                // round in the standard, mono and dots looks, square in terminal and poster
                radius: root.family === "term" || root.family === "poster" ? 0 : width / 2
                layer.enabled: true
                visible: false
            }
            Item {
                anchors.fill: parent
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: mask
                }
                Rectangle {
                    anchors.fill: parent
                    color: DwcTheme.alt
                    DText {
                        anchors.centerIn: parent
                        face: "display"
                        font.weight: Font.DemiBold
                        font.pixelSize: av.height * 0.45
                        text: root.user ? root.user.login.charAt(0).toUpperCase() : ""
                    }
                }
                Image {
                    anchors.fill: parent
                    source: root.picture
                    visible: status === Image.Ready
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    sourceSize: Qt.size(160, 160)
                }
            }
        }
    }

    // picture, name and @login (with the place, when there is room)
    Component {
        id: headC
        Item {
            id: h
            readonly property real a: Math.min(h.height, 64 * root.u)
            Loader {
                id: pic
                width: h.a
                height: h.a
                anchors.verticalCenter: parent.verticalCenter
                sourceComponent: avatarC
            }
            Column {
                anchors { left: pic.right; leftMargin: 10 * root.u; right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 1
                DText {
                    width: parent.width
                    face: "display"
                    // the dot-matrix and mono faces are wider; a smaller size keeps a long name on the line
                    font.pixelSize: (root.family === "dots" || root.family === "term" || root.family === "mono" ? 13 : 15) * root.u
                    font.weight: Font.DemiBold
                    text: root.user ? (root.user.name !== "" ? root.user.name : root.user.login) : ""
                }
                Row {
                    width: parent.width
                    spacing: 5 * root.u
                    DLogo { name: "github"; size: 11 * root.u; color: DwcTheme.muted; anchors.verticalCenter: parent.verticalCenter }
                    DText {
                        width: parent.width - 16 * root.u
                        face: "mono"
                        font.pixelSize: 11 * root.u
                        color: DwcTheme.muted
                        text: root.user ? root.user.login : ""
                    }
                }
                DText {
                    visible: h.height >= 50 * root.u && text !== ""
                    width: parent.width
                    font.pixelSize: 11 * root.u
                    color: DwcTheme.sub
                    text: root.user ? (root.user.location !== "" ? root.user.location : root.user.company) : ""
                }
            }
        }
    }

    // one icon and one number (the Loader that holds it sets icon, value and tint)
    Component {
        id: statC
        Row {
            spacing: 5 * root.u
            DIcon { anchors.verticalCenter: parent.verticalCenter; name: parent.parent.icon; size: 13 * root.u; color: parent.parent.tint }
            DText {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 18 * root.u
                face: "mono"
                font.pixelSize: 11.5 * root.u
                text: parent.parent.value
            }
        }
    }

    // followers, repositories, stars, forks: a row, or a 2×2 block when narrow
    Component {
        id: statsC
        Flow {
            id: flow
            spacing: 6 * root.u
            readonly property real cellW: parent.row === true ? (flow.width - 3 * flow.spacing) / 4 : (flow.width - flow.spacing) / 2
            readonly property var items: root.user ? [
                { icon: "users", value: Github.compact(root.user.followers), tint: DwcTheme.sub },
                { icon: "repo",  value: Github.compact(root.user.repos),     tint: DwcTheme.sub },
                { icon: "star",  value: Github.compact(root.rs.stars),       tint: root.tone("color2") },
                { icon: "fork",  value: Github.compact(root.rs.forks),       tint: DwcTheme.sub }
            ] : []
            Repeater {
                model: flow.items
                delegate: Row {
                    required property var modelData
                    width: flow.cellW
                    height: 16 * root.u
                    spacing: 5 * root.u
                    DIcon { anchors.verticalCenter: parent.verticalCenter; name: modelData.icon; size: 13 * root.u; color: modelData.tint }
                    DText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 18 * root.u
                        face: "mono"
                        font.pixelSize: 11.5 * root.u
                        text: modelData.value
                    }
                }
            }
        }
    }

    // the calendar with its totals underneath
    Component {
        id: graphC
        Item {
            id: g
            readonly property real capH: 14 * root.u
            DHeatmap {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: g.height - g.capH - 5 * root.u
                visible: root.days.length > 0
                days: root.days
                color: root.tone("color")
                maxCell: (parent.parent.cell !== undefined ? parent.parent.cell : 11) * root.u
                gap: Math.max(1.5, 2 * root.u)
            }
            DText {
                visible: root.days.length === 0
                anchors.fill: parent
                horizontalAlignment: Text.AlignHCenter
                face: "mono"
                font.pixelSize: 11 * root.u
                color: DwcTheme.muted
                text: root.showGraph ? Str.t("gh.noGraph") : ""
            }
            DText {
                visible: root.days.length > 0
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: g.capH
                face: "mono"
                font.pixelSize: 10.5 * root.u
                color: DwcTheme.sub
                text: root.grouped(root.gs.total) + " " + Str.t("gh.contributions")
                    + (root.gs.current > 0 ? "  ·  " + Str.t("gh.streak") + " " + root.gs.current + Str.t("gh.days") : "")
                    + (g.width > 330 * root.u && root.gs.longest > 0 ? "  ·  " + Str.t("gh.longest") + " " + root.gs.longest + Str.t("gh.days") : "")
            }
        }
    }

    // a share bar of the languages with the names under it
    Component {
        id: langC
        Item {
            id: lc
            readonly property var langs: root.rs.languages
            Row {
                id: bar
                width: parent.width
                height: 5 * root.u
                spacing: 2
                Repeater {
                    model: lc.langs
                    delegate: Rectangle {
                        required property var modelData
                        height: bar.height
                        width: Math.max(2, (bar.width - bar.spacing * (lc.langs.length - 1)) * modelData.pct)
                        radius: root.family === "std" || root.family === "dots" ? height / 2 : 0
                        color: root.langTone(modelData.name)
                    }
                }
            }
            Flow {
                anchors { left: parent.left; right: parent.right; top: bar.bottom; topMargin: 6 * root.u; bottom: parent.bottom }
                spacing: 10 * root.u
                clip: true
                Repeater {
                    model: lc.langs
                    delegate: Row {
                        required property var modelData
                        spacing: 4 * root.u
                        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 6 * root.u; height: width; radius: width / 2; color: root.langTone(modelData.name) }
                        DText {
                            face: "mono"
                            font.pixelSize: 10 * root.u
                            color: DwcTheme.sub
                            elide: Text.ElideNone
                            text: (modelData.name === "" ? Str.t("gh.other") : modelData.name) + " " + Math.round(modelData.pct * 100) + "%"
                        }
                    }
                }
            }
        }
    }

    // as many repositories as there is room for: name, then the stars (or how long ago it was pushed)
    Component {
        id: reposC
        Item {
            id: rc
            readonly property real rowH: 19 * root.u
            readonly property int fit: Math.floor(rc.height / rc.rowH)
            DText {
                visible: root.topRepos.length === 0
                anchors.fill: parent
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 11 * root.u
                color: DwcTheme.muted
                text: Str.t("gh.noRepos")
            }
            Column {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                Repeater {
                    model: root.topRepos.slice(0, Math.max(0, rc.fit))
                    delegate: Item {
                        required property var modelData
                        width: parent.width
                        height: rc.rowH
                        Rectangle {
                            id: dot
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            width: 7 * root.u
                            height: width
                            radius: width / 2
                            color: root.langTone(modelData.lang)
                        }
                        DText {
                            anchors { left: dot.right; leftMargin: 7 * root.u; right: value.left; rightMargin: 8 * root.u; verticalCenter: parent.verticalCenter }
                            font.pixelSize: 12 * root.u
                            text: modelData.name
                        }
                        Row {
                            id: value
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            spacing: 4 * root.u
                            DIcon {
                                visible: root.byStars
                                anchors.verticalCenter: parent.verticalCenter
                                name: "star"
                                size: 12 * root.u
                                color: root.tone("color2")
                            }
                            DText {
                                anchors.verticalCenter: parent.verticalCenter
                                face: "mono"
                                font.pixelSize: 11 * root.u
                                color: root.byStars ? DwcTheme.fg : DwcTheme.sub
                                text: root.byStars ? Github.compact(modelData.stars) : root.agoText(modelData.pushed)
                            }
                        }
                    }
                }
            }
        }
    }
}
