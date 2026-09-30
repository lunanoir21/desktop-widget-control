import QtQuick
import QtQuick.Shapes
import ".."
import "../controls"

// Download and upload rates. The bars style mirrors them around a centre line,
// download growing up and upload growing down, on one shared scale; the line
// style is the two plain sparklines.
DwcWidget {
    id: root

    readonly property bool bits: root.opt("unit", "bytes") === "bits"
    readonly property string iface: String(root.opt("iface", "auto")).trim() || "auto"
    readonly property string design: root.opt("design", "bars")

    DwcNeed { source: "net"; interval: root.opt("interval", 1) * 1000 }

    property var rxHist: []
    property var txHist: []
    property real rx: 0
    property real tx: 0

    Connections {
        target: DwcData
        function onNetUpdated() {
            var r = DwcData.netRates[root.iface] || { rx: 0, tx: 0 };
            root.rx = r.rx;
            root.tx = r.tx;
            root.rxHist = DwcData.push(root.rxHist, r.rx);
            root.txHist = DwcData.push(root.txHist, r.tx);
        }
    }

    // Scale to the busiest sample, but never below 10 KB/s so idle noise stays flat.
    readonly property real scaleTop: {
        var m = 10000;
        for (var i = 0; i < rxHist.length; i++)
            m = Math.max(m, rxHist[i]);
        for (var j = 0; j < txHist.length; j++)
            m = Math.max(m, txHist[j]);
        return m;
    }

    function norm(hist) {
        return hist.map(function (v) { return v / root.scaleTop; });
    }

    function line(hist, w, h) {
        var n = hist.length;
        var out = [];
        var dx = w / 59;
        if (n < 2) {
            out.push(Qt.point(0, h));
            out.push(Qt.point(w, h));
            return out;
        }
        for (var i = 0; i < n; i++)
            out.push(Qt.point(w - (n - 1 - i) * dx, h - Math.min(1, hist[i] / root.scaleTop) * h));
        return out;
    }

    readonly property int fontPx: Math.max(11, Math.min(16, Math.round(root.height * 0.11)))
    // Small cards stack the two readings; wider ones put them on one line.
    readonly property real labelH: (root.small ? 2 : 1) * (root.fontPx + 4)

    Item {
        id: plot
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: root.height - root.labelH - 6

        // bars: download above the middle, upload below it
        DBarGraph {
            visible: root.design === "bars"
            x: 0
            y: 0
            width: parent.width
            height: parent.height / 2 - 1
            values: root.norm(root.rxHist)
            low: root.tone("color")
            gradient: false
        }
        Rectangle {
            visible: root.design === "bars"
            y: parent.height / 2 - 1
            width: parent.width
            height: 1
            color: DwcTheme.alpha(DwcTheme.fg, 0.22)
        }
        DBarGraph {
            visible: root.design === "bars"
            x: 0
            y: parent.height / 2 + 1
            width: parent.width
            height: parent.height / 2 - 1
            values: root.norm(root.txHist)
            low: root.tone("color2")
            gradient: false
            flip: true
        }
        // the scale, top right
        DText {
            visible: root.design === "bars"
            anchors { right: parent.right; top: parent.top }
            face: "mono"
            font.pixelSize: 9
            color: DwcTheme.faint
            text: DwcData.rate(root.scaleTop, root.bits)
        }

        Shape {
            anchors.fill: parent
            visible: root.design === "line"
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 1.6
                strokeColor: root.tone("color")
                fillColor: "transparent"
                joinStyle: ShapePath.RoundJoin
                capStyle: ShapePath.RoundCap
                PathPolyline { path: root.design === "line" ? root.line(root.rxHist, plot.width, plot.height) : [] }
            }
            ShapePath {
                strokeWidth: 1.6
                strokeColor: root.tone("color2")
                fillColor: "transparent"
                joinStyle: ShapePath.RoundJoin
                capStyle: ShapePath.RoundCap
                PathPolyline { path: root.design === "line" ? root.line(root.txHist, plot.width, plot.height) : [] }
            }
        }
    }

    Item {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: root.labelH

        DText {
            anchors { left: parent.left; top: parent.top }
            height: root.fontPx + 4
            face: "mono"
            font.pixelSize: root.fontPx
            color: root.tone("color")
            text: "↓ " + DwcData.rate(root.rx, root.bits)
        }
        DText {
            anchors { right: root.small ? undefined : parent.right; left: root.small ? parent.left : undefined; bottom: parent.bottom }
            height: root.fontPx + 4
            face: "mono"
            font.pixelSize: root.fontPx
            color: root.tone("color2")
            text: "↑ " + DwcData.rate(root.tx, root.bits)
        }
    }
}
