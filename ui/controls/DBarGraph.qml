import QtQuick
import ".."

// A history drawn as columns, the way btop does: one bar per sample, newest at
// the right, faint slots where there is no sample yet, and dotted guide lines.
// With `gradient` the bars shift from `low` through `mid` to `high` as the
// value rises, which makes a spike readable at a glance.
Item {
    id: g

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
        if (!g.gradient)
            return g.low;
        if (v < 0.5)
            return DwcTheme.mix(g.mid, g.low, v / 0.5);
        return DwcTheme.mix(g.high, g.mid, (v - 0.5) / 0.5);
    }

    // Guide lines at 25, 50 and 75 %.
    Repeater {
        model: g.guides ? 3 : 0
        delegate: Rectangle {
            required property int index
            width: g.width
            height: 1
            y: g.flip ? g.height * (index + 1) / 4 : g.height * (3 - index) / 4
            color: DwcTheme.alpha(DwcTheme.fg, 0.07)
        }
    }

    Repeater {
        model: g.slots
        delegate: Rectangle {
            required property int index
            readonly property real v: g.valueAt(index)

            x: index * (g.barW + g.gap)
            width: g.barW
            height: v < 0 ? 2 : Math.max(2, v * g.height)
            y: g.flip ? 0 : g.height - height
            radius: Math.min(g.barW / 2, 1.5)
            color: v < 0 ? DwcTheme.alpha(DwcTheme.fg, 0.10) : g.tone(g.colorAt(index))
        }
    }
}
