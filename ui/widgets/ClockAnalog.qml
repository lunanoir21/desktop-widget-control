import QtQuick
import ".."
import "../controls"

// Analog face drawn from plain rectangles. Small: just the face; bigger: the
// face on the left and the date beside it.
DwcWidget {
    id: root

    readonly property bool secs: root.opt("seconds", false)
    readonly property string ticks: root.opt("ticks", "all")
    readonly property bool showDate: root.opt("date", true) && !root.small

    DwcNeed { source: root.secs ? "clock.sec" : "clock"; interval: 1000 }

    readonly property real h: DwcData.now.getHours()
    readonly property real m: DwcData.now.getMinutes()
    readonly property real s: DwcData.now.getSeconds()

    readonly property real dia: Math.min(root.width, root.height)

    Item {
        id: face
        width: root.dia
        height: root.dia
        x: root.showDate ? 0 : (root.width - width) / 2
        y: (root.height - height) / 2

        // mono and terminal draw the dial's edge (a circle, a square); the others leave it open
        Rectangle {
            visible: root.family === "mono" || root.family === "term"
            anchors.fill: parent
            radius: root.family === "term" ? 0 : width / 2
            color: "transparent"
            border.width: 1
            border.color: DwcTheme.alpha(DwcTheme.fg, root.family === "mono" ? 0.3 : 0.25)
        }

        Repeater {
            model: root.ticks === "none" ? 0 : 12
            delegate: Item {
                required property int index
                readonly property bool major: index % 3 === 0
                // mono and poster keep only the quarters
                visible: (root.ticks === "all" && root.family !== "mono" && root.family !== "poster") || major
                anchors.fill: parent
                rotation: index * 30
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 2
                    // the dots look turns each tick into a dot
                    width: root.family === "dots" ? (major ? 5 : 3) : (major ? 3 : 2)
                    height: root.family === "dots" ? width : (major ? face.height * 0.08 : face.height * 0.045)
                    radius: root.family === "std" ? 1 : (root.family === "dots" ? width / 2 : 0)
                    color: major ? DwcTheme.fg : DwcTheme.muted
                }
            }
        }

        // hour
        Item {
            anchors.fill: parent
            rotation: (root.h % 12) * 30 + root.m * 0.5
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: face.height / 2 - height
                width: Math.max(3, face.height * 0.035)
                height: face.height * 0.26
                radius: root.family === "std" || root.family === "dots" ? width / 2 : 0
                color: root.family === "mono" ? DwcTheme.fg : root.tone("color")
            }
        }
        // minute
        Item {
            anchors.fill: parent
            rotation: root.m * 6 + (root.secs ? root.s * 0.1 : 0)
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: face.height / 2 - height
                width: Math.max(2, face.height * 0.025)
                height: face.height * 0.38
                radius: root.family === "std" || root.family === "dots" ? width / 2 : 0
                color: root.family === "mono" ? DwcTheme.fg : root.tone("color")
            }
        }
        // second
        Item {
            visible: root.secs
            anchors.fill: parent
            rotation: root.s * 6
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: face.height / 2 - height + face.height * 0.06
                width: 1.5
                height: face.height * 0.44
                color: root.tone("accent")
            }
        }
        Rectangle {
            anchors.centerIn: parent
            width: Math.max(6, face.height * 0.06)
            height: width
            radius: width / 2
            color: root.tone("accent")
        }
    }

    Column {
        visible: root.showDate
        anchors { left: face.right; leftMargin: Math.round(root.height * 0.18); right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: 2

        DText {
            width: parent.width
            face: "display"
            font.pixelSize: Math.max(14, Math.round(root.height * 0.17))
            font.weight: Font.DemiBold
            text: Str.fmt("dddd", DwcData.now)
        }
        DText {
            width: parent.width
            font.pixelSize: Math.max(11, Math.round(root.height * 0.11))
            color: DwcTheme.sub
            text: Str.fmt("d MMMM yyyy", DwcData.now)
        }
    }
}
