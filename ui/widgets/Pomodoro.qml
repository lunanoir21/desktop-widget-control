import QtQuick
import QtQuick.Shapes
import Quickshell
import ".."
import "../controls"

// A focus / break timer. Click the ring (or the button) to start and pause.
// It runs on a one-second timer only while it is actually counting down, and
// finishes by sending a desktop notification through `notify-send` if the
// option is on. State lives for the session; a reload starts it over.
DwcWidget {
    id: root

    readonly property int focusMin: root.opt("focus", 25)
    readonly property int restMin: root.opt("rest", 5)
    readonly property bool notify: root.opt("notify", true)

    property string phase: "focus"        // "focus" | "break"
    property bool running: false
    property real endAt: 0
    property int remain: root.focusMin * 60
    property int done: 0

    readonly property int total: (root.phase === "focus" ? root.focusMin : root.restMin) * 60
    readonly property real frac: root.total > 0 ? Math.max(0, Math.min(1, root.remain / root.total)) : 0
    readonly property bool live: !root.preview

    // A changed option applies straight away while the timer is sitting idle.
    onFocusMinChanged: if (!root.running && root.phase === "focus") root.remain = root.focusMin * 60
    onRestMinChanged: if (!root.running && root.phase === "break") root.remain = root.restMin * 60

    function toggle() {
        if (!root.live)
            return;
        if (root.running) {
            root.remain = Math.max(0, Math.round((root.endAt - Date.now()) / 1000));
            root.running = false;
        } else {
            root.endAt = Date.now() + root.remain * 1000;
            root.running = true;
        }
    }

    function reset() {
        root.running = false;
        root.phase = "focus";
        root.remain = root.focusMin * 60;
    }

    function finish() {
        root.running = false;
        var wasFocus = root.phase === "focus";
        if (wasFocus)
            root.done += 1;
        if (root.notify)
            Quickshell.execDetached(["notify-send", "-a", "Desktop Widget Control",
                                     wasFocus ? Str.t("w.pomoDone") : Str.t("w.pomoBreakDone")]);
        root.phase = wasFocus ? "break" : "focus";
        root.remain = (wasFocus ? root.restMin : root.focusMin) * 60;
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.running && !DwcData.paused
        onTriggered: {
            root.remain = Math.max(0, Math.ceil((root.endAt - Date.now()) / 1000));
            if (root.remain <= 0)
                root.finish();
        }
    }

    function clock(s) {
        var m = Math.floor(s / 60);
        var r = s % 60;
        return (m < 10 ? "0" : "") + m + ":" + (r < 10 ? "0" : "") + r;
    }

    readonly property real dia: Math.min(root.width, root.height)
    readonly property real stroke: Math.max(6, dia * 0.07)
    readonly property color ink: root.phase === "focus" ? root.tone("color") : DwcTheme.acc2

    Item {
        id: ring
        width: root.dia
        height: root.dia
        x: root.small ? (root.width - width) / 2 : 0
        y: (root.height - height) / 2

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: DwcTheme.track
                strokeWidth: root.stroke
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: ring.width / 2; centerY: ring.height / 2
                    radiusX: (ring.width - root.stroke) / 2; radiusY: (ring.height - root.stroke) / 2
                    startAngle: -90; sweepAngle: 359.9
                }
            }
            ShapePath {
                strokeColor: root.ink
                strokeWidth: root.stroke
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: ring.width / 2; centerY: ring.height / 2
                    radiusX: (ring.width - root.stroke) / 2; radiusY: (ring.height - root.stroke) / 2
                    startAngle: -90; sweepAngle: Math.max(0.1, 359.9 * root.frac)
                }
            }
        }

        Column {
            anchors.centerIn: parent
            DText {
                anchors.horizontalCenter: parent.horizontalCenter
                face: "mono"
                font.pixelSize: Math.round(ring.height * 0.2)
                text: root.clock(root.remain)
            }
            DText {
                anchors.horizontalCenter: parent.horizontalCenter
                font.pixelSize: Math.max(10, Math.round(ring.height * 0.095))
                color: DwcTheme.muted
                text: root.phase === "focus" ? Str.t("w.focus") : Str.t("w.break")
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.live
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggle()
        }
    }

    Column {
        visible: !root.small
        anchors { left: ring.right; leftMargin: Math.round(root.height * 0.2); right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: 8

        DText {
            width: parent.width
            face: "display"
            font.pixelSize: Math.max(13, Math.round(root.height * 0.15))
            font.weight: Font.DemiBold
            text: "Pomodoro"
        }
        DText {
            width: parent.width
            face: "mono"
            font.pixelSize: 11
            color: DwcTheme.muted
            text: root.done + " ✓"
        }
        Row {
            spacing: 8
            DButton {
                primary: true
                text: root.running ? Str.t("w.pause") : (root.remain < root.total ? Str.t("w.resume") : Str.t("w.start"))
                enabled: root.live
                onClicked: root.toggle()
            }
            DButton {
                icon: "reset"
                enabled: root.live
                onClicked: root.reset()
            }
        }
    }
}
