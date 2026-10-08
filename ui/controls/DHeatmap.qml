import QtQuick
import ".."
import "../js/Github.js" as Github

// A contribution calendar: columns of seven days, Sunday at the top, the newest
// week at the right, as many weeks as fit. The squares are as large as the height
// allows (at most `maxCell`), then the width decides how many weeks are shown.
// Level 0 is a faint square; levels 1 to 4 are `color` at rising strength.
Item {
    id: root

    property var days: []                 // [{ date, level, count }] in date order
    property color color: DwcTheme.acc
    property real maxCell: 12
    property real gap: 2
    // The nearest ancestor with a `family` (a DwcWidget) decides the look.
    property string family: "std"

    Component.onCompleted: {
        var p = root.parent;
        while (p && p.family === undefined)
            p = p.parent;
        if (p)
            root.family = Qt.binding(function () { return p.family; });
    }

    readonly property real cell: Math.max(3, Math.min(root.maxCell, (root.height - 6 * root.gap) / 7))
    readonly property real pitch: root.cell + root.gap
    readonly property int fit: Math.max(1, Math.floor((root.width + root.gap) / root.pitch))
    readonly property var weeks: Github.weeksOf(root.days, root.fit)
    // the grid is placed against the right edge so the newest week is always at the right
    readonly property real gridW: root.weeks.length * root.pitch - root.gap

    readonly property var strength: [0.08, 0.3, 0.52, 0.76, 1]

    Repeater {
        model: root.weeks.length * 7
        delegate: Rectangle {
            required property int index
            readonly property var day: root.weeks[Math.floor(index / 7)][index % 7] || null
            visible: day !== null
            x: root.width - root.gridW + Math.floor(index / 7) * root.pitch
            y: (index % 7) * root.pitch
            width: root.cell
            height: root.cell
            // standard: soft squares; dots: round; mono, terminal and poster: sharp squares
            radius: root.family === "std" ? Math.max(1, root.cell * 0.22) : root.family === "dots" ? root.cell / 2 : 0
            // mono draws the empty days as outlines and the busy ones in the text colour
            color: day === null ? "transparent"
                : day.level === 0 ? (root.family === "mono" ? "transparent" : DwcTheme.alpha(DwcTheme.fg, root.family === "dots" ? 0.13 : root.strength[0]))
                : Qt.alpha(root.family === "mono" ? DwcTheme.fg : root.color, root.strength[day.level])
            border.width: root.family === "mono" && day !== null && day.level === 0 ? 1 : 0
            border.color: DwcTheme.alpha(DwcTheme.fg, 0.16)
        }
    }
}
