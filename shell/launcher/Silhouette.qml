// The launcher's shape: the body (top corners rounded) standing on the bottom edge, joined
// to it by two concave fillets that shrink into the edge as the body shrinks. Drawn by the
// launcher (its surface) and by LauncherShadow (the shape cut out of its shadow).
import QtQuick
import qs

Item {
    id: shape
    property real bodyX: 0
    property real bodyW: 0
    property real bodyH: 0
    property color color: Theme.bg
    readonly property real fillet: Math.min(1, bodyH / Theme.corner)

    Rectangle {
        x: shape.bodyX; y: shape.height - shape.bodyH; width: shape.bodyW; height: shape.bodyH
        visible: shape.bodyH > 0
        topLeftRadius: Theme.drawerRadius; topRightRadius: Theme.drawerRadius
        bottomLeftRadius: 0; bottomRightRadius: 0
        color: shape.color
    }
    // Fillet's shape turned 180°. They reach 1 px into the body (no seam at fractional x).
    Item {
        x: shape.bodyX - Theme.corner + 1; y: shape.height - Theme.corner
        width: Theme.corner; height: Theme.corner
        rotation: 180
        Fillet { flip: true; scale: shape.fillet; color: shape.color }
    }
    Item {
        x: shape.bodyX + shape.bodyW - 1; y: shape.height - Theme.corner
        width: Theme.corner; height: Theme.corner
        rotation: 180
        Fillet { scale: shape.fillet; color: shape.color }
    }
}
