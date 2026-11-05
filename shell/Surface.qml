// The bar's one surface: strip, its inner corners at the screen ends, and the drawers with
// its fillets. Plain rectangles + static corner shapes, cheap to animate at 165 Hz.
// Drawn opaque into one layer so overlaps never show; the layer opacity is the glass tint.
// The drawer body starts under the bar, so its rounded bottom slides up behind it on close.
import QtQuick
import QtQuick.Effects

Item {
    id: s
    // The drawer slots (DrawerSlot: x, width, height in this item's coordinates). Two, so one
    // can close while another opens at a different chip.
    property var drawers: []
    // One color in both modes: glass only changes the layer opacity, so the switch is a
    // pure fade (a color jump to black here flashed on every toggle).
    readonly property color tone: Theme.bg

    layer.enabled: true
    opacity: Theme.surfaceOpacity
    Behavior on opacity {
        NumberAnimation { duration: Theme.effects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.outExpo }
    }

    // Fillets reach 1 px into the surface they join (up into the bar, sideways into the
    // drawer): inside one opaque layer the overlap is invisible, and edges at fractional
    // positions never leave a hairline seam.
    // Very slight shadow under the bar and the drawers, so they stay apart from a window
    // behind in the same color (a terminal under an open menu looked wrong). Analytic
    // RectangularShadow, drawn first (= below): a MultiEffect shadow over the whole layer
    // pushed 13-22 drawer frames per animation over 8 ms, these cost ~nothing.
    RectangularShadow {
        width: s.width
        height: Theme.height
        offset.y: 2
        blur: 14
        color: Qt.rgba(0, 0, 0, 0.45)
    }
    Repeater {
        model: s.drawers
        RectangularShadow {
            required property var modelData
            x: modelData.x
            y: Theme.height - Theme.drawerRadius
            width: modelData.width
            height: modelData.height + Theme.drawerRadius
            visible: modelData.height > 0
            radius: Theme.drawerRadius
            offset.y: 2
            blur: 14
            color: Qt.rgba(0, 0, 0, 0.45)
        }
    }

    Rectangle { width: s.width; height: Theme.height; color: s.tone }
    Fillet { y: Theme.height - 1; flip: true; color: s.tone }
    Fillet { x: s.width - width; y: Theme.height - 1; color: s.tone }

    // Each drawer: body (starts under the bar) + concave fillets joining it to the bar.
    Repeater {
        model: s.drawers
        Item {
            id: shape
            required property var modelData
            readonly property real fillet: Math.min(1, modelData.height / Theme.corner)
            visible: modelData.height > 0
            Rectangle {
                x: shape.modelData.x
                y: Theme.height - Theme.drawerRadius
                width: shape.modelData.width
                height: shape.modelData.height + Theme.drawerRadius
                topLeftRadius: 0
                topRightRadius: 0
                bottomLeftRadius: Theme.drawerRadius
                bottomRightRadius: Theme.drawerRadius
                color: s.tone
            }
            Fillet { x: shape.modelData.x - width + 1; y: Theme.height - 1; scale: shape.fillet; color: s.tone }
            Fillet { x: shape.modelData.x + shape.modelData.width - 1; y: Theme.height - 1; flip: true; scale: shape.fillet; color: s.tone }
        }
    }
}
