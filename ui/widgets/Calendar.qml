import QtQuick
import ".."
import "../controls"
import "../js/Dates.js" as Dates

// A month grid. Large: the whole card; medium: today's date on the left and a
// compact grid on the right.
DwcWidget {
    id: root

    DwcNeed { source: "clock"; interval: 60000 }

    readonly property bool mondayFirst: root.opt("firstDay", "mon") === "mon"
    readonly property bool weeks: root.opt("weeks", false)
    readonly property bool wide: !root.small && root.rows < 8     // medium: side panel + grid

    readonly property int year: DwcData.now.getFullYear()
    readonly property int month: DwcData.now.getMonth()
    readonly property int today: DwcData.now.getDate()


    // 42 cells: { n, inMonth, isToday }
    readonly property var cells: {
        var first = new Date(root.year, root.month, 1);
        var offset = root.mondayFirst ? (first.getDay() + 6) % 7 : first.getDay();
        var out = [];
        for (var i = 0; i < 42; i++) {
            var d = new Date(root.year, root.month, 1 - offset + i);
            out.push({ n: d.getDate(), inMonth: d.getMonth() === root.month,
                       isToday: d.getMonth() === root.month && d.getDate() === root.today,
                       week: Dates.isoWeek(d) });
        }
        return out;
    }

    // Weekday initials in the chosen language, starting on the configured day.
    readonly property var heads: {
        var out = [];
        for (var i = 0; i < 7; i++) {
            var day = (root.mondayFirst ? i + 1 : i) % 7;
            out.push(Str.locale.dayName(day, Locale.NarrowFormat).toUpperCase());
        }
        return out;
    }

    readonly property int cols: root.weeks ? 8 : 7
    readonly property real gridX: root.wide ? Math.round(root.width * 0.4) : 0
    readonly property real gridW: root.width - gridX
    readonly property real headH: root.wide ? 0 : Math.round(root.height * 0.11)
    readonly property real gridH: root.height - headH
    readonly property real cw: gridW / cols
    readonly property real ch: gridH / 7

    // ---- heading (large) / date panel (medium) ----
    DText {
        visible: !root.wide
        x: 0
        y: 0
        width: root.width
        height: root.headH
        face: "display"
        font.pixelSize: Math.round(root.headH * 0.78)
        font.weight: Font.DemiBold
        text: Str.fmt("MMMM yyyy", DwcData.now)
    }

    Column {
        visible: root.wide
        x: 0
        width: root.gridX - 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        DText {
            width: parent.width
            face: "display"
            font.pixelSize: Math.round(root.height * 0.42)
            font.weight: Font.DemiBold
            color: root.tone("color")
            text: root.today
        }
        DText {
            width: parent.width
            font.pixelSize: Math.round(root.height * 0.11)
            font.weight: Font.Medium
            text: Str.fmt("dddd", DwcData.now)
        }
        DText {
            width: parent.width
            font.pixelSize: Math.round(root.height * 0.09)
            color: DwcTheme.muted
            text: Str.fmt("MMMM yyyy", DwcData.now)
        }
    }

    // ---- grid ----
    Item {
        x: root.gridX
        y: root.headH
        width: root.gridW
        height: root.gridH

        Repeater {
            model: root.cols
            delegate: DText {
                required property int index
                readonly property int col: root.weeks ? index - 1 : index
                visible: col >= 0
                x: index * root.cw
                y: 0
                width: root.cw
                height: root.ch
                horizontalAlignment: Text.AlignHCenter
                face: "mono"
                font.pixelSize: Math.max(9, Math.min(12, Math.round(root.ch * 0.42)))
                color: DwcTheme.muted
                text: col >= 0 ? root.heads[col] : ""
            }
        }

        Repeater {
            model: root.cells
            delegate: Item {
                required property var modelData
                required property int index
                readonly property int row: Math.floor(index / 7)
                readonly property int col: index % 7 + (root.weeks ? 1 : 0)

                x: col * root.cw
                y: (row + 1) * root.ch
                width: root.cw
                height: root.ch

                Rectangle {
                    visible: modelData.isToday
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height) - 2
                    height: width
                    radius: width / 2
                    color: root.tone("color")
                }
                DText {
                    anchors.fill: parent
                    horizontalAlignment: Text.AlignHCenter
                    face: "mono"
                    font.pixelSize: Math.max(10, Math.min(14, Math.round(root.ch * 0.46)))
                    color: modelData.isToday ? DwcTheme.onAcc : (modelData.inMonth ? DwcTheme.fg : DwcTheme.faint)
                    text: modelData.n
                }
                // Week number at the start of each row.
                DText {
                    visible: root.weeks && index % 7 === 0
                    x: -root.cw
                    width: root.cw
                    height: parent.height
                    horizontalAlignment: Text.AlignHCenter
                    face: "mono"
                    font.pixelSize: Math.max(9, Math.min(11, Math.round(root.ch * 0.38)))
                    color: DwcTheme.muted
                    text: modelData.week
                }
            }
        }
    }
}
