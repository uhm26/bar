// Concave corner joining two surfaces at a right angle: the square minus a quarter circle.
// Filled corner at top-right (`flip`: top-left). The path is static, never re-tessellated;
// shrink it with `scale` (it shrinks into its filled corner).
import QtQuick
import QtQuick.Shapes

Shape {
    id: f
    property bool flip: false
    property color color
    width: Theme.corner
    height: Theme.corner
    transformOrigin: flip ? Item.TopLeft : Item.TopRight
    visible: scale > 0.01
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeColor: "transparent"
        fillColor: f.color
        startX: f.flip ? f.width : 0; startY: 0
        PathLine { x: f.flip ? 0 : f.width; y: 0 }
        PathLine { x: f.flip ? 0 : f.width; y: f.height }
        PathArc {
            x: f.flip ? f.width : 0; y: 0
            radiusX: f.width; radiusY: f.height
            direction: f.flip ? PathArc.Clockwise : PathArc.Counterclockwise
        }
    }
}
