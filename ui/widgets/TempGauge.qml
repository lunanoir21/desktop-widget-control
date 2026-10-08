import QtQuick
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

        // a half circle: the arc of a ring that is as tall as the gauge is wide
        DRing {
            anchors.top: parent.top
            width: parent.width
            height: parent.width
            startAngle: 180
            span: 180
            value: root.frac
            color: root.hot
            stroke: root.stroke
            keepColor: DwcData.temp >= root.opt("warn", 70)
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
