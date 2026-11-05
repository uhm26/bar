// Drawer content for the clock: month grid (Monday first), today as a white pill, other
// months' days dim. Arrows or scroll change the month; the grid slides in from the side
// it comes from. Opens on the current month.
import QtQuick
import Quickshell
import qs
import qs.ui

DrawerPage {
    id: panel
    kind: "cal"
    readonly property int cell: 40
    property int year: 0
    property int month: 0 // 0-11

    readonly property date today: Now.date

    function goToday(): void { year = today.getFullYear(); month = today.getMonth(); }
    function step(by: int): void {
        const d = new Date(year, month + by, 1);
        year = d.getFullYear();
        month = d.getMonth();
        grid.instant = true; // jump to the side the month comes from, then glide home
        grid.offset = by;
        grid.instant = false;
        grid.offset = 0;
    }
    onVisibleChanged: if (visible) goToday()
    Component.onCompleted: goToday()

    // 42 days: the weeks touching this month, Monday first.
    readonly property var days: {
        const first = new Date(year, month, 1);
        const lead = (first.getDay() + 6) % 7;
        return Array.from({ length: 42 }, (_, i) => new Date(year, month, 1 - lead + i));
    }
    function same(a: date, b: date): bool {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    implicitWidth: 7 * cell + 2 * Theme.panelPad
    implicitHeight: col.implicitHeight + 2 * Theme.panelPad

    component Arrow: Rectangle {
        id: arrow
        property string glyph
        signal pressed
        width: 28
        height: 28
        radius: 14
        color: area.containsMouse ? Theme.hover : "transparent"
        Label { anchors.centerIn: parent; text: arrow.glyph; color: Theme.bright }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: arrow.pressed() }
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
            Column {
                anchors.verticalCenter: parent.verticalCenter
                x: 4
                Caption { text: Qt.formatDate(panel.today, "dddd").toLowerCase() }
                Label {
                    text: Qt.formatDate(new Date(panel.year, panel.month, 1), "MMMM yyyy")
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    color: Theme.bright
                }
            }
            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 2
                Rectangle {
                    visible: panel.year !== panel.today.getFullYear() || panel.month !== panel.today.getMonth()
                    width: todayLabel.implicitWidth + 20
                    height: 28
                    radius: 14
                    color: todayArea.containsMouse ? Theme.containerHigh : Theme.container
                    Label { id: todayLabel; anchors.centerIn: parent; text: "today"; font.pixelSize: 11 }
                    MouseArea { id: todayArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: panel.goToday() }
                }
                Arrow { glyph: "\u{f0141}"; onPressed: panel.step(-1) }
                Arrow { glyph: "\u{f0142}"; onPressed: panel.step(1) }
            }
        }

        Section {
            reveal: panel.reveal
            step: 1
            width: parent.width
            height: names.height + grid.height + 6

            Row {
                id: names
                Repeater {
                    model: ["mo", "tu", "we", "th", "fr", "sa", "su"]
                    Caption {
                        required property string modelData
                        width: panel.cell
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                    }
                }
            }

            Grid {
                id: grid
                y: names.height + 6
                columns: 7
                // offset ±1 = shifted a cell's width to that side and faded; glides to 0.
                property real offset: 0
                property bool instant: false
                Behavior on offset {
                    enabled: grid.visible && !grid.instant
                    NumberAnimation { duration: Theme.effects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.outExpo }
                }
                transform: Translate { x: grid.offset * 24 }
                opacity: 1 - Math.abs(grid.offset)

                Repeater {
                    model: panel.days
                    Item {
                        id: day
                        required property date modelData
                        readonly property bool isToday: panel.same(modelData, panel.today)
                        readonly property bool inMonth: modelData.getMonth() === panel.month
                        width: panel.cell
                        height: 34
                        Rectangle {
                            anchors.centerIn: parent
                            width: 32
                            height: 28
                            radius: 14
                            color: day.isToday ? Theme.primary : dayArea.containsMouse ? Theme.hover : "transparent"
                        }
                        Label {
                            anchors.centerIn: parent
                            text: day.modelData.getDate()
                            color: day.isToday ? Theme.primaryText : day.inMonth ? Theme.fg : Qt.rgba(1, 1, 1, 0.25)
                        }
                        MouseArea { id: dayArea; anchors.fill: parent; hoverEnabled: true }
                    }
                }
            }

            // Scroll anywhere on the grid: next / previous month (one per notch).
            Timer { id: wheelCooldown; interval: Theme.effects }
            WheelHandler {
                onWheel: event => {
                    if (event.angleDelta.y === 0 || wheelCooldown.running) return;
                    wheelCooldown.start();
                    panel.step(event.angleDelta.y < 0 ? 1 : -1);
                }
            }
        }
    }
}
