import QtQuick
import ".."
import "../controls"

// Memory use as a ring. Small: ring and percentage; bigger: the ring with
// used / total and swap beside it.
DwcWidget {
    id: root

    readonly property bool showSwap: root.opt("swap", true) && !root.small
    readonly property bool showLabel: root.opt("label", true)

    DwcNeed { source: "mem"; interval: root.opt("interval", 2) * 1000 }

    readonly property real dia: Math.min(root.width, root.height)
    readonly property real stroke: Math.max(6, dia * 0.085)

    Item {
        id: ring
        width: root.dia
        height: root.dia
        x: root.small ? (root.width - width) / 2 : 0
        y: (root.height - height) / 2

        DRing {
            anchors.fill: parent
            value: DwcData.memFrac
            color: root.tone("color")
            stroke: root.stroke
        }

        DText {
            anchors.centerIn: parent
            face: "mono"
            font.pixelSize: Math.round(ring.height * 0.22)
            text: Math.round(DwcData.memFrac * 100) + "%"
        }
    }

    Column {
        visible: !root.small
        anchors { left: ring.right; leftMargin: Math.round(root.height * 0.2); right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: 3

        DText {
            visible: root.showLabel
            width: parent.width
            face: "display"
            font.pixelSize: Math.max(13, Math.round(root.height * 0.15))
            font.weight: Font.DemiBold
            text: Str.t("w.memory")
        }
        DText {
            width: parent.width
            face: "mono"
            font.pixelSize: Math.max(11, Math.round(root.height * 0.105))
            color: DwcTheme.sub
            text: DwcData.bytes(DwcData.memUsed, 1) + " / " + DwcData.bytes(DwcData.memTotal, 0)
        }
        DText {
            visible: root.showSwap && DwcData.swapTotal > 0
            width: parent.width
            face: "mono"
            font.pixelSize: Math.max(10, Math.round(root.height * 0.09))
            color: DwcTheme.muted
            text: Str.t("w.swap") + " " + DwcData.bytes(DwcData.swapUsed, 1)
        }
    }
}
