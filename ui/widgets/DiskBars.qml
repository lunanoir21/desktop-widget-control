import QtQuick
import ".."
import "../controls"

// One bar per mount point; a bar turns to the warning colour past the threshold.
DwcWidget {
    id: root

    DwcNeed { source: "disk"; interval: 60000 }

    readonly property real warn: root.opt("warn", 85) / 100

    readonly property var wanted: {
        var raw = String(root.opt("mounts", "/")).split(",");
        var out = [];
        for (var i = 0; i < raw.length; i++) {
            var t = raw[i].trim();
            if (t !== "")
                out.push(t);
        }
        return out.length ? out : ["/"];
    }

    readonly property var rows: {
        var out = [];
        for (var i = 0; i < root.wanted.length; i++)
            for (var j = 0; j < DwcData.disks.length; j++)
                if (DwcData.disks[j].target === root.wanted[i]) {
                    out.push(DwcData.disks[j]);
                    break;
                }
        return out;
    }

    readonly property real rowH: Math.max(34, Math.min(56, root.height / Math.max(1, Math.min(rows.length, 4))))

    Column {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        spacing: Math.round(root.height * 0.08)

        Repeater {
            model: root.rows.slice(0, Math.max(1, Math.floor(root.height / root.rowH)))
            delegate: Item {
                required property var modelData
                readonly property real frac: modelData.size > 0 ? modelData.used / modelData.size : 0

                width: root.width
                height: root.rowH - Math.round(root.height * 0.08)

                DText {
                    anchors { left: parent.left; top: parent.top }
                    width: parent.width * 0.4
                    face: "mono"
                    font.pixelSize: 12
                    text: modelData.target
                }
                DText {
                    anchors { right: parent.right; top: parent.top }
                    width: parent.width * 0.6
                    horizontalAlignment: Text.AlignRight
                    face: "mono"
                    font.pixelSize: 12
                    color: DwcTheme.sub
                    text: root.small ? Math.round(parent.frac * 100) + "%"
                        : DwcData.bytes(modelData.used, 0) + " / " + DwcData.bytes(modelData.size, 0)
                }
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 6
                    radius: 3
                    color: DwcTheme.track
                    Rectangle {
                        width: Math.max(6, parent.width * parent.parent.frac)
                        height: parent.height
                        radius: 3
                        color: parent.parent.frac > root.warn ? DwcTheme.danger : root.tone("color")
                    }
                }
            }
        }
    }

    DText {
        visible: root.rows.length === 0
        anchors.centerIn: parent
        color: DwcTheme.muted
        text: Str.t("w.loading")
    }
}
