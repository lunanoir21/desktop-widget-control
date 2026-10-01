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
                    visible: modelData.kind !== "text"
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    width: 15
                    height: 15
                    radius: 4
                    color: modelData.kind === "done" ? root.tone("color") : "transparent"
                    border.width: modelData.kind === "done" ? 0 : 1.5
                    border.color: DwcTheme.muted
                    DIcon { visible: modelData.kind === "done"; anchors.centerIn: parent; name: "check"; size: 11; strokeWidth: 2.2; color: DwcTheme.onAcc }
                }
                DText {
                    anchors { left: box.visible ? box.right : parent.left; leftMargin: box.visible ? 10 : 0; right: parent.right; verticalCenter: parent.verticalCenter }
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
