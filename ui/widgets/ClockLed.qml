import QtQuick
import ".."
import "../controls"
import "../js/Dates.js" as Dates
import "../js/Geometry.js" as Geometry

// Dot-matrix clock in three styles (the Style option):
//   classic  the time with the date under it
//   ring     the same, inside a dotted ring that fills as the seconds pass
//   strip    time on the left, the week's days beside it, the day's 24 hours below
DwcWidget {
    id: root

    readonly property string design: root.opt("design", "classic")
    readonly property bool secs: root.opt("seconds", false)
    readonly property bool ringSeconds: root.design === "ring" && root.opt("ringOf", "seconds") === "seconds"
    readonly property bool h12: root.opt("format", "24") === "12"
    readonly property string dateMode: root.design === "strip" ? "none" : root.opt("date", "short")

    // Seconds are only ticked when something on screen shows them.
    DwcNeed { source: (root.secs || root.ringSeconds) ? "clock.sec" : "clock"; interval: 1000 }

    readonly property string timeText: {
        var f = root.h12 ? (root.secs ? "h:mm:ss AP" : "h:mm AP") : (root.secs ? "HH:mm:ss" : "HH:mm");
        return Str.fmt(f, DwcData.now);
    }
    readonly property string dateText: {
        if (root.dateMode === "short")
            return Str.fmt("ddd dd.MM", DwcData.now).toUpperCase();
        if (root.dateMode === "long")
            return Str.fmt("dddd, d MMMM", DwcData.now).toUpperCase();
        return "";
    }

    // ---- classic and ring: the time with the date under it ----
    Item {
        id: faceBox
        visible: root.design !== "strip"
        anchors.fill: parent
        anchors.margins: root.design === "ring" ? Math.round(root.height * 0.08) : 0

        Column {
            anchors.centerIn: parent
            width: parent.width
            spacing: Math.round(root.height * 0.03)

            DText {
                width: parent.width
                height: root.dateMode === "none" ? faceBox.height : Math.round(faceBox.height * 0.74)
                horizontalAlignment: Text.AlignHCenter
                face: "dots"
                font.pixelSize: 400
                font.weight: Font.Black
                fontSizeMode: Text.Fit
                minimumPixelSize: 8
                color: root.tone("color")
                elide: Text.ElideNone
                text: root.timeText
            }

            DText {
                visible: root.dateMode !== "none"
                width: parent.width
                height: Math.round(faceBox.height * 0.18)
                horizontalAlignment: Text.AlignHCenter
                face: "dots"
                font.pixelSize: 400
                font.weight: Font.Black
                fontSizeMode: Text.Fit
                minimumPixelSize: 8
                color: DwcTheme.sub
                elide: Text.ElideNone
                text: root.dateText
            }
        }
    }

    // ---- ring: dots round the card, filled to the current second (or minute) ----
    Loader {
        active: root.design === "ring"
        anchors.fill: parent
        sourceComponent: Item {
            id: ring

            readonly property real inset: 3
            readonly property real radius: Math.min(16, height / 4)
            // The outline, computed again only when the card is resized.
            readonly property var outline: Geometry.roundedRectPoints(width - inset * 2, height - inset * 2, radius, 2)
            readonly property real frac: root.ringSeconds
                ? (DwcData.now.getSeconds() + 1) / 60
                : (DwcData.now.getMinutes() * 60 + DwcData.now.getSeconds()) / 3600

            // One dot every 8 px along the outline: lit up to the current second,
            // faint after it, the last lit one a little larger.
            readonly property var dots: {
                var out = [];
                for (var i = 0; i < ring.outline.length - 1; i += 4)
                    out.push(ring.outline[i]);
                return out;
            }
            readonly property int litCount: Math.round(ring.frac * ring.dots.length)

            Repeater {
                model: ring.dots
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool lit: index < ring.litCount
                    readonly property bool head: index === ring.litCount - 1

                    x: modelData.x + ring.inset - width / 2
                    y: modelData.y + ring.inset - height / 2
                    width: head ? 5 : 3
                    height: width
                    radius: width / 2
                    color: lit ? root.tone("color") : DwcTheme.alpha(root.tone("color"), 0.26)
                }
            }
        }
    }

    // ---- strip: time, the week, the day's hours ----
    Loader {
        active: root.design === "strip"
        anchors.fill: parent
        sourceComponent: Item {
            id: strip

            readonly property int hour: DwcData.now.getHours()
            readonly property int today: Dates.mondayIndex(DwcData.now)
            readonly property real cellGap: 2
            readonly property real cellW: (width - 23 * cellGap) / 24
            readonly property color ink: root.tone("color")

            DText {
                id: big
                x: 0
                y: 0
                width: Math.round(strip.width * 0.66)
                height: Math.round(strip.height * 0.64)
                face: "dots"
                font.pixelSize: 400
                font.weight: Font.Black
                fontSizeMode: Text.Fit
                minimumPixelSize: 8
                color: strip.ink
                elide: Text.ElideNone
                text: root.timeText
            }

            // the week: seven squares, the past filled faintly, today bright
            Column {
                anchors { right: parent.right; top: parent.top; topMargin: 4 }
                spacing: Math.round(strip.height * 0.06)

                Row {
                    anchors.right: parent.right
                    spacing: 4
                    Repeater {
                        model: 7
                        delegate: Rectangle {
                            required property int index
                            width: Math.max(7, Math.round(strip.height * 0.07))
                            height: width
                            radius: 2
                            color: index === strip.today ? strip.ink
                                : index < strip.today ? DwcTheme.alpha(strip.ink, 0.32) : "transparent"
                            border.width: index > strip.today ? 1 : 0
                            border.color: DwcTheme.alpha(strip.ink, 0.45)
                        }
                    }
                }
                DText {
                    anchors.right: parent.right
                    face: "mono"
                    font.pixelSize: Math.max(9, Math.round(strip.height * 0.075))
                    color: DwcTheme.muted
                    text: Str.t("w.week").toUpperCase() + " " + Dates.isoWeek(DwcData.now)
                }
                DText {
                    anchors.right: parent.right
                    face: "mono"
                    font.pixelSize: Math.max(9, Math.round(strip.height * 0.075))
                    color: DwcTheme.sub
                    text: Str.fmt("ddd d MMM", DwcData.now).toUpperCase()
                }
            }

            // the day: 24 cells, hours gone dim, this hour bright, the rest faint
            Item {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: Math.round(strip.height * 0.3)

                Repeater {
                    model: 24
                    delegate: Rectangle {
                        required property int index
                        x: index * (strip.cellW + strip.cellGap)
                        y: 0
                        width: strip.cellW
                        height: Math.round(strip.height * 0.12)
                        radius: 1.5
                        color: index === strip.hour ? strip.ink
                            : index < strip.hour ? DwcTheme.alpha(strip.ink, 0.6) : DwcTheme.alpha(strip.ink, 0.2)
                    }
                }
                Repeater {
                    model: [0, 6, 12, 18, 24]
                    delegate: DText {
                        required property int modelData
                        x: Math.min(strip.width - width, Math.max(0, modelData * (strip.cellW + strip.cellGap) - width / 2))
                        y: Math.round(strip.height * 0.14)
                        face: "mono"
                        font.pixelSize: Math.max(8, Math.round(strip.height * 0.065))
                        color: DwcTheme.muted
                        text: (modelData < 10 ? "0" : "") + modelData
                    }
                }
            }
        }
    }
}
