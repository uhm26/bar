// Drawer content for the system chip's network page: header, download / upload cards,
// 60 s graph, and apps (TCP) by download or upload, like the process list.
import QtQuick
import qs
import qs.ui

DrawerPage {
    id: panel
    kind: "net"
    // A per-app network viewer while shown (see Sys.viewNet): bar-sys runs `ss` only then.
    onVisibleChanged: Sys.viewNet(panel, visible)
    Component.onCompleted: Sys.viewNet(panel, visible)
    Component.onDestruction: Sys.viewNet(panel, false)

    // Apps sorted by the picked direction, then "other": interface total minus all apps
    // (UDP: voice, games, QUIC). Fixed row count so the panel never changes height.
    readonly property bool byUp: sort.current === 1
    readonly property int rows: 6
    readonly property real total: byUp ? Sys.netUp : Sys.netDown
    readonly property var appRows: {
        if (!visible) return []; // hidden: don't recompute every second
        const all = Sys.netApps.map(a => ({ name: a.name, rate: byUp ? a.up : a.down }))
            .filter(a => a.rate > 0)
            .sort((a, b) => b.rate - a.rate);
        const other = Math.max(0, total - all.reduce((s, a) => s + a.rate, 0));
        return all.slice(0, rows - 1).concat([{ name: "other · udp", rate: other, other: true }]);
    }
    TextMetrics { id: rateSlot; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.weight: Font.Medium; text: "999 KB/s" }
    implicitWidth: 440
    implicitHeight: col.implicitHeight + 2 * Theme.panelPad

    component Speed: Card {
        id: speed
        property string icon
        property string label
        property real now
        property bool primary: true
        height: 70
        Row {
            x: 14
            y: 12
            spacing: 6
            Label { text: speed.icon; font.pixelSize: Theme.iconSize; color: speed.primary ? Theme.bright : Theme.dim }
            Caption { anchors.verticalCenter: parent.verticalCenter; text: speed.label }
        }
        Label {
            x: 14
            y: 34
            text: Sys.speed(speed.now)
            font.pixelSize: 20
            font.weight: Font.DemiBold
            color: Theme.bright
        }
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
            PanelHeader { anchors.fill: parent; icon: "\u{f0317}"; title: "Network" }
        }

        Section {
            reveal: panel.reveal
            step: 1
            width: parent.width
            height: 70
            Row {
                spacing: 10
                Speed { width: (col.width - 10) / 2; icon: "\u{f0045}"; label: "download"; now: Sys.netDown }
                Speed { width: (col.width - 10) / 2; icon: "\u{f005d}"; label: "upload"; now: Sys.netUp; primary: false }
            }
        }

        Section {
            reveal: panel.reveal
            step: 2
            width: parent.width
            height: 150
            Card {
                anchors.fill: parent
                Caption { x: 14; y: 10; text: "last 60 s" }
                Row {
                    anchors { right: parent.right; rightMargin: 14 }
                    y: 10
                    spacing: 12
                    Row { spacing: 5; Rectangle { width: 10; height: 2; radius: 1; color: Theme.bright; anchors.verticalCenter: parent.verticalCenter } Caption { text: "down" } }
                    Row { spacing: 5; Rectangle { width: 10; height: 2; radius: 1; color: Theme.dim; anchors.verticalCenter: parent.verticalCenter } Caption { text: "up" } }
                }
                NetGraph { id: graph; x: 14; y: 34; width: parent.width - 28; height: parent.height - 56 }
                Caption {
                    x: 14
                    anchors { bottom: parent.bottom; bottomMargin: 6 }
                    text: "scale " + Sys.speed(graph.peak)
                }
            }
        }

        // Same shape as the process list: toggle, name, mini meter (share of the current
        // total in that direction), value.
        Section {
            reveal: panel.reveal
            step: 3
            width: parent.width
            height: appsCard.height
            Card {
                id: appsCard
                width: parent.width
                height: appsCol.implicitHeight + 58
                Caption { x: 14; y: 18; text: "apps · tcp" }
                Segmented {
                    id: sort
                    anchors { right: parent.right; rightMargin: 10; top: parent.top; topMargin: 10 }
                    width: 96
                    implicitHeight: 26
                    options: ["down", "up"]
                    onPicked: index => current = index
                }
                Column {
                    id: appsCol
                    x: 8
                    y: 46
                    width: parent.width - 16
                    Repeater {
                        model: panel.rows
                        MeterRow {
                            id: arow
                            required property int index
                            readonly property var a: panel.appRows[index] ?? null
                            width: appsCol.width
                            opacity: a ? 1 : 0
                            name: a ? a.name : ""
                            nameColor: !a || a.other ? Theme.dim : index === 0 ? Theme.bright : Theme.fg
                            share: a && panel.total > 0 ? Math.min(1, a.rate / panel.total) : 0
                            value: a ? Sys.speed(a.rate) : ""
                            valueWidth: rateSlot.advanceWidth
                        }
                    }
                }
            }
        }
    }
}
