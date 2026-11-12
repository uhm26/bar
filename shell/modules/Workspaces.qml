// Workspaces of this screen as numbers. A white pill slides to the active one and
// stretches on the way: the leading edge moves first. Click switches.
import QtQuick
import Quickshell
import qs
import qs.ui
import Quickshell.Hyprland

Chip {
    id: root
    required property var screen
    readonly property var monitor: Hyprland.monitorFor(screen)
    // By id: Hyprland lists workspaces in creation order (a new "2" would land after "5").
    readonly property var list: Hyprland.workspaces.values
        .filter(w => w.id > 0 && w.monitor === monitor)
        .sort((a, b) => a.id - b.id)

    readonly property int index: list.findIndex(w => w === monitor?.activeWorkspace)
    pad: (Theme.chip - Theme.pill) / 2

    // Pill edges. Set by place() so the duration knows the direction first.
    property real pillStart: 0
    property real pillEnd: 0
    property bool forward: true
    property int last: -1
    function place(): void {
        if (index < 0) return;
        forward = index >= last;
        last = index;
        pillStart = index * Theme.cell;
        pillEnd = (index + 1) * Theme.cell;
    }
    onIndexChanged: place()
    Component.onCompleted: place()
    Behavior on pillStart {
        NumberAnimation { duration: root.forward ? Theme.trail : Theme.lead; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.graphic }
    }
    Behavior on pillEnd {
        NumberAnimation { duration: root.forward ? Theme.lead : Theme.trail; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.graphic }
    }

    Item {
        width: root.list.length * Theme.cell
        height: Theme.pill
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            visible: root.index >= 0
            x: root.pillStart
            width: root.pillEnd - root.pillStart
            height: parent.height
            radius: Theme.pillRadius
            color: Theme.primary
        }

        Row {
            Repeater {
                // ScriptModel: a workspace coming or going adds or drops one number; a plain array
                // rebuilt every number (and its click area) on each change.
                model: ScriptModel { values: root.list }
                Label {
                    id: num
                    required property var modelData
                    readonly property bool active: modelData === root.monitor?.activeWorkspace
                    width: Theme.cell
                    height: Theme.pill
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: modelData.name
                    color: active ? Theme.primaryText : area.containsMouse ? Theme.bright : Theme.dim
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: num.modelData.activate()
                    }
                }
            }
        }
    }
}
