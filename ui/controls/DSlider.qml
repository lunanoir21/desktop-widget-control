import QtQuick
import ".."

// A slider with a value read-out. Emits moved(value) while dragging and when
// clicked; the owner stores it and feeds it back through `value`.
Item {
    id: root

    property real from: 0
    property real to: 1
    property real step: 0.05
    property real value: 0
    property string unit: ""
    property int decimals: step < 1 ? (step < 0.1 ? 2 : 1) : 0

    signal moved(real value)

    implicitWidth: 170
    implicitHeight: 24

    readonly property real frac: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0

    function at(px) {
        var f = Math.max(0, Math.min(1, px / track.width));
        var v = from + f * (to - from);
        v = Math.round(v / step) * step;
        return Math.max(from, Math.min(to, Number(v.toFixed(4))));
    }

    Item {
        id: track
        anchors { left: parent.left; right: readout.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
        height: 20

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: 2
            color: DwcTheme.alt
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * root.frac
            height: 4
            radius: 2
            color: DwcTheme.acc
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: parent.width * root.frac - width / 2
            width: 14
            height: 14
            radius: 7
            color: DwcTheme.fg
            border.width: drag.pressed ? 3 : 0
            border.color: DwcTheme.alpha(DwcTheme.acc, 0.5)
        }

        MouseArea {
            id: drag
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => root.moved(root.at(mouse.x))
            onPositionChanged: mouse => { if (pressed) root.moved(root.at(mouse.x)) }
        }
    }

    DText {
        id: readout
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: 44
        horizontalAlignment: Text.AlignRight
        face: "mono"
        font.pixelSize: 11
        color: DwcTheme.sub
        text: Number(root.value).toFixed(root.decimals) + root.unit
    }
}
