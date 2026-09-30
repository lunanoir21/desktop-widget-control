import QtQuick
import QtQuick.Shapes
import ".."
import "../controls"

// CPU load, in two styles (the Style option): btop-like bars, one per sample and
// coloured by how high it reached, or the plain line. A second series
// (temperature or memory) can ride on top as a thin line.
DwcWidget {
    id: root

    readonly property int ms: root.opt("interval", 2) * 1000
    readonly property string s2: root.opt("series2", "temp")
    readonly property string design: root.opt("design", "bars")
    readonly property bool showLabel: root.opt("label", true)

    DwcNeed { source: "cpu"; interval: root.ms }
    DwcNeed { source: "temp"; interval: Math.max(root.ms, 3000); enabled: root.s2 === "temp" }
    DwcNeed { source: "mem"; interval: root.ms; enabled: root.s2 === "mem" }

    // Auto: the graph is scaled to the highest recent sample (at least 10 %), so
    // a quiet machine still draws something readable; Fixed is always 0–100.
    readonly property bool autoScale: root.opt("scale", "auto") === "auto"
    readonly property real peak: {
        if (!root.autoScale)
            return 1;
        var m = 0.1;
        for (var i = 0; i < DwcData.cpuHistory.length; i++)
            m = Math.max(m, DwcData.cpuHistory[i]);
        return Math.min(1, m * 1.25);
    }
    readonly property var scaled: DwcData.cpuHistory.map(function (v) { return v / root.peak; })

    readonly property int fontPx: Math.max(11, Math.min(18, Math.round(root.height * 0.11)))

    // A history (0..1 values) as points across w × h, newest at the right edge.
    function line(hist, w, h, close) {
        var n = hist.length;
        var out = [];
        var dx = w / 59;
        if (n < 2) {
            out.push(Qt.point(0, h));
            out.push(Qt.point(w, h));
        } else {
            for (var i = 0; i < n; i++) {
                var v = Math.max(0, Math.min(1, hist[i]));
                out.push(Qt.point(w - (n - 1 - i) * dx, h - v * h));
            }
        }
        if (close) {
            out.push(Qt.point(out[out.length - 1].x, h));
            out.push(Qt.point(out[0].x, h));
        }
        return out;
    }

    readonly property var hist2: root.s2 === "temp" ? DwcData.tempHistory.map(function (v) { return v / 100; })
        : root.s2 === "mem" ? DwcData.memHistory : []

    readonly property string value2: root.s2 === "temp" ? (DwcData.tempAvailable ? Math.round(DwcData.temp) + "°" : "–")
        : root.s2 === "mem" ? Math.round(DwcData.memFrac * 100) + "%" : ""

    // ---- heading: what it is, what it is now ----
    Item {
        id: head
        visible: root.showLabel
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: root.showLabel ? root.fontPx * 2 : 0

        DText {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            face: "mono"
            font.pixelSize: Math.round(root.fontPx * 0.85)
            color: DwcTheme.muted
            text: Str.t("w.cpu")
        }
        DText {
            anchors { left: parent.left; leftMargin: Math.round(root.fontPx * 2.4); verticalCenter: parent.verticalCenter }
            face: "display"
            font.pixelSize: Math.round(root.fontPx * 1.7)
            font.weight: Font.DemiBold
            text: Math.round(DwcData.cpuUsage * 100) + "%"
        }
        DText {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            visible: root.value2 !== ""
            face: "mono"
            font.pixelSize: root.fontPx
            color: root.tone("color2")
            text: root.value2
        }
    }

    // ---- the graph, with a scale on the left ----
    Item {
        id: plotArea
        anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom; topMargin: 4 }

        Column {
            id: scaleCol
            visible: root.design === "bars"
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: 24
            DText { width: parent.width; height: parent.height / 2; horizontalAlignment: Text.AlignLeft; verticalAlignment: Text.AlignTop; face: "mono"; font.pixelSize: 9; color: DwcTheme.faint; text: Math.round(root.peak * 100) }
            DText { width: parent.width; height: parent.height / 2; horizontalAlignment: Text.AlignLeft; verticalAlignment: Text.AlignBottom; face: "mono"; font.pixelSize: 9; color: DwcTheme.faint; text: "0" }
        }

        Item {
            id: plot
            anchors { left: root.design === "bars" ? scaleCol.right : parent.left; right: parent.right; top: parent.top; bottom: parent.bottom }

            DBarGraph {
                visible: root.design === "bars"
                anchors.fill: parent
                values: root.scaled
                colorValues: DwcData.cpuHistory
                low: root.tone("color")
                mid: root.tone("color2")
                high: DwcTheme.danger
                gradient: root.opt("gradient", true)
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: -1
                    strokeColor: "transparent"
                    fillColor: root.design === "line" && root.opt("fill", false) ? DwcTheme.alpha(root.tone("color"), 0.16) : "transparent"
                    PathPolyline { path: root.design === "line" ? root.line(root.scaled, plot.width, plot.height, true) : [] }
                }
                ShapePath {
                    strokeWidth: root.design === "line" ? 1.8 : 0
                    strokeColor: root.tone("color")
                    fillColor: "transparent"
                    joinStyle: ShapePath.RoundJoin
                    capStyle: ShapePath.RoundCap
                    PathPolyline { path: root.design === "line" ? root.line(root.scaled, plot.width, plot.height, false) : [] }
                }
                // the second series, a thin line over either style
                ShapePath {
                    strokeWidth: root.s2 === "none" ? 0 : 1.5
                    strokeColor: root.tone("color2")
                    fillColor: "transparent"
                    joinStyle: ShapePath.RoundJoin
                    capStyle: ShapePath.RoundCap
                    PathPolyline { path: root.line(root.hist2, plot.width, plot.height, false) }
                }
            }
        }
    }
}
