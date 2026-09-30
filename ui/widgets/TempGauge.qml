import QtQuick
import QtQuick.Shapes
import ".."
import "../controls"

// A half-circle gauge for the CPU temperature. Warm past `warn`, red past `crit`.
DwcWidget {
    id: root

    DwcNeed { source: "temp"; interval: 3000 }

    readonly property real maxT: root.opt("max", 100)
    readonly property real frac: Math.max(0, Math.min(1, DwcData.temp / maxT))
    readonly property color hot: DwcData.temp >= root.opt("crit", 85) ? DwcTheme.danger
        : DwcData.temp >= root.opt("warn", 70) ? "#e0a458" : root.tone("color")

    readonly property real gaugeW: root.small ? root.width : Math.min(root.width * 0.62, root.height * 1.9)
    readonly property real stroke: Math.max(7, gaugeW * 0.075)

    Item {
        id: gauge
        width: root.gaugeW
        height: root.gaugeW / 2 + root.stroke / 2
        x: root.small ? 0 : 0
        anchors.verticalCenter: parent.verticalCenter

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: DwcTheme.track
                strokeWidth: root.stroke
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: gauge.width / 2; centerY: gauge.width / 2
                    radiusX: (gauge.width - root.stroke) / 2; radiusY: (gauge.width - root.stroke) / 2
                    startAngle: 180; sweepAngle: 180
                }
            }
            ShapePath {
                strokeColor: root.hot
                strokeWidth: root.stroke
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: gauge.width / 2; centerY: gauge.width / 2
                    radiusX: (gauge.width - root.stroke) / 2; radiusY: (gauge.width - root.stroke) / 2
                    startAngle: 180; sweepAngle: Math.max(0.1, 180 * root.frac)
                }
            }
        }

        DText {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: root.stroke * 0.4 }
            face: "mono"
            font.pixelSize: Math.round(gauge.width * 0.2)
            text: DwcData.tempAvailable ? Math.round(DwcData.temp) + "°" : "–"
        }
    }

    Column {
        visible: !root.small
        anchors { left: gauge.right; leftMargin: Math.round(root.height * 0.18); right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: 3

        DText {
            width: parent.width
            face: "display"
            font.pixelSize: Math.max(13, Math.round(root.height * 0.15))
            font.weight: Font.DemiBold
            text: Str.t("w.cpu")
        }
        DText {
            width: parent.width
            face: "mono"
            font.pixelSize: Math.max(10, Math.round(root.height * 0.095))
            color: DwcTheme.muted
            text: DwcData.tempAvailable ? "0 – " + root.maxT + "°" : Str.t("w.tempNA")
        }
    }
}
