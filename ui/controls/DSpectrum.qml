import QtQuick
import ".."

// A soft spectrum for the back of a card: columns rising from the bottom edge,
// barely there when quiet and brighter as the level climbs. It draws nothing
// without audio, so a paused player leaves a clean card.
Item {
    id: s

    property var values: []               // cava bands, 0..1
    property bool live: false
    property color color: DwcTheme.acc
    property real barWidth: 6
    property real gap: 3
    property real strength: 0.26          // alpha of the tallest bars

    readonly property int count: Math.max(6, Math.floor((width + gap) / (barWidth + gap)))
    readonly property real step: (width - barWidth) / Math.max(1, s.count - 1)

    function level(i) {
        var n = s.values.length;
        if (!s.live || n === 0)
            return 0;
        var k = Math.min(n - 1, Math.floor(i * n / s.count));
        var a = s.values[Math.max(0, k - 1)];
        var b = s.values[k];
        var c = s.values[Math.min(n - 1, k + 1)];
        return Math.max(0, Math.min(1, (a + 2 * b + c) / 4));
    }

    Repeater {
        model: s.count
        delegate: Rectangle {
            required property int index
            readonly property real lv: s.level(index)

            x: index * s.step
            width: s.barWidth
            height: lv * s.height
            y: s.height - height
            radius: Math.min(width / 2, 3)
            color: Qt.rgba(s.color.r, s.color.g, s.color.b, 0.05 + s.strength * lv)
            visible: height > 1

            Behavior on height { NumberAnimation { duration: 80 } }
        }
    }
}
