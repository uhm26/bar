// Top processes (grouped by name), by cpu or memory: name left, small pill meter and the
// value right. No row backgrounds. Always `rows` rows tall so the panel never changes size.
// Meters are absolute: cpu out of 100 % of the machine, memory out of total RAM.
import QtQuick
import qs
import qs.ui

Column {
    id: list
    property bool byMem: false
    property int rows: 7
    readonly property var picks: Sys.procs.slice()
        .sort((a, b) => byMem ? b.mem - a.mem : b.cpu - a.cpu || b.mem - a.mem)
        .slice(0, rows)
    // Absolute: % of the whole machine, or share of total RAM (15 % must not look full).
    readonly property real full: byMem ? Math.max(Sys.memTotal, 1) : 100
    spacing: 0
    signal menu(var proc, point at) // right-click on a row; `at` in this list's coordinates

    TextMetrics { id: widest; font: probe.font; text: "100.0%" }
    Label { id: probe; visible: false }

    Repeater {
        model: list.rows
        Item {
            id: row
            required property int index
            readonly property var p: list.picks[index] ?? null
            readonly property real share: p ? Math.min(1, (list.byMem ? p.mem : p.cpu) / list.full) : 0
            width: list.width
            height: 30

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: Theme.hover
                opacity: area.containsMouse && row.p ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: Theme.fastEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.outExpo }
                }
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.RightButton
                onClicked: mouse => { if (row.p) list.menu(row.p, mapToItem(list, mouse.x, mouse.y)); }
            }
            opacity: p ? 1 : 0

            MeterRow {
                anchors.fill: parent
                name: row.p ? row.p.name : ""
                nameColor: row.index === 0 ? Theme.bright : Theme.fg
                share: row.share
                value: !row.p ? "" : list.byMem ? Sys.size(row.p.mem) : row.p.cpu.toFixed(1) + "%"
                valueWidth: widest.advanceWidth
            }
        }
    }
}
