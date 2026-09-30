import QtQuick
import ".."
import "../controls"
import "../js/Dates.js" as Dates

// Monospaced time with seconds, a thin seconds bar and a date / week line.
DwcWidget {
    id: root

    readonly property bool secs: root.opt("seconds", true)
    readonly property bool h12: root.opt("format", "24") === "12"
    readonly property string dateMode: root.opt("date", "short")

    DwcNeed { source: root.secs ? "clock.sec" : "clock"; interval: 1000 }


    readonly property real unit: root.height
    // The time must fit the width as well as the height: five monospaced
    // characters, plus ":ss" at 60 % size when seconds are on.
    readonly property real mainPx: Math.min(root.unit * (root.small ? 0.34 : 0.4), root.width / (root.secs ? 4.4 : 3.3))

    Column {
        anchors.centerIn: parent
        width: parent.width
        spacing: Math.round(root.unit * 0.07)

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2
            DText {
                face: "mono"
                font.pixelSize: Math.round(root.mainPx)
                text: Str.fmt(root.h12 ? "h:mm" : "HH:mm", DwcData.now)
                color: root.tone("color")
            }
            DText {
                visible: root.secs
                face: "mono"
                font.pixelSize: Math.round(root.mainPx * 0.6)
                text: ":" + Str.fmt("ss", DwcData.now)
                color: DwcTheme.muted
            }
        }

        Rectangle {
            visible: root.secs && root.opt("bar", true)
            width: parent.width
            height: 3
            radius: 2
            color: DwcTheme.track
            Rectangle {
                width: parent.width * (DwcData.now.getSeconds() + 1) / 60
                height: parent.height
                radius: 2
                color: root.tone("color")
            }
        }

        Item {
            visible: root.dateMode !== "none"
            width: parent.width
            height: Math.round(root.unit * 0.12) + 4

            DText {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                face: "mono"
                font.pixelSize: Math.max(10, Math.round(root.unit * 0.1))
                color: DwcTheme.sub
                text: root.dateMode === "long" ? Str.fmt("dddd d MMMM yyyy", DwcData.now).toUpperCase() : Str.fmt("ddd dd.MM.yyyy", DwcData.now).toUpperCase()
            }
            DText {
                visible: !root.small
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                face: "mono"
                font.pixelSize: Math.max(10, Math.round(root.unit * 0.1))
                color: DwcTheme.muted
                text: Str.t("w.week") + " " + Dates.isoWeek(DwcData.now)
            }
        }
    }
}
