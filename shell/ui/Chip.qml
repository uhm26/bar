// Module container: a pill on the bar with an M3 hover layer and optional click/scroll.
// Arrives with a staggered fade + drop (`order`), width glides when content changes.
import QtQuick
import qs

Rectangle {
    id: chip
    default property alias content: inner.data
    property int order: 0
    property int pad: Theme.pad
    property bool interactive: false
    property bool highlighted: false // its drawer is open
    property bool glide: true // width glides on content changes; off while content animates its own width
    signal clicked
    signal rightClicked
    signal scrolled(int dir)
    Notches { id: notches; onNotch: d => chip.scrolled(d) }

    implicitWidth: inner.childrenRect.width + 2 * pad
    implicitHeight: Theme.chip
    radius: Theme.chipRadius
    color: highlighted ? Theme.containerHigh : Theme.container
    Behavior on implicitWidth {
        enabled: chip.glide
        NumberAnimation { duration: Theme.fastSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.graphic }
    }
    Behavior on color {
        ColorAnimation { duration: Theme.effects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.outExpo }
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Theme.hover
        opacity: chip.interactive && hover.hovered ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.fastEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.outExpo }
        }
    }
    HoverHandler { id: hover }
    MouseArea {
        anchors.fill: parent
        enabled: chip.interactive
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => mouse.button === Qt.RightButton ? chip.rightClicked() : chip.clicked()
        onWheel: wheel => notches.feed(wheel.angleDelta.y)
    }

    Item {
        id: inner
        x: chip.pad
        width: childrenRect.width
        height: parent.height
    }

    // Entrance.
    opacity: 0
    transform: Translate { id: drop; y: -Theme.rise }
    Component.onCompleted: arrive.start()
    SequentialAnimation {
        id: arrive
        PauseAnimation { duration: 100 + chip.order * Theme.stagger }
        ParallelAnimation {
            NumberAnimation { target: chip; property: "opacity"; to: 1; duration: Theme.effects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.outExpo }
            NumberAnimation { target: drop; property: "y"; to: 0; duration: Theme.entrance; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.outExpo }
        }
    }
}
