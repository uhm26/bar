// One list row: name left, a small pill meter (share 0..1, glides while shown) and the value
// right in a fixed-width slot. Shared by the process list and the network apps list.
import QtQuick
import qs

Item {
    id: row
    property string name
    property real share: 0
    property string value
    property real valueWidth: 60
    property color nameColor: Theme.fg
    height: 30

    Label {
        anchors { left: parent.left; leftMargin: 6; right: meter.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
        elide: Text.ElideRight
        text: row.name
        color: row.nameColor
    }
    Rectangle {
        id: meter
        anchors { right: valueLabel.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
        width: 64
        height: 4
        radius: 2
        color: Theme.containerHigh
        Rectangle {
            width: Math.max(parent.height, parent.width * row.share)
            height: parent.height
            radius: 2
            color: Theme.bright
            opacity: row.share > 0.005 ? 1 : 0
            Behavior on width {
                enabled: row.visible
                NumberAnimation { duration: Theme.fastSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.graphic }
            }
        }
    }
    Label {
        id: valueLabel
        anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
        width: Math.ceil(row.valueWidth)
        horizontalAlignment: Text.AlignRight
        text: row.value
        color: Theme.bright
    }
}
