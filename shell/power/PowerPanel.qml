// Drawer content for the power chip: lock, log out, reboot, shut down. Lock acts on click;
// the others are hold-to-fill: a white fill sweeps across while held and they
// act only when it is full. Letting go or sliding off drains it back.
import QtQuick
import Quickshell
import qs
import qs.ui
import qs.lock

DrawerPage {
    id: panel
    kind: "power"
    signal done // the bar closes the drawer
    implicitWidth: 260
    implicitHeight: col.implicitHeight + 2 * Theme.panelPad

    function run(what: string): void {
        done();
        if (what === "lock") Lock.lock();
        // Hyprland with a Lua config takes `hl.dsp.exit()`, with a classic hyprland.conf `exit`;
        // the wrong one just fails (non-zero exit), so try Lua first, then the classic one.
        else if (what === "logout") Quickshell.execDetached(["sh", "-c", "hyprctl dispatch 'hl.dsp.exit()' || hyprctl dispatch exit"]);
        else if (what === "reboot") Quickshell.execDetached(["systemctl", "reboot"]);
        else if (what === "poweroff") Quickshell.execDetached(["systemctl", "poweroff"]);
    }

    // One row drawn twice: normal underneath, inverted (white, dark text) in the fill.
    component Face: Item {
        id: face
        property var row // the Action it draws
        property color ink
        width: face.row.width
        height: face.row.height
        Label {
            id: glyph
            anchors { left: parent.left; leftMargin: Theme.pad; verticalCenter: parent.verticalCenter }
            width: Theme.iconBox
            horizontalAlignment: Text.AlignHCenter
            text: face.row.icon
            font.pixelSize: Theme.iconSize
            color: parent.ink
        }
        Label {
            anchors { left: glyph.right; leftMargin: Theme.pad; verticalCenter: parent.verticalCenter }
            text: face.row.label
            color: parent.ink
        }
        Caption {
            anchors { right: parent.right; rightMargin: Theme.pad; verticalCenter: parent.verticalCenter }
            visible: face.row.hold
            text: "hold"
            color: parent.ink
            opacity: 0.6
        }
    }
    component Action: Item {
        id: act
        property string icon
        property string label
        property string what
        property bool hold: true
        width: parent.width
        height: Theme.field
        readonly property bool holding: hold && area.pressed && area.containsMouse
        // The action fires ONLY from this timer: it restarts on every press and must run the
        // full Theme.hold uninterrupted. (It used to fire when an animated fill reached 1; that
        // fired after a short hold and shut the PC down.) The fill below is only the picture.
        Timer {
            interval: Theme.hold
            running: act.holding
            onTriggered: panel.run(act.what)
        }
        property real fill: 0
        NumberAnimation { id: grow; target: act; property: "fill"; from: 0; to: 1; duration: Theme.hold }
        NumberAnimation { id: drain; target: act; property: "fill"; to: 0; duration: Theme.fastEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.outExpo }
        onHoldingChanged: {
            if (holding) { drain.stop(); grow.start(); }
            else { grow.stop(); drain.start(); }
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.fieldRadius
            color: area.containsMouse ? Theme.hover : "transparent"
            clip: true
            Face { row: act; ink: Theme.fg }
            Item {
                width: act.width * act.fill // fractional: no stalled frames
                height: act.height
                clip: true
                Rectangle { width: act.width; height: act.height; radius: Theme.fieldRadius; color: Theme.primary }
                Face { row: act; ink: Theme.primaryText }
            }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (!act.hold) panel.run(act.what)
        }
    }

    Column {
        id: col
        x: Theme.panelPad
        y: Theme.panelPad
        width: panel.width - 2 * Theme.panelPad
        spacing: 2
        // Nerd Font Material icons: lock, logout, restart, power.
        Section { reveal: panel.reveal; step: 0; width: parent.width; height: Theme.field
            Action { icon: "\u{f033e}"; label: "Lock"; what: "lock"; hold: false } }
        Section { reveal: panel.reveal; step: 1; width: parent.width; height: Theme.field
            Action { icon: "\u{f0343}"; label: "Log out"; what: "logout" } }
        Section { reveal: panel.reveal; step: 2; width: parent.width; height: Theme.field
            Action { icon: "\u{f0709}"; label: "Reboot"; what: "reboot" } }
        Section { reveal: panel.reveal; step: 3; width: parent.width; height: Theme.field
            Action { icon: "\u{f0425}"; label: "Shut down"; what: "poweroff" } }
    }
}
