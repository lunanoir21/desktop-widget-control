import QtQuick
import ".."
import "../controls"

// A checklist. Lines look like "- [ ] thing" / "- [x] done thing"; any other
// line is plain text. Ticking a box on the desktop rewrites that one line in
// the saved options; adding and editing lines happens in the editor.
DwcWidget {
    id: root

    readonly property string text: String(root.opt("lines", ""))

    // [{ line, kind: "todo" | "done" | "text", label }]
    readonly property var entries: {
        var lines = root.text.split("\n");
        var out = [];
        for (var i = 0; i < lines.length && i < 300; i++) {   // a checklist, not a document: never build more rows than this
            var m = lines[i].match(/^\s*[-*]\s*\[( |x|X)\]\s?(.*)$/);
            if (m)
                out.push({ line: i, kind: m[1] === " " ? "todo" : "done", label: m[2] });
            else if (lines[i].trim() !== "")
                out.push({ line: i, kind: "text", label: lines[i].trim() });
        }
        return out;
    }

    function toggle(line) {
        if (root.preview || root.wid === "")
            return;
        var lines = root.text.split("\n");
        lines[line] = lines[line].replace(/\[( |x|X)\]/, function (all, mark) { return mark === " " ? "[x]" : "[ ]"; });
        DwcStore.setCfg(root.wid, "lines", lines.join("\n"));
    }

    readonly property int rowH: 26
    // mono and poster draw the box as a plain square; everything else rounds it
    readonly property bool squareBox: family === "mono" || family === "poster"

    DText {
        id: title
        visible: String(root.opt("title", "")) !== ""
        width: parent.width
        face: "display"
        font.pixelSize: 14
        font.weight: Font.DemiBold
        color: root.tone("color")
        text: String(root.opt("title", ""))
    }

    Column {
        anchors { top: title.visible ? title.bottom : parent.top; topMargin: title.visible ? 8 : 0; left: parent.left; right: parent.right; bottom: parent.bottom }
        clip: true

        Repeater {
            model: root.entries
            delegate: Item {
                required property var modelData
                width: parent.width
                height: root.rowH

                Rectangle {
                    id: box
                    readonly property bool done: modelData.kind === "done"
                    // terminal spells the mark out in text instead of drawing a box
                    visible: modelData.kind !== "text" && root.family !== "term"
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    width: 15
                    height: 15
                    radius: root.family === "std" ? 4 : (root.family === "dots" ? width / 2 : 0)
                    color: box.done ? (root.squareBox ? DwcTheme.fg : root.tone("color")) : "transparent"
                    border.width: box.done ? 0 : (root.squareBox ? 1 : 1.5)
                    border.color: root.squareBox ? DwcTheme.alpha(DwcTheme.fg, 0.3) : DwcTheme.muted
                    DIcon { visible: box.done && root.family === "std"; anchors.centerIn: parent; name: "check"; size: 11; strokeWidth: 2.2; color: DwcTheme.onAcc }
                }
                DText {
                    id: mark
                    visible: modelData.kind !== "text" && root.family === "term"
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    face: "mono"
                    font.pixelSize: 13
                    color: modelData.kind === "done" ? root.tone("color") : DwcTheme.muted
                    text: modelData.kind === "done" ? "[x]" : "[ ]"
                }
                DText {
                    anchors { left: box.visible ? box.right : mark.visible ? mark.right : parent.left; leftMargin: box.visible || mark.visible ? 10 : 0; right: parent.right; verticalCenter: parent.verticalCenter }
                    font.pixelSize: 13
                    font.strikeout: modelData.kind === "done"
                    color: modelData.kind === "done" ? DwcTheme.muted : DwcTheme.fg
                    text: modelData.label
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: modelData.kind !== "text" && !root.preview
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggle(modelData.line)
                }
            }
        }
    }
}
