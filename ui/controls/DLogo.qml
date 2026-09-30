import QtQuick
import QtQuick.Shapes
import "../js/Logos.js" as Logos

// A service mark from js/Logos.js ("claude", "openai"), filled, on a 24×24 grid.
Item {
    id: root

    property string name: ""
    property color color: "white"
    property real size: 16

    width: size
    height: size

    Shape {
        width: 24
        height: 24
        scale: root.size / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: "transparent"
            strokeWidth: -1
            fillColor: root.color
            fillRule: ShapePath.WindingFill
            PathSvg { path: Logos.path(root.name) }
        }
    }
}
