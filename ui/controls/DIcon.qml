import QtQuick
import QtQuick.Shapes
import "../js/Icons.js" as Icons

// An icon from js/Icons.js. Stroked by default; `filled` paints the shape instead.
Item {
    id: root

    property string name: ""
    property color color: "white"
    property real size: 16
    property bool filled: false
    property real strokeWidth: 1.6

    width: size
    height: size

    Shape {
        width: 20
        height: 20
        scale: root.size / 20
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.filled ? "transparent" : root.color
            strokeWidth: root.filled ? -1 : root.strokeWidth
            fillColor: root.filled ? root.color : "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: Icons.path(root.name) }
        }
    }
}
