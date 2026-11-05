// M3 segmented toggle: options in a container, a white pill glides to the picked one.
import QtQuick
import qs

Rectangle {
    id: seg
    property var options: []
    property int current: 0
    signal picked(int index)
    readonly property real cell: width / Math.max(1, options.length)

    implicitHeight: Theme.chip
    radius: Theme.chipRadius
    color: Theme.container

    Rectangle {
        x: 3 + seg.current * seg.cell
        y: 3
        width: seg.cell - 6
        height: seg.height - 6
        radius: height / 2
        color: Theme.primary
        Behavior on x {
            NumberAnimation { duration: Theme.fastSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.graphic }
        }
    }

    Row {
        Repeater {
            model: seg.options
            Label {
                id: option
                required property int index
                required property string modelData
                width: seg.cell
                height: seg.height
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: modelData
                color: index === seg.current ? Theme.primaryText : area.containsMouse ? Theme.bright : Theme.dim
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: seg.picked(option.index)
                }
            }
        }
    }
}
