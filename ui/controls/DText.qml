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
    // Always literal text. Track titles, session names and other outside strings
    // must never be read as HTML (an <img> tag would make the shell fetch a URL).
    textFormat: Text.PlainText
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
}
