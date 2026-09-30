import QtQuick
import ".."

// The progress bar and the live audio level in one: a row of bars centred on a
// line, the played part in `color` and the rest faint, each bar as tall as the
// matching band of the spectrum. With no audio the bars rest at `minH`, which
// reads as an ordinary segmented progress bar, so a paused player loses nothing.
Item {
    id: w

    property var values: []               // cava bands, 0..1
    property bool live: false
    property real progress: 0             // 0..1
    property color color: DwcTheme.acc
    property real barWidth: 3
    property real gap: 2
    property real minH: 3

    readonly property int count: Math.max(8, Math.floor((width + gap) / (barWidth + gap)))
    readonly property real step: (width - barWidth) / Math.max(1, count - 1)

    // The band under bar i, softened with its neighbours so the row moves as one line.
    function level(i) {
        var n = w.values.length;
        if (!w.live || n === 0)
            return 0;
        var k = Math.min(n - 1, Math.floor(i * n / w.count));
        var a = w.values[Math.max(0, k - 1)];
        var b = w.values[k];
        var c = w.values[Math.min(n - 1, k + 1)];
        return Math.max(0, Math.min(1, (a + 2 * b + c) / 4));
    }

    Repeater {
        model: w.count
        delegate: Rectangle {
            required property int index
            readonly property real lv: w.level(index)
            readonly property bool played: (index + 0.5) / w.count <= w.progress

            x: index * w.step
            width: w.barWidth
            height: w.minH + lv * (w.height - w.minH)
            y: (w.height - height) / 2
            radius: width / 2
            color: played ? w.color : DwcTheme.alpha(DwcTheme.fg, 0.2)

            Behavior on height { NumberAnimation { duration: 70 } }
        }
    }
}
