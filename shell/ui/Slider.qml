// M3-style slider: rounded track, white fill and knob. `value` 0..1 follows its source;
// drag, click or scroll (5 % per notch) emits `moved(v)` and the parent sets the source.
import QtQuick
import qs

Item {
    id: s
    property real value: 0
    property bool dim: false // muted: grey instead of white
    signal moved(real v)
    readonly property real shown: Math.max(0, Math.min(1, value))
    readonly property int knob: 14
    Notches { id: notches; onNotch: d => s.moved(Math.max(0, Math.min(1, s.value + d * 0.05))) }
    implicitHeight: 24

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Theme.containerHigh
        Rectangle {
            width: Math.max(parent.height, s.knob / 2 + (parent.width - s.knob) * s.shown)
            height: parent.height
            radius: 3
            color: s.dim ? Theme.dim : Theme.bright
        }
    }
    Rectangle {
        x: (s.width - s.knob) * s.shown
        anchors.verticalCenter: parent.verticalCenter
        width: s.knob
        height: s.knob
        radius: s.knob / 2
        color: s.dim ? Theme.dim : Theme.bright
        scale: area.pressed || area.containsMouse ? 1.15 : 1
        Behavior on scale {
            NumberAnimation { duration: Theme.fastEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.outExpo }
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        function at(x: real): real { return Math.max(0, Math.min(1, (x - s.knob / 2) / (s.width - s.knob))); }
        onPressed: mouse => s.moved(at(mouse.x))
        onPositionChanged: mouse => { if (pressed) s.moved(at(mouse.x)); }
        onWheel: wheel => notches.feed(wheel.angleDelta.y)
    }
}
