// Right-click menu for a process row: End (SIGTERM, asks it to quit) or Force kill
// (SIGKILL), sent to every process in the group via util-linux `kill`.
// Processes of other users (root) just fail: kill can't signal them.
import QtQuick
import QtQuick.Effects
import Quickshell
import qs
import qs.ui

Rectangle {
    id: menu
    property var proc: null // the group last shown, kept while fading out
    property bool open: false

    function show(p: var, at: point, area: size): void {
        proc = p;
        x = Math.min(at.x, area.width - width - 8);
        y = Math.min(at.y, area.height - height - 8);
        open = true;
    }
    // Fresh pids at click time: the menu may sit open while processes come and go.
    function send(sig: string): void {
        const now = Sys.procs.find(q => q.name === proc.name);
        if (now && now.pids.length) Quickshell.execDetached(["kill", "-" + sig].concat(now.pids.map(String)));
        open = false;
    }

    width: 176
    height: col.implicitHeight + 12
    radius: 12
    color: Theme.menu
    border { width: 1; color: Theme.outline }

    RectangularShadow {
        anchors.fill: parent
        z: -1 // under the menu
        radius: parent.radius
        offset.y: 6
        blur: 24
        spread: 0
        color: Qt.rgba(0, 0, 0, 0.55)
    }
    visible: opacity > 0
    opacity: open ? 1 : 0
    scale: open ? 1 : 0.96
    transformOrigin: Item.TopLeft
    Behavior on opacity {
        NumberAnimation { duration: Theme.fastEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.outExpo }
    }
    Behavior on scale {
        NumberAnimation { duration: Theme.fastEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.outExpo }
    }

    component Entry: Rectangle {
        id: entry
        property string label
        property string hint
        signal picked
        width: col.width
        height: 32
        radius: 8
        color: area.containsMouse ? Theme.hover : "transparent"
        Label { x: 10; anchors.verticalCenter: parent.verticalCenter; text: entry.label; color: Theme.bright }
        Label {
            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            text: entry.hint
            font.pixelSize: 11
            color: Theme.dim
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: entry.picked()
        }
    }

    Column {
        id: col
        x: 6
        y: 6
        width: parent.width - 12
        Label {
            x: 10
            width: parent.width - 20
            height: 26
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            text: !menu.proc ? "" : menu.proc.name + (menu.proc.pids.length > 1 ? "  ×" + menu.proc.pids.length : "")
            font.pixelSize: 11
            color: Theme.dim
        }
        Entry { label: "End"; hint: "TERM"; onPicked: menu.send("TERM") }
        Entry { label: "Force kill"; hint: "KILL"; onPicked: menu.send("KILL") }
    }
}
