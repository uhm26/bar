// Circle gauge: track + white arc from 12 o'clock, value in the middle. The arc glides.
import QtQuick
import QtQuick.Shapes
import qs

Item {
    id: ring
    property real value: 0 // 0..100
    property string label: ""
    property bool off: false // nothing to measure (e.g. no swap): dim, empty
    property int size: 76
    property color track: Theme.containerHigh
    property int stroke: 7
    property real shown: off ? 0 : Math.max(0, Math.min(100, value))
    Behavior on shown {
        enabled: ring.visible // a hidden ring must not animate (it kept the bar rendering)
        NumberAnimation { duration: Theme.fastSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.graphic }
    }
    implicitWidth: size
    implicitHeight: size

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: ring.track
            strokeWidth: ring.stroke
            fillColor: "transparent"
            PathAngleArc {
                centerX: ring.size / 2; centerY: ring.size / 2
                radiusX: (ring.size - ring.stroke) / 2; radiusY: radiusX
                startAngle: 0; sweepAngle: 360
            }
        }
        ShapePath {
            strokeColor: ring.shown > 0.5 ? Theme.primary : "transparent"
            strokeWidth: ring.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.size / 2; centerY: ring.size / 2
                radiusX: (ring.size - ring.stroke) / 2; radiusY: radiusX
                startAngle: -90; sweepAngle: 3.6 * ring.shown
            }
        }
    }

    Column {
        anchors.centerIn: parent
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ring.off ? "off" : Math.round(ring.value) + "%"
            font.pixelSize: 16
            font.weight: Font.DemiBold
            color: ring.off ? Theme.dim : Theme.bright
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ring.label
            font.pixelSize: 11
            color: Theme.dim
        }
    }
}
