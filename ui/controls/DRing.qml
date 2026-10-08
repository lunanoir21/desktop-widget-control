import QtQuick
import QtQuick.Shapes
import ".."

// A ring (or an arc, with `span` below 360) that fills with `value` (0..1), drawn in
// the look of the widget it sits in: a round-capped stroke (standard), a hairline
// (mono, poster), dots (dots) or blocks (terminal). The caller puts what belongs in the
// middle inside it and sizes it with width and height.
Item {
    id: root

    property real value: 0
    property color color: DwcTheme.acc
    property real stroke: Math.max(5, Math.min(width, height) * 0.09)
    property real startAngle: -90
    property real span: 360
    // In the mono look the arc is drawn in the text colour; a warning colour should still show
    property bool keepColor: false
    // The nearest ancestor with a `family` (a DwcWidget) decides the look.
    property string family: "std"

    Component.onCompleted: {
        var p = root.parent;
        while (p && p.family === undefined)
            p = p.parent;
        if (p)
            root.family = Qt.binding(function () { return p.family; });
    }

    readonly property bool dotted: family === "dots"
    readonly property bool blocks: family === "term"
    readonly property bool hair: family === "mono" || family === "poster"
    readonly property real w: dotted ? stroke * 0.6 : hair ? Math.max(1.5, stroke * 0.22) : stroke
    readonly property real r: (Math.min(width, height) - Math.max(stroke, w)) / 2
    readonly property real circumference: Math.PI * 2 * r * (span / 360)
    // dash patterns are in stroke widths: a dot every 1/36 of a full circle, or a block and a gap
    readonly property var dashes: dotted ? [0.001, Math.max(1.2, Math.PI * 2 * r / 36 / w - 0.001)]
        : blocks ? [Math.max(0.5, Math.PI * 2 * r / 32 / w * 0.72), Math.max(0.2, Math.PI * 2 * r / 32 / w * 0.28)]
        : []
    readonly property color fill: family === "mono" && !keepColor ? DwcTheme.fg : root.color
    readonly property color trackColor: hair ? DwcTheme.alpha(DwcTheme.fg, 0.18) : dotted ? DwcTheme.alpha(DwcTheme.fg, 0.16) : DwcTheme.track

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.trackColor
            strokeWidth: root.w
            fillColor: "transparent"
            capStyle: root.dotted ? ShapePath.RoundCap : (root.hair || root.blocks ? ShapePath.FlatCap : ShapePath.RoundCap)
            strokeStyle: root.dashes.length > 0 ? ShapePath.DashLine : ShapePath.SolidLine
            dashPattern: root.dashes
            PathAngleArc {
                centerX: root.width / 2; centerY: root.height / 2
                radiusX: root.r; radiusY: root.r
                startAngle: root.startAngle; sweepAngle: root.span - 0.1
            }
        }
        ShapePath {
            strokeColor: root.value > 0 ? root.fill : "transparent"
            strokeWidth: root.w
            fillColor: "transparent"
            capStyle: root.dotted ? ShapePath.RoundCap : (root.hair || root.blocks ? ShapePath.FlatCap : ShapePath.RoundCap)
            strokeStyle: root.dashes.length > 0 ? ShapePath.DashLine : ShapePath.SolidLine
            dashPattern: root.dashes
            PathAngleArc {
                centerX: root.width / 2; centerY: root.height / 2
                radiusX: root.r; radiusY: root.r
                startAngle: root.startAngle; sweepAngle: Math.max(0.1, (root.span - 0.1) * Math.max(0, Math.min(1, root.value)))
            }
        }
    }
}
