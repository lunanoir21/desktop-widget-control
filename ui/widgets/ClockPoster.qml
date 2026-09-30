import QtQuick
import ".."
import "../controls"
import "../js/Dates.js" as Dates

// A lock-screen style clock in three styles (the Style option):
//   classic  the weekday in large, widely spaced capitals, the date under it
//            and the time small between two dashes
//   cut      the same, with the weekday sliced across the middle by a thin gap
//   sign     the weekday as a big outline across the card, a strip of four
//            readings under it (date, week, day of the year, time)
// It starts without a card so it sits straight on the wallpaper.
DwcWidget {
    id: root

    readonly property string design: root.opt("design", "classic")
    readonly property bool h12: root.opt("format", "24") === "12"
    readonly property bool showDate: root.opt("showDate", true)
    readonly property bool showTime: root.opt("showTime", true)
    readonly property bool secs: root.design === "sign" && root.showTime && root.opt("seconds", false)
    readonly property real tracking: ({ tight: 0.08, normal: 0.16, wide: 0.26 })[root.opt("spacing", "wide")] || 0.26

    DwcNeed { source: root.secs ? "clock.sec" : "clock"; interval: 1000 }

    readonly property string weekday: Str.fmt("dddd", DwcData.now).toUpperCase()
    readonly property string dateLine: (Str.lang === "tr" ? Str.fmt("d MMMM yyyy", DwcData.now) : Str.fmt("MMMM d, yyyy", DwcData.now)).toUpperCase()
    readonly property string timeText: Str.fmt(root.h12 ? (root.secs ? "h:mm:ss AP" : "h:mm AP") : (root.secs ? "HH:mm:ss" : "HH:mm"), DwcData.now).toUpperCase()

    // The weekday is sized to fill the width (capitals of this face run about
    // 0.68 em wide, plus the spacing between them), but never taller than the card allows.
    readonly property int n: Math.max(1, root.weekday.length)
    readonly property real px: Math.max(14, Math.min(root.height * (root.showDate || root.showTime ? 0.36 : 0.6),
                                                      root.width / (0.68 * n + root.tracking * (n - 1))))

    // The weekday in this face, used by the classic and the cut styles.
    component Weekday: DText {
        face: "geo"
        font.pixelSize: Math.round(root.px)
        font.weight: Font.Medium
        font.letterSpacing: root.px * root.tracking
        leftPadding: root.px * root.tracking     // the last letter carries spacing too; balance it
        color: root.tone("color")
        style: Text.Raised
        styleColor: Qt.rgba(0, 0, 0, 0.45)
        elide: Text.ElideNone
        text: root.weekday
    }

    component Small: DText {
        face: "geo"
        font.weight: Font.Medium
        color: root.tone("color")
        style: Text.Raised
        styleColor: Qt.rgba(0, 0, 0, 0.45)
        elide: Text.ElideNone
    }

    // ---- classic and cut ----
    Column {
        visible: root.design !== "sign"
        anchors.centerIn: parent
        spacing: Math.round(root.px * 0.16)

        // classic: one piece
        Weekday {
            visible: root.design === "classic"
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // cut: two halves with a gap between them
        Item {
            id: cutBox
            visible: root.design === "cut"
            anchors.horizontalCenter: parent.horizontalCenter
            readonly property real gap: Math.max(2, Math.round(root.px * 0.05))
            width: cutProbe.implicitWidth
            height: cutProbe.implicitHeight + gap

            Weekday { id: cutProbe; visible: false }

            Item {
                width: parent.width
                height: Math.round(cutProbe.implicitHeight * 0.52)
                clip: true
                Weekday { }
            }
            Item {
                y: Math.round(cutProbe.implicitHeight * 0.48) + cutBox.gap
                width: parent.width
                height: cutProbe.implicitHeight - Math.round(cutProbe.implicitHeight * 0.48)
                clip: true
                Weekday { y: -Math.round(cutProbe.implicitHeight * 0.48) }
            }
        }

        Small {
            visible: root.showDate
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: Math.max(10, Math.round(root.px * 0.36))
            font.letterSpacing: Math.max(1, root.px * (root.design === "cut" ? 0.08 : 0.05))
            leftPadding: Math.max(1, root.px * (root.design === "cut" ? 0.08 : 0.05))
            text: root.dateLine
        }

        Row {
            visible: root.showTime
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(root.px * 0.22)

            Rectangle {
                visible: root.design === "cut"
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(root.px * 0.7)
                height: 1
                color: DwcTheme.sub
            }
            DText {
                face: "geo"
                font.pixelSize: Math.max(9, Math.round(root.px * 0.27))
                font.letterSpacing: Math.max(1, root.px * (root.design === "cut" ? 0.1 : 0.04))
                leftPadding: Math.max(1, root.px * 0.04)
                color: DwcTheme.sub
                style: Text.Raised
                styleColor: Qt.rgba(0, 0, 0, 0.45)
                elide: Text.ElideNone
                text: root.design === "cut" ? root.timeText : "- " + root.timeText + " -"
            }
            Rectangle {
                visible: root.design === "cut"
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(root.px * 0.7)
                height: 1
                color: DwcTheme.sub
            }
        }
    }

    // ---- sign: an outlined weekday and a strip of readings ----
    Loader {
        active: root.design === "sign"
        anchors.fill: parent
        sourceComponent: Item {
            id: sign

            readonly property bool strip: root.showDate || root.showTime
            // Four readings need room; a narrow card keeps the date and the time.
            readonly property bool narrow: width < 400
            readonly property real stripH: strip ? Math.round(height * 0.3) : 0
            readonly property color ink: root.tone("color")
            readonly property color accent: root.tone("accent")

            // corner marks
            Repeater {
                model: [[0, 0, 1, 1], [1, 0, -1, 1], [0, 1, 1, -1], [1, 1, -1, -1]]
                delegate: Item {
                    required property var modelData
                    readonly property real len: Math.max(8, Math.round(sign.height * 0.07))
                    x: modelData[0] === 0 ? 2 : sign.width - 2
                    y: modelData[1] === 0 ? 2 : sign.height - 2
                    Rectangle { x: modelData[2] > 0 ? 0 : -parent.len; width: parent.len; height: 1; color: DwcTheme.alpha(sign.ink, 0.45) }
                    Rectangle { y: modelData[3] > 0 ? 0 : -parent.len; width: 1; height: parent.len; color: DwcTheme.alpha(sign.ink, 0.45) }
                }
            }

            // the weekday: only the outline, scaled to the width
            Canvas {
                id: cv
                anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 10; rightMargin: 10; topMargin: 8 }
                height: sign.height - sign.stripH - 16

                property string txt: root.weekday
                property color stroke: sign.ink
                readonly property string family: DwcTheme.display

                onTxtChanged: requestPaint()
                onStrokeChanged: requestPaint()
                onFamilyChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    if (width < 10 || height < 10 || txt === "")
                        return;
                    ctx.font = "800 100px \"" + family + "\"";
                    var w100 = ctx.measureText(txt).width;
                    var px = Math.max(10, Math.min(height * 1.05, 100 * (width - 4) / Math.max(1, w100)));
                    ctx.font = "800 " + px + "px \"" + family + "\"";
                    ctx.lineWidth = Math.max(1.5, px * 0.014);
                    ctx.lineJoin = "round";
                    ctx.strokeStyle = stroke;
                    ctx.textAlign = "center";
                    ctx.textBaseline = "alphabetic";
                    ctx.strokeText(txt, width / 2, (height + px * 0.7) / 2);
                }
            }

            // the strip: four readings between thin rules
            Item {
                visible: sign.strip
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 6; rightMargin: 6; bottomMargin: 6 }
                height: sign.stripH - 6

                Rectangle { width: parent.width; height: 1; color: DwcTheme.alpha(sign.ink, 0.3) }
                Rectangle { y: parent.height - 1; width: parent.width; height: 1; color: DwcTheme.alpha(sign.ink, 0.3) }

                Row {
                    anchors.fill: parent
                    readonly property var cells: {
                        var out = [];
                        if (root.showDate) {
                            out.push({ label: Str.t("w.dateLabel"), value: Str.fmt(sign.narrow ? "dd.MM" : "dd.MM.yyyy", DwcData.now), hot: false });
                            if (!sign.narrow) {
                                out.push({ label: Str.t("w.weekLabel"), value: String(Dates.isoWeek(DwcData.now)), hot: false });
                                out.push({ label: Str.t("w.dayLabel"), value: String(Dates.dayOfYear(DwcData.now)), hot: false });
                            }
                        }
                        if (root.showTime)
                            out.push({ label: Str.t("w.timeLabel"), value: root.timeText, hot: true });
                        return out;
                    }

                    Repeater {
                        model: parent.cells
                        delegate: Item {
                            required property var modelData
                            required property int index
                            width: parent.width / Math.max(1, parent.cells.length)
                            height: parent.height

                            Rectangle { visible: index > 0; width: 1; height: parent.height; color: DwcTheme.alpha(sign.ink, 0.3) }
                            Column {
                                anchors { left: parent.left; leftMargin: 10; right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                                spacing: 2
                                DText {
                                    width: parent.width
                                    face: "mono"
                                    font.pixelSize: Math.max(8, Math.round(sign.height * 0.065))
                                    font.letterSpacing: 1.5
                                    color: DwcTheme.muted
                                    text: modelData.label
                                }
                                DText {
                                    width: parent.width
                                    face: "mono"
                                    font.pixelSize: Math.max(10, Math.round(sign.height * 0.11))
                                    font.weight: Font.Medium
                                    color: modelData.hot ? sign.accent : sign.ink
                                    text: modelData.value
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
