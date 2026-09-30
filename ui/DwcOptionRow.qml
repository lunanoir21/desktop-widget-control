import QtQuick
import "controls"

// One option of the inspector, made from its schema in js/Modules.js: a label
// and the control for its type. `value` goes in, changed(value) comes out; the
// owner stores it and feeds it back, so the control always shows what is saved.
Item {
    id: row

    property var opt: ({})
    property var value: null

    signal changed(var value)

    readonly property bool stacked: opt.type === "color" || opt.type === "text" || opt.type === "lines" || opt.type === "place"

    width: parent ? parent.width : 240
    implicitHeight: stacked ? stackCol.implicitHeight + 6 : 34
    height: implicitHeight

    // Choices as { v, label } in the current language.
    readonly property var choices: {
        var out = [];
        var src = row.opt.choices || [];
        for (var i = 0; i < src.length; i++)
            out.push({ v: src[i].v, label: Str.pick(src[i].label) });
        return out;
    }

    // ---- inline: label left, control right ----
    DText {
        visible: !row.stacked
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        text: Str.pick(row.opt.label)
        color: DwcTheme.sub
    }

    Loader {
        visible: !row.stacked
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        sourceComponent: row.opt.type === "toggle" ? toggleC
            : row.opt.type === "select" ? selectC
            : row.opt.type === "range" ? rangeC : null
    }

    // ---- stacked: label on top, control below ----
    Column {
        id: stackCol
        visible: row.stacked
        width: parent.width
        spacing: 6
        DText { text: Str.pick(row.opt.label); color: DwcTheme.sub }
        Loader {
            width: parent.width
            sourceComponent: row.opt.type === "color" ? colorC
                : row.opt.type === "text" ? textC
                : row.opt.type === "lines" ? linesC
                : row.opt.type === "place" ? placeC : null
        }
        DText {
            visible: !!row.opt.hint
            width: parent.width
            font.pixelSize: 10
            color: DwcTheme.muted
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
            text: row.opt.hint ? Str.pick(row.opt.hint) : ""
        }
    }

    Component {
        id: toggleC
        DSwitch { checked: !!row.value; onToggled: v => row.changed(v) }
    }
    Component {
        id: selectC
        DSelect { width: 130; model: row.choices; current: row.value; onPicked: v => row.changed(v) }
    }
    Component {
        id: rangeC
        DSlider {
            width: 170
            from: row.opt.min
            to: row.opt.max
            step: row.opt.step
            unit: row.opt.unit || ""
            value: Number(row.value)
            onMoved: v => row.changed(v)
        }
    }
    Component {
        id: colorC
        DColorPick { current: String(row.value); onPicked: v => row.changed(v) }
    }
    Component {
        id: textC
        DTextField { text: String(row.value === undefined || row.value === null ? "" : row.value); onCommitted: t => row.changed(t) }
    }
    Component {
        id: placeC
        DPlacePicker { value: row.value; onPlacePicked: p => row.changed(p) }
    }
    Component {
        id: linesC
        DTextArea { text: String(row.value === undefined || row.value === null ? "" : row.value); onCommitted: t => row.changed(t) }
    }
}
