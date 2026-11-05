// Drawer content for the bell chip: notification history (newest first), do-not-disturb
// and clear-all. Long lists scroll inside a fixed maximum height.
import QtQuick
import Quickshell
import qs
import qs.ui

DrawerPage {
    id: panel
    kind: "notif"
    readonly property var items: Notifs.list.slice().reverse()
    implicitWidth: 400
    implicitHeight: col.implicitHeight + 2 * Theme.panelPad

    component Pill: Rectangle {
        id: pill
        property string label
        property bool active: false
        signal pressed
        width: pillLabel.implicitWidth + 22
        height: 28
        radius: 14
        color: active ? Theme.primary : pillArea.containsMouse ? Theme.containerHigh : Theme.container
        Behavior on color {
            ColorAnimation { duration: Theme.fastEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.outExpo }
        }
        Label { id: pillLabel; anchors.centerIn: parent; text: pill.label; font.pixelSize: 11; color: pill.active ? Theme.primaryText : Theme.fg }
        MouseArea { id: pillArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pill.pressed() }
    }

    Column {
        id: col
        x: Theme.panelPad
        y: Theme.panelPad
        width: parent.width - 2 * Theme.panelPad
        spacing: 12

        Section {
            reveal: panel.reveal
            step: 0
            width: parent.width
            height: 40
            PanelHeader {
                anchors.fill: parent
                icon: Notifs.dnd ? "\u{f009b}" : "\u{f009a}"
                title: "Notifications"
                subtitle: panel.items.length ? panel.items.length + " unread" : "all caught up"
                Pill { label: "do not disturb"; active: Notifs.dnd; onPressed: Notifs.dnd = !Notifs.dnd }
                Pill { label: "clear"; visible: panel.items.length > 0; onPressed: Notifs.clear() }
            }
        }

        Section {
            reveal: panel.reveal
            step: 1
            width: parent.width
            height: panel.items.length ? Math.min(list.contentHeight, 440) : 80
            Caption {
                visible: panel.items.length === 0
                anchors.centerIn: parent
                text: "nothing new"
            }
            ListView {
                id: list
                anchors.fill: parent
                visible: panel.items.length > 0
                clip: true
                spacing: 8
                boundsBehavior: Flickable.StopAtBounds
                // ScriptModel: cards stay when another one goes, so only the leaving one animates.
                model: ScriptModel { values: panel.items }
                delegate: NotifCard {
                    required property var modelData
                    width: list.width
                    n: modelData
                    onGone: modelData.dismiss() // after its exit animation
                }
            }
        }
    }
}
