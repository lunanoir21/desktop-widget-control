import QtQuick
import ".."

// Text in one of the theme's faces: "body" (default), "display", "mono",
// "serif" (italic), "dots" (the dot-matrix face) or "geo" (a geometric sans).
//
// The look of the widget it sits in (DwcWidget.family) re-maps the faces, so one
// widget file serves every look: mono and terminal set everything in the mono face,
// dots turns the display face into the dot-matrix one, poster into a tight sans.
// Outside a widget (the editor) the look is "std" and nothing changes.
Text {
    id: root

    property string face: "body"
    // The nearest ancestor that has a `family` (a DwcWidget) decides.
    property string family: "std"

    Component.onCompleted: {
        var p = root.parent;
        while (p && p.family === undefined)
            p = p.parent;
        if (p)
            root.family = Qt.binding(function () { return p.family; });
    }

    // the big-number / title role: display, and (outside the standard look) the serif and geometric faces too
    readonly property bool headline: face === "display" || (family !== "std" && (face === "serif" || face === "geo"))
    readonly property bool monoish: family === "mono" || family === "term"

    color: DwcTheme.fg
    font.pixelSize: 12
    font.family: face === "dots" ? DwcTheme.dots
        : headline ? (monoish ? DwcTheme.mono : family === "dots" ? DwcTheme.dots : family === "poster" ? DwcTheme.body : DwcTheme.display)
        : face === "mono" ? DwcTheme.mono
        : face === "serif" ? DwcTheme.serif
        : face === "geo" ? DwcTheme.geo
        : (monoish ? DwcTheme.mono : DwcTheme.body)
    font.italic: face === "serif" && family === "std"
    font.weight: headline && family === "dots" ? Font.Black : Font.Normal
    font.letterSpacing: headline && family === "poster" ? -0.035 * font.pixelSize : 0
    // Always literal text. Track titles, session names and other outside strings
    // must never be read as HTML (an <img> tag would make the shell fetch a URL).
    textFormat: Text.PlainText
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
}
