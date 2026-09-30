import QtQuick
import "controls"
import "js/Layout.js" as Layout
import "js/Modules.js" as Modules

// One module in the library: a live thumbnail (the real widget at its
// default size and options, scaled down) with its name and the sizes it has.
Rectangle {
    id: card

    required property var module
    required property var editor

    readonly property var dims: Layout.preset(module.size)
    readonly property real naturalW: dims.w * DwcStore.cell
    readonly property real naturalH: dims.h * DwcStore.cell
    readonly property real thumbW: width - 16
    readonly property real thumbH: 88
    readonly property real fit: Math.min(thumbW / naturalW, thumbH / naturalH)

    height: 8 + thumbH + 8 + label.implicitHeight + 2 + sizes.implicitHeight + 10
    radius: 14
    color: mouse.containsMouse ? DwcTheme.alt : DwcTheme.alpha(DwcTheme.alt, 0.6)
    border.width: 1
    border.color: mouse.containsMouse ? DwcTheme.lineStrong : DwcTheme.line

    Behavior on color { ColorAnimation { duration: 110 } }

    // The thumbnail: a dark stage so a translucent card still reads on any theme.
    Rectangle {
        x: 8
        y: 8
        width: card.thumbW
        height: card.thumbH
        radius: 9
        color: DwcTheme.dark ? Qt.rgba(0, 0, 0, 0.35) : Qt.rgba(0.2, 0.2, 0.25, 0.22)
        clip: true

        DwcCard {
            x: (parent.width - card.naturalW * card.fit) / 2
            y: (parent.height - card.naturalH * card.fit) / 2
            scale: card.fit
            transformOrigin: Item.TopLeft
            type: card.module.type
            sizeKey: card.module.size
            cfg: Modules.cfgDefaults(card.module.type)
            st: ({ background: true, bgOpacity: 0.9, radius: 16, padding: 14, shadow: false, border: false })
            preview: true
        }
    }

    DText {
        id: label
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 10; rightMargin: 10; topMargin: 8 + card.thumbH + 8 }
        font.weight: Font.Medium
        text: Str.pick(card.module.name)
    }
    DText {
        id: sizes
        anchors { left: parent.left; right: parent.right; top: label.bottom; leftMargin: 10; rightMargin: 10; topMargin: 2 }
        face: "mono"
        font.pixelSize: 10
        color: DwcTheme.muted
        text: card.module.sizes.join(" · ")
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.OpenHandCursor

        property point press: Qt.point(0, 0)
        property bool dragging: false

        onPressed: m => {
            press = Qt.point(m.x, m.y);
            dragging = false;
        }
        onPositionChanged: m => {
            if (!pressed)
                return;
            if (!dragging && Math.hypot(m.x - press.x, m.y - press.y) > 8) {
                dragging = true;
                card.editor.beginDrag(card.module.type, card.module.size);
            }
            if (dragging)
                card.editor.moveDrag(mapToItem(card.editor, m.x, m.y));
        }
        onReleased: {
            if (dragging)
                card.editor.endDrag();
            dragging = false;
        }
        onCanceled: {
            if (dragging)
                card.editor.cancelDrag();
            dragging = false;
        }
        onDoubleClicked: card.editor.quickAdd(card.module.type)
    }
}
