import QtQuick
import "controls"
import "js/Layout.js" as Layout
import "js/Modules.js" as Modules

// The editor's hold on one widget: an outline over it that selects, drags
// (snapping to cells, refusing a spot that is taken) and resizes from the
// bottom-right corner by stepping through the sizes the module allows. The
// widget itself is drawn by the desktop layer underneath.
Item {
    id: handle

    required property string wid
    required property var editor

    readonly property var rec: DwcStore.items[wid] || null
    readonly property var module: rec ? Modules.byType(rec.type) : null
    readonly property var dims: rec ? Layout.preset(rec.size) : ({ w: 1, h: 1 })
    readonly property bool selected: DwcStore.selected === wid
    readonly property bool locked: rec ? rec.locked : false
    readonly property real inset: Math.max(2, Math.round(DwcStore.cell * 0.1))

    x: rec ? rec.x * DwcStore.cell : 0
    y: rec ? rec.y * DwcStore.cell : 0
    width: dims.w * DwcStore.cell
    height: dims.h * DwcStore.cell

    Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Rectangle {
        id: outline
        x: handle.inset
        y: handle.inset
        width: handle.width - handle.inset * 2
        height: handle.height - handle.inset * 2
        radius: 16
        color: body.containsMouse && !handle.selected ? DwcTheme.alpha(DwcTheme.fg, 0.05) : "transparent"
        border.width: handle.selected ? 2 : 1
        border.color: handle.selected ? DwcTheme.acc : (body.containsMouse ? DwcTheme.lineStrong : DwcTheme.alpha("#ffffff", 0.32))
        opacity: body.drag ? 0.9 : 1
    }

    // Name tag while hovered or selected.
    Rectangle {
        visible: handle.selected || body.containsMouse
        x: handle.inset
        y: handle.inset - height - 4
        height: 22
        width: tag.implicitWidth + (handle.locked ? 38 : 20)
        radius: 11
        color: handle.selected ? DwcTheme.acc : DwcTheme.card
        border.width: handle.selected ? 0 : 1
        border.color: DwcTheme.line

        Row {
            anchors.centerIn: parent
            spacing: 5
            DIcon { visible: handle.locked; anchors.verticalCenter: parent.verticalCenter; name: "lock"; size: 11; color: handle.selected ? DwcTheme.onAcc : DwcTheme.sub }
            DText {
                id: tag
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 10
                font.weight: Font.Medium
                color: handle.selected ? DwcTheme.onAcc : DwcTheme.sub
                text: handle.module ? Str.pick(handle.module.name) : ""
            }
        }
    }

    MouseArea {
        id: body
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: handle.locked ? Qt.ArrowCursor : (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor)

        property point grab: Qt.point(0, 0)      // pointer in editor coordinates
        property int startX: 0
        property int startY: 0
        readonly property bool drag: pressed && !handle.locked

        onPressed: m => {
            DwcStore.select(handle.wid);
            grab = mapToItem(handle.editor, m.x, m.y);
            startX = handle.rec.x;
            startY = handle.rec.y;
        }
        onReleased: handle.editor.busy = false
        onCanceled: handle.editor.busy = false
        onPositionChanged: m => {
            if (!pressed || handle.locked)
                return;
            var p = mapToItem(handle.editor, m.x, m.y);
            // A real drag (not a click) sends the panels out of the way.
            if (Math.hypot(p.x - grab.x, p.y - grab.y) > 6)
                handle.editor.busy = true;
            var dx = Math.round((p.x - grab.x) / DwcStore.cell);
            var dy = Math.round((p.y - grab.y) / DwcStore.cell);
            DwcStore.move(handle.wid, startX + dx, startY + dy);
        }
    }

    // Resize grip.
    Rectangle {
        visible: handle.selected && !handle.locked && handle.module && handle.module.sizes.length > 1
        x: handle.width - handle.inset - width / 2
        y: handle.height - handle.inset - height / 2
        width: 16
        height: 16
        radius: 8
        color: DwcTheme.acc
        border.width: 3
        border.color: DwcTheme.card

        MouseArea {
            anchors { fill: parent; margins: -6 }
            cursorShape: Qt.SizeFDiagCursor
            preventStealing: true
            onReleased: handle.editor.busy = false
            onCanceled: handle.editor.busy = false
            onPositionChanged: m => {
                if (!pressed)
                    return;
                handle.editor.busy = true;
                var p = mapToItem(handle.editor, m.x, m.y);
                var cols = Math.max(1, Math.round((p.x - handle.x) / DwcStore.cell));
                var rows = Math.max(1, Math.round((p.y - handle.y) / DwcStore.cell));
                var pick = Layout.nearestPreset(handle.module.sizes, cols, rows);
                if (pick !== handle.rec.size)
                    DwcStore.setSize(handle.wid, pick);
            }
        }
    }
}
