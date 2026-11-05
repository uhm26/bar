// System chip: cpu · ram · swap, scroll → network down · up (PagedChip). Click opens the
// drawer for the shown page (Bar). Numbers sit in fixed slots, so values never resize it
// (a rare "100%" spills one character into the gap after it).
import QtQuick
import qs
import qs.ui
import qs.sys

PagedChip {
    id: root
    first: stats
    second: network

    TextMetrics { id: pct; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.weight: Font.Medium; text: "99%" }
    TextMetrics { id: rate; font: pct.font; text: "999 KB/s" }

    component Stat: Row {
        property string icon
        property string text
        property real slot
        property bool dim: false
        spacing: 5
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: parent.icon
            font.pixelSize: Theme.iconSize
            color: parent.dim ? Theme.dim : Theme.bright
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.ceil(parent.slot)
            text: parent.text
            color: parent.dim ? Theme.dim : Theme.fg
        }
    }

    Item {
        width: root.page === 0 ? stats.width : network.width
        height: root.height

        // Nerd Font Material icons: cpu, memory, swap / arrow down, arrow up.
        Page {
            room: root.room
            id: stats
            Stat { icon: "\u{f0ee0}"; slot: pct.advanceWidth; text: Sys.ready ? Math.round(Sys.cpu) + "%" : "--" }
            Stat { icon: "\u{f035b}"; slot: pct.advanceWidth; text: Sys.ready ? Math.round(Sys.memPct) + "%" : "--" }
            Stat { icon: "\u{f04e1}"; slot: pct.advanceWidth; text: !Sys.hasSwap ? "off" : Math.round(Sys.swapPct) + "%"; dim: !Sys.hasSwap }
        }
        Page {
            room: root.room
            id: network
            offset: 1
            Stat { icon: "\u{f0045}"; slot: rate.advanceWidth; text: Sys.ready ? Sys.speed(Sys.netDown) : "--" }
            Stat { icon: "\u{f005d}"; slot: rate.advanceWidth; text: Sys.ready ? Sys.speed(Sys.netUp) : "--" }
        }
    }
}
