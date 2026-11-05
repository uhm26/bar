// One page of a paged chip (system/network, clock/media): offset 0 = shown, ±1 = moved
// 12 px up/down and faded. `instant` places it without animating, so an incoming page can
// jump to the side it enters from before gliding home.
// `room` = the chip's current inner width (it glides): a page is only visible once it fits,
// so text never sticks out past the chip's rounded ends while the chip grows or shrinks.
// `centered`: for a centered chip, so the page stays in the middle while it widens.
import QtQuick
import qs

Row {
    property real offset: 0
    property bool instant: false
    property real room: Infinity
    property bool centered: false
    Behavior on offset {
        enabled: !instant
        NumberAnimation { duration: Theme.effects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.outExpo }
    }
    spacing: 10
    x: centered ? (room - width) / 2 : 0
    y: (parent.height - height) / 2 + offset * 12
    // Fades over the last 16 px of missing room.
    opacity: Math.min(1 - Math.abs(offset), Math.max(0, Math.min(1, (room - width) / 16 + 1)))
    visible: opacity > 0
}
