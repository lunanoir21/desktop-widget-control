import QtQuick
import ".."

// Text in one of the theme's faces: "body" (default), "display", "mono",
// "serif" (italic), "dots" (the dot-matrix face) or "geo" (a geometric sans).
Text {
    id: root

    property string face: "body"

    color: DwcTheme.fg
    font.pixelSize: 12
    font.family: face === "display" ? DwcTheme.display
        : face === "mono" ? DwcTheme.mono
        : face === "serif" ? DwcTheme.serif
        : face === "dots" ? DwcTheme.dots
        : face === "geo" ? DwcTheme.geo
        : DwcTheme.body
    font.italic: face === "serif"
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
}
