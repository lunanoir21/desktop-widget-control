import QtQuick
import Quickshell.Io
import ".."
import "../controls"

// Several time zones at once. The zone names are handed to `date` as
// separate arguments (never spliced into a shell string), after being
// limited to the characters a zone name can contain.
DwcWidget {
    id: root

    readonly property bool h12: root.opt("format", "24") === "12"

    DwcNeed { source: "clock"; interval: 60000 }

    readonly property var zones: {
        var raw = String(root.opt("zones", "")).split(",");
        var out = [];
        for (var i = 0; i < raw.length && out.length < 4; i++) {
            var z = raw[i].trim();
            if (/^[A-Za-z0-9_+\-\/]{1,40}$/.test(z) && z.indexOf("..") < 0)
                out.push(z);
        }
        return out;
    }

    // [{ zone, city, hh, mm, off (minutes from UTC), day }]
    property var rows: []

    readonly property int minuteKey: DwcData.now.getHours() * 60 + DwcData.now.getMinutes()
    onMinuteKeyChanged: root.refresh()
    onZonesChanged: root.refresh()
    Component.onCompleted: root.refresh()

    function refresh() {
        if (root.zones.length === 0) {
            root.rows = [];
            return;
        }
        proc.command = ["sh", "-c", 'for z in "$@"; do TZ="$z" date +"%H:%M %z %a"; done', "sh"].concat(root.zones);
        proc.running = true;
    }

    function city(z) {
        var last = z.split("/").pop();
        return last.replace(/_/g, " ");
    }

    function offsetText(diffMin) {
        if (diffMin === 0)
            return "";
        var sign = diffMin > 0 ? "+" : "−";
        var a = Math.abs(diffMin);
        var h = Math.floor(a / 60);
        var m = a % 60;
        return sign + h + (m ? ":" + (m < 10 ? "0" : "") + m : "");
    }

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                var local = -new Date().getTimezoneOffset();
                var out = [];
                for (var i = 0; i < lines.length && i < root.zones.length; i++) {
                    var m = lines[i].match(/^(\d\d):(\d\d) ([+-])(\d\d)(\d\d) (\S+)/);
                    if (!m)
                        continue;
                    var off = (m[3] === "-" ? -1 : 1) * (Number(m[4]) * 60 + Number(m[5]));
                    var hh = Number(m[1]);
                    var label = m[1] + ":" + m[2];
                    if (root.h12)
                        label = ((hh % 12) || 12) + ":" + m[2] + (hh < 12 ? " AM" : " PM");
                    out.push({ city: root.city(root.zones[i]), time: label, diff: root.offsetText(off - local), day: m[6] });
                }
                root.rows = out;
            }
        }
    }

    // Re-render the labels when the 12/24 switch flips.
    onH12Changed: root.refresh()

    readonly property real rowH: root.rows.length > 0 ? root.height / root.rows.length : root.height

    Column {
        anchors.fill: parent
        visible: root.rows.length > 0

        Repeater {
            model: root.rows
            delegate: Item {
                required property var modelData
                required property int index
                width: root.width
                height: root.rowH

                DText {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    width: parent.width * 0.5
                    face: "mono"
                    font.pixelSize: Math.max(11, Math.min(15, Math.round(root.rowH * 0.3)))
                    color: index === 0 ? root.tone("color") : DwcTheme.sub
                    text: modelData.city + (modelData.diff !== "" ? " · " + modelData.diff : "")
                }
                DText {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    face: "mono"
                    font.pixelSize: Math.max(14, Math.min(34, Math.round(root.rowH * (index === 0 ? 0.6 : 0.46))))
                    color: index === 0 ? DwcTheme.fg : DwcTheme.sub
                    text: modelData.time
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
