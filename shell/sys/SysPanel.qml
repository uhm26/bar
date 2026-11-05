// Drawer content for the system chip: header, cpu / ram / swap ring cards,
// process list. Sections fade + drop in one after another, driven by the drawer's
// `reveal` (0..1), so closing plays the same steps in reverse.
import QtQuick
import qs
import qs.ui

DrawerPage {
    id: panel
    kind: "sys"
    // The drawer started closing: drop the process menu now, not after the drawer is gone.
    onRevealChanged: if (reveal < 1) procMenu.open = false
    // A process-list viewer while shown (see Sys.view).
    onVisibleChanged: {
        Sys.view(panel, visible);
        if (!visible) procMenu.open = false;
    }
    Component.onCompleted: Sys.view(panel, visible)
    Component.onDestruction: Sys.view(panel, false)
    implicitWidth: 440
    implicitHeight: col.implicitHeight + 2 * Theme.panelPad

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
                icon: "\u{f061a}"
                title: "System"
                subtitle: Sys.up === null ? "" : "up " + Sys.duration(Sys.up)
                Rectangle {
                    visible: Sys.temp !== null
                    width: temp.implicitWidth + 24
                    height: 28
                    radius: 14
                    color: Theme.container
                    Label { id: temp; anchors.centerIn: parent; text: "\u{f050f} " + Math.round(Sys.temp ?? 0) + "°C" }
                }
            }
        }

        Section {
            reveal: panel.reveal
            step: 1
            width: parent.width
            height: 130
            Row {
                spacing: 10
                Repeater {
                    model: [
                        { label: "cpu", value: () => Sys.cpu, off: () => false,
                          detail: () => Math.round(Sys.cpu) + "% busy" },
                        { label: "ram", value: () => Sys.memPct, off: () => false,
                          detail: () => Sys.size(Sys.memUsed) + " / " + Sys.size(Sys.memTotal) },
                        { label: "swap", value: () => Sys.swapPct, off: () => !Sys.hasSwap,
                          detail: () => Sys.hasSwap ? Sys.size(Sys.swapUsed) + " / " + Sys.size(Sys.swapTotal) : "none" },
                    ]
                    Card {
                        required property var modelData
                        width: (col.width - 20) / 3
                        height: 130
                        Ring {
                            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 14 }
                            label: parent.modelData.label
                            value: parent.modelData.value()
                            off: parent.modelData.off()
                        }
                        Caption {
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 12 }
                            text: parent.modelData.detail()
                        }
                    }
                }
            }
        }

        Section {
            reveal: panel.reveal
            step: 2
            width: parent.width
            height: procCard.height
            Card {
                id: procCard
                width: parent.width
                height: procs.implicitHeight + 58
                Caption { x: 14; y: 18; text: "processes" }
                Segmented {
                    id: sort
                    anchors { right: parent.right; rightMargin: 10; top: parent.top; topMargin: 10 }
                    width: 96
                    implicitHeight: 26
                    options: ["cpu", "ram"]
                    onPicked: index => current = index
                }
                ProcList {
                    id: procs
                    x: 8
                    y: 46
                    width: parent.width - 16
                    byMem: sort.current === 1
                    // No menu for the session and the bar itself: one misclick would end them.
                    onMenu: (p, at) => { if (p.pids.length && !["Hyprland", "quickshell"].includes(p.name)) procMenu.show(p, mapToItem(panel, at), Qt.size(panel.width, panel.height)); }
                }
            }
        }
    }

    // Click anywhere else in the panel closes the menu.
    MouseArea {
        anchors.fill: parent
        enabled: procMenu.open
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: procMenu.open = false
    }
    ProcMenu { id: procMenu }
}
