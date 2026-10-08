import QtQuick
import ".."

// A horizontal bar that fills with `value` (0..1), in the look of the widget it sits
// in: a rounded track (standard), an outlined box (mono), dots (dots), blocks
// (terminal) or a hairline (poster). Its height is the thickness; the caller sets it.
// In the mono look the fill is the text colour, unless `keepColor` is set (a warning
// colour should still read as one).
Item {
    id: root

    property real value: 0
    property color color: DwcTheme.acc
    property bool keepColor: false
    // The nearest ancestor with a `family` (a DwcWidget) decides the look.
    property string family: "std"

    Component.onCompleted: {
        var p = root.parent;
        while (p && p.family === undefined)
            p = p.parent;
        if (p)
            root.family = Qt.binding(function () { return p.family; });
    }

    readonly property real v: Math.max(0, Math.min(1, root.value))
    readonly property color fillColor: family === "mono" && !keepColor ? DwcTheme.fg : root.color
    implicitHeight: 6

    // standard, mono, poster: a track and a fill
    Rectangle {
        visible: root.family === "std" || root.family === "mono" || root.family === "poster"
        anchors.fill: parent
        radius: root.family === "std" ? height / 2 : 0
        color: root.family === "std" ? DwcTheme.track : (root.family === "poster" ? DwcTheme.alpha(DwcTheme.fg, 0.14) : "transparent")
        border.width: root.family === "mono" ? 1 : 0
        border.color: DwcTheme.alpha(DwcTheme.fg, 0.3)

        Rectangle {
            width: parent.width * root.v
            height: root.family === "poster" ? Math.min(parent.height, 3) : parent.height
            anchors.verticalCenter: parent.verticalCenter
            radius: parent.radius
            color: root.fillColor
        }
    }

    // dots and terminal: a row of cells, lit up to the value
    Row {
        visible: root.family === "dots" || root.family === "term"
        readonly property real d: root.family === "dots" ? Math.max(3, root.height) : Math.max(4, root.height * 0.7)
        readonly property real gap: root.family === "dots" ? 2 : 1
        readonly property int n: Math.max(1, Math.floor((root.width + gap) / (d + gap)))
        spacing: gap
        anchors.verticalCenter: parent.verticalCenter
        Repeater {
            // the cells are only built in the two looks that show them
            model: parent.visible ? parent.n : 0
            delegate: Rectangle {
                required property int index
                width: parent.d
                height: root.family === "dots" ? parent.d : root.height
                radius: root.family === "dots" ? width / 2 : 0
                color: index < Math.round(root.v * parent.n) ? root.color : DwcTheme.alpha(DwcTheme.fg, root.family === "dots" ? 0.13 : 0.10)
            }
        }
    }
}
