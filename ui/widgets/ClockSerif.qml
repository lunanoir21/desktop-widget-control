import QtQuick
import ".."
import "../controls"

// A large italic serif time. Updates once a minute, so it costs almost nothing.
DwcWidget {
    id: root

    readonly property bool h12: root.opt("format", "24") === "12"
    readonly property string dateMode: root.opt("date", "long")

    DwcNeed { source: "clock"; interval: 60000 }

    Column {
        anchors.centerIn: parent
        width: parent.width
        spacing: Math.round(root.height * 0.02)

        DText {
            width: parent.width
            height: root.dateMode === "none" ? root.height : Math.round(root.height * 0.76)
            face: "serif"
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 400
            fontSizeMode: Text.Fit
            minimumPixelSize: 10
            elide: Text.ElideNone
            color: root.tone("color")
            text: Str.fmt(root.h12 ? "h:mm" : "H:mm", DwcData.now)
        }
        DText {
            visible: root.dateMode !== "none"
            width: parent.width
            height: Math.round(root.height * 0.16)
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 400
            fontSizeMode: Text.Fit
            minimumPixelSize: 9
            elide: Text.ElideNone
            color: DwcTheme.sub
            text: root.dateMode === "short" ? Str.fmt("ddd, d MMM", DwcData.now) : Str.fmt("dddd, d MMMM", DwcData.now)
        }
    }
}
