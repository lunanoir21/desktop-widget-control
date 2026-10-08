import QtQuick
import ".."

// A history drawn as columns, the way btop does: one bar per sample, newest at
// the right, faint slots where there is no sample yet, and dotted guide lines.
// With `gradient` the bars shift from `low` through `mid` to `high` as the
// value rises, which makes a spike readable at a glance.
//
// The look of the widget it sits in changes how it is drawn: flat grey-scale bars
// (mono), bars in eighth-steps in one colour (terminal), columns of dots (dots) or a
// thin line over a faint area (poster).
Item {
    id: g

    // The nearest ancestor with a `family` (a DwcWidget) decides the look.
    property string family: "std"
    Component.onCompleted: {
        var p = g.parent;
        while (p && p.family === undefined)
            p = p.parent;
        if (p)
            g.family = Qt.binding(function () { return p.family; });
    }
    readonly property bool canvasLook: g.family === "dots" || g.family === "poster"

    property var values: []               // 0..1, newest last
    // What the colour follows, when that differs from the bar height (a graph
    // scaled to its own peak still colours by the real load). Same length as values.
    property var colorValues: null
    property int slots: 60
    property color low: DwcTheme.acc
    property color mid: DwcTheme.acc2
    property color high: DwcTheme.danger
    property bool gradient: true
    property bool flip: false             // grow downward from the top edge
    property bool guides: true
    property real gap: 1

    readonly property real barW: Math.max(1, (width - (slots - 1) * gap) / slots)

    function valueAt(i) {
        var k = g.values.length - g.slots + i;
        return k >= 0 ? Math.max(0, Math.min(1, g.values[k])) : -1;
    }

    function colorAt(i) {
        if (!g.colorValues)
            return g.valueAt(i);
        var k = g.colorValues.length - g.slots + i;
        return k >= 0 ? Math.max(0, Math.min(1, g.colorValues[k])) : -1;
    }

    function tone(v) {
        if (g.family === "mono")
            return DwcTheme.alpha(DwcTheme.fg, 0.3 + 0.7 * v);
        if (g.family === "term")
            return g.low;
        if (!g.gradient)
            return g.low;
        if (v < 0.5)
            return DwcTheme.mix(g.mid, g.low, v / 0.5);
        return DwcTheme.mix(g.high, g.mid, (v - 0.5) / 0.5);
    }

    // Guide lines at 25, 50 and 75 %.
    Repeater {
        model: g.guides && !g.canvasLook && g.family !== "term" ? 3 : 0
        delegate: Rectangle {
            required property int index
            width: g.width
            height: 1
            y: g.flip ? g.height * (index + 1) / 4 : g.height * (3 - index) / 4
            color: DwcTheme.alpha(DwcTheme.fg, 0.07)
        }
    }

    Repeater {
        model: g.canvasLook ? 0 : g.slots
        delegate: Rectangle {
            required property int index
            readonly property real v: g.valueAt(index)
            // the terminal look draws in steps of an eighth, like ▁▂▃▄▅▆▇█
            readonly property real shown: g.family === "term" && v >= 0 ? Math.max(1, Math.ceil(v * 8)) / 8 : v

            x: index * (g.barW + g.gap)
            width: g.barW
            height: v < 0 ? 2 : Math.max(2, shown * g.height)
            y: g.flip ? 0 : g.height - height
            radius: g.family === "std" ? Math.min(g.barW / 2, 1.5) : 0
            color: v < 0 ? DwcTheme.alpha(DwcTheme.fg, 0.10) : g.tone(g.colorAt(index))
        }
    }

    // dots and poster are painted: one pass per change, not hundreds of items
    Canvas {
        id: paint
        anchors.fill: parent
        visible: g.canvasLook
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (!g.canvasLook)
                return;
            var low = g.low;
            if (g.family === "poster") {
                var pts = [];
                for (var i = 0; i < g.slots; i++) {
                    var v = g.valueAt(i);
                    if (v >= 0)
                        pts.push([i / Math.max(1, g.slots - 1) * width, g.flip ? v * height : height - v * height]);
                }
                if (pts.length < 2)
                    return;
                ctx.beginPath();
                ctx.moveTo(pts[0][0], g.flip ? 0 : height);
                for (var a = 0; a < pts.length; a++)
                    ctx.lineTo(pts[a][0], pts[a][1]);
                ctx.lineTo(pts[pts.length - 1][0], g.flip ? 0 : height);
                ctx.closePath();
                ctx.fillStyle = Qt.rgba(low.r, low.g, low.b, 0.16);
                ctx.fill();
                ctx.beginPath();
                ctx.moveTo(pts[0][0], pts[0][1]);
                for (var b = 1; b < pts.length; b++)
                    ctx.lineTo(pts[b][0], pts[b][1]);
                ctx.strokeStyle = Qt.rgba(low.r, low.g, low.b, 1);
                ctx.lineWidth = 1.5;
                ctx.lineJoin = "round";
                ctx.stroke();
                return;
            }
            // dots: a column per sample, a dot per step of height
            var d = Math.max(2.5, Math.min(5, height / 9));
            var pitch = d + 2;
            var cols = Math.max(1, Math.floor(width / pitch));
            var rows = Math.max(1, Math.floor(height / pitch));
            var fg = DwcTheme.fg;
            for (var c = 0; c < cols; c++) {
                var val = g.valueAt(g.slots - cols + c);
                var lit = val < 0 ? 0 : Math.max(1, Math.ceil(val * rows));
                for (var r = 0; r < rows; r++) {
                    var on = r < lit;
                    ctx.fillStyle = on ? Qt.rgba(low.r, low.g, low.b, 1) : Qt.rgba(fg.r, fg.g, fg.b, 0.12);
                    ctx.beginPath();
                    var cy = g.flip ? r * pitch + d / 2 : height - r * pitch - d / 2;
                    ctx.arc(c * pitch + d / 2, cy, d / 2, 0, Math.PI * 2);
                    ctx.fill();
                }
            }
        }
        Connections {
            target: g
            function onValuesChanged() { paint.requestPaint(); }
            function onFamilyChanged() { paint.requestPaint(); }
            function onLowChanged() { paint.requestPaint(); }
            function onWidthChanged() { paint.requestPaint(); }
            function onHeightChanged() { paint.requestPaint(); }
        }
        Component.onCompleted: requestPaint()
    }
}
