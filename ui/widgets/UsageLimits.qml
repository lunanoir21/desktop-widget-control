import QtQuick
import QtQuick.Shapes
import ".."
import "../controls"
import "../js/Usage.js" as Usage

// The 5-hour and weekly limits of Claude and Codex. Two looks: twin rings (the
// outer ring is the 5-hour window, the inner one the week) and LED dots.
// Codex comes from its own session logs; Claude from Claude Code's status line
// capture, or, when the option is on, from the usage endpoint. See
// DwcData (usage) and scripts/usage.sh for where the numbers come from.
DwcWidget {
    id: root

    readonly property string look: root.opt("look", "rings")
    readonly property string show: root.opt("show", "both")
    readonly property real warnAt: root.opt("warn", 90)
    readonly property bool api: root.opt("claudeApi", false)

    DwcNeed { source: "usage"; interval: 60000 }
    DwcNeed { source: "usageApi"; interval: 300000; enabled: root.api && root.show !== "codex" }

    readonly property int nowS: Math.floor(DwcData.now.getTime() / 1000)

    // One provider's numbers, ready to draw. A library thumbnail gets sample ones.
    function make(id) {
        var claude = id === "claude";
        var reading = root.preview
            ? { five: { pct: claude ? 63 : 40, resets: root.nowS + 7500 }, week: { pct: claude ? 72 : 18, resets: root.nowS + 250000 }, at: root.nowS, source: "sample" }
            : (claude ? DwcData.claudeUsage : DwcData.codexUsage);
        var five = reading ? Usage.settle(reading.five, root.nowS) : null;
        var week = reading ? Usage.settle(reading.week, root.nowS) : null;
        var note = "";
        if (!reading) {
            note = claude ? (root.api && DwcData.claudeApiNote === "expired" ? Str.t("usage.expired") : Str.t("usage.connect"))
                          : Str.t("usage.codexNone");
        }
        var age = reading && reading.source !== "api" ? Usage.ageMinutes(reading.at, root.nowS) : 0;
        return {
            id: id,
            title: claude ? "Claude" : "Codex",
            mark: claude ? "claude" : "openai",
            accent: root.tone(claude ? "color2" : "color"),
            five: five, week: week, note: note,
            resets: five && five.resets > 0 ? Usage.duration(Usage.remaining(five.resets, root.nowS)) : "",
            stale: age >= 30 ? Usage.duration(age * 60) : ""
        };
    }

    readonly property var panels: {
        var out = [];
        if (root.show !== "codex")
            out.push(root.make("claude"));
        if (root.show !== "claude")
            out.push(root.make("codex"));
        return out;
    }

    function fillColor(p, w) {
        return w && Usage.level(w.pct, root.warnAt) !== "ok" ? DwcTheme.danger : p.accent;
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.look === "led" ? ledLook : ringsLook
    }

    // ---- twin rings ---------------------------------------------------------
    Component {
        id: ringsLook
        Row {
            spacing: Math.round(root.height * 0.08)

            Repeater {
                model: root.panels
                delegate: Item {
                    id: panel
                    required property var modelData
                    required property int index
                    width: (parent.width - parent.spacing * (root.panels.length - 1)) / root.panels.length
                    height: parent.height

                    readonly property real ring: Math.min(panel.height, panel.width * 0.56)
                    readonly property real stroke: Math.max(5, ring * 0.095)

                    Item {
                        id: rings
                        width: panel.ring
                        height: panel.ring
                        anchors.verticalCenter: parent.verticalCenter

                        Repeater {
                            model: [
                                { r: (rings.width - panel.stroke) / 2, w: panel.modelData.five, dim: 1 },
                                { r: (rings.width - panel.stroke) / 2 - panel.stroke * 1.3, w: panel.modelData.week, dim: 0.55 }
                            ]
                            delegate: Shape {
                                required property var modelData
                                anchors.fill: parent
                                preferredRendererType: Shape.CurveRenderer
                                ShapePath {
                                    strokeColor: DwcTheme.track
                                    strokeWidth: panel.stroke * (modelData.dim === 1 ? 1 : 0.78)
                                    fillColor: "transparent"
                                    PathAngleArc { centerX: rings.width / 2; centerY: rings.width / 2; radiusX: modelData.r; radiusY: modelData.r; startAngle: -90; sweepAngle: 359.9 }
                                }
                                ShapePath {
                                    strokeColor: modelData.w ? Qt.alpha(root.fillColor(panel.modelData, modelData.w), modelData.dim) : "transparent"
                                    strokeWidth: panel.stroke * (modelData.dim === 1 ? 1 : 0.78)
                                    fillColor: "transparent"
                                    capStyle: ShapePath.RoundCap
                                    PathAngleArc {
                                        centerX: rings.width / 2; centerY: rings.width / 2; radiusX: modelData.r; radiusY: modelData.r
                                        startAngle: -90; sweepAngle: modelData.w ? Math.max(0.1, 3.599 * modelData.w.pct) : 0
                                    }
                                }
                            }
                        }

                        DText {
                            anchors.centerIn: parent
                            face: "mono"
                            font.pixelSize: Math.round(rings.width * 0.2)
                            text: panel.modelData.five ? Math.round(panel.modelData.five.pct) : "–"
                        }
                    }

                    Column {
                        anchors { left: rings.right; leftMargin: Math.round(root.height * 0.07); right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 2

                        Row {
                            spacing: 6
                            DLogo { name: panel.modelData.mark; size: Math.max(12, Math.round(root.height * 0.1)); color: panel.modelData.accent; anchors.verticalCenter: parent.verticalCenter }
                            DText {
                                face: "display"
                                font.pixelSize: Math.max(13, Math.round(root.height * 0.095))
                                font.weight: Font.DemiBold
                                text: panel.modelData.title
                            }
                        }
                        DText {
                            visible: panel.modelData.five !== null
                            width: parent.width
                            face: "mono"
                            font.pixelSize: Math.max(10, Math.round(root.height * 0.07))
                            color: DwcTheme.sub
                            text: Str.t("usage.five") + " " + (panel.modelData.five ? Math.round(panel.modelData.five.pct) : 0) + "%"
                        }
                        DText {
                            visible: panel.modelData.week !== null
                            width: parent.width
                            face: "mono"
                            font.pixelSize: Math.max(10, Math.round(root.height * 0.07))
                            color: panel.modelData.week && Usage.level(panel.modelData.week.pct, root.warnAt) !== "ok" ? DwcTheme.danger : DwcTheme.sub
                            text: Str.t("usage.week") + " " + (panel.modelData.week ? Math.round(panel.modelData.week.pct) : 0) + "%"
                        }
                        DText {
                            visible: text !== ""
                            width: parent.width
                            face: "mono"
                            font.pixelSize: Math.max(9, Math.round(root.height * 0.06))
                            color: DwcTheme.muted
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            text: panel.modelData.note !== "" ? panel.modelData.note
                                : panel.modelData.stale !== "" ? Str.t("usage.asOf") + " " + panel.modelData.stale + " " + Str.t("usage.ago")
                                : panel.modelData.resets !== "" ? Str.t("usage.resets") + " " + panel.modelData.resets : ""
                        }
                    }
                }
            }
        }
    }

    // ---- LED dots ---------------------------------------------------------------
    Component {
        id: ledLook
        Column {
            spacing: Math.round(root.height * 0.06)

            Repeater {
                model: root.panels
                delegate: Item {
                    id: row
                    required property var modelData
                    width: parent.width
                    height: (parent.height - parent.spacing * (root.panels.length - 1)) / root.panels.length

                    readonly property real nameW: Math.round(root.height * 0.3)
                    readonly property real numW: Math.round(root.height * 0.42)

                    Column {
                        id: nameCol
                        width: row.nameW
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        DLogo { name: row.modelData.mark; size: Math.max(16, Math.round(root.height * 0.15)); color: row.modelData.accent }
                        DText {
                            face: "mono"
                            font.pixelSize: Math.max(8, Math.round(root.height * 0.055))
                            font.letterSpacing: 1
                            color: DwcTheme.sub
                            text: row.modelData.title.toUpperCase()
                        }
                    }

                    DText {
                        id: num
                        anchors { left: nameCol.right; verticalCenter: parent.verticalCenter }
                        width: row.numW
                        face: "dots"
                        font.pixelSize: Math.round(root.height * 0.27)
                        font.weight: Font.Black
                        color: row.modelData.five ? root.fillColor(row.modelData, row.modelData.five) : DwcTheme.muted
                        text: row.modelData.five ? Math.round(row.modelData.five.pct) : "--"
                    }

                    Column {
                        anchors { left: num.right; right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: Math.round(root.height * 0.045)

                        Repeater {
                            model: [{ w: row.modelData.five, dim: 1 }, { w: row.modelData.week, dim: 0.6 }]
                            delegate: Row {
                                id: dots
                                required property var modelData
                                readonly property int n: 18
                                readonly property real gap: 2
                                readonly property real d: Math.max(3, (parent.width - gap * (n - 1)) / n)
                                spacing: gap
                                Repeater {
                                    model: dots.n
                                    delegate: Rectangle {
                                        required property int index
                                        width: dots.d; height: dots.d; radius: dots.d / 2
                                        color: dots.modelData.w && index < Math.round(dots.modelData.w.pct / 100 * dots.n)
                                            ? Qt.alpha(root.fillColor(row.modelData, dots.modelData.w), dots.modelData.dim) : DwcTheme.track
                                    }
                                }
                            }
                        }
                        DText {
                            width: parent.width
                            face: "mono"
                            font.pixelSize: Math.max(8, Math.round(root.height * 0.055))
                            color: DwcTheme.muted
                            elide: Text.ElideRight
                            text: row.modelData.note !== "" ? row.modelData.note
                                : row.modelData.stale !== "" ? Str.t("usage.asOf") + " " + row.modelData.stale + " " + Str.t("usage.ago")
                                : row.modelData.resets !== "" ? Str.t("usage.resets") + " " + row.modelData.resets : ""
                        }
                    }
                }
            }
        }
    }
}
