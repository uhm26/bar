// Drawer content for the volume chip: output volume (icon = mute) and the output
// device picker. PipeWire nodes are only bound (tracked) while the drawer shows.
import QtQuick
import Quickshell.Services.Pipewire
import qs
import qs.ui

DrawerPage {
    id: panel
    kind: "vol"
    readonly property var sink: Pipewire.defaultAudioSink
    // Not on n.audio: unbound nodes may not have it yet (the tracker binds only listed ones).
    readonly property var outputs: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream)
    PwObjectTracker {
        objects: panel.visible ? [panel.sink].concat(panel.outputs).filter(o => o) : []
    }

    function nameOf(n: var): string {
        return n?.properties["application.name"] || n?.description || n?.nickname || n?.name || "";
    }

    implicitWidth: 360
    implicitHeight: col.implicitHeight + 2 * Theme.panelPad
    TextMetrics { id: pct; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.weight: Font.Medium; text: "100%" }

    // One volume line: icon (click = mute), slider, percent.
    component Level: Item {
        id: level
        property var node: null
        property string icon
        property string mutedIcon
        readonly property bool ready: node?.audio != null
        readonly property bool muted: ready && node.audio.muted
        width: parent.width
        height: 32
        Rectangle {
            id: muteButton
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            height: 30
            radius: 15
            color: muteArea.containsMouse ? Theme.hover : "transparent"
            Label {
                anchors.centerIn: parent
                text: level.muted ? level.mutedIcon : level.icon
                font.pixelSize: Theme.iconSize
                color: level.muted ? Theme.dim : Theme.bright
            }
            MouseArea {
                id: muteArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (level.ready) level.node.audio.muted = !level.node.audio.muted
            }
        }
        Slider {
            anchors { left: muteButton.right; leftMargin: 8; right: value.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
            value: level.ready ? level.node.audio.volume : 0
            dim: level.muted
            onMoved: v => { if (level.ready) level.node.audio.volume = v; }
        }
        Label {
            id: value
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: Math.ceil(pct.advanceWidth)
            horizontalAlignment: Text.AlignRight
            text: level.ready ? Math.round(level.node.audio.volume * 100) + "%" : "--"
            color: level.muted ? Theme.dim : Theme.fg
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
            PanelHeader { anchors.fill: parent; icon: "\u{f057e}"; title: "Sound"; subtitle: panel.nameOf(panel.sink) }
        }

        Section {
            reveal: panel.reveal
            step: 1
            width: parent.width
            height: levels.height
            Card {
                id: levels
                width: parent.width
                height: levelCol.implicitHeight + 16
                Column {
                    id: levelCol
                    x: 10
                    y: 8
                    width: parent.width - 24
                    Level { node: panel.sink; icon: "\u{f057e}"; mutedIcon: "\u{f075f}" }
                }
            }
        }

        Section {
            reveal: panel.reveal
            step: 2
            width: parent.width
            height: devices.height
            visible: panel.outputs.length > 1
            Card {
                id: devices
                width: parent.width
                height: deviceCol.implicitHeight + 42
                Caption { x: 14; y: 12; text: "output" }
                Column {
                    id: deviceCol
                    x: 6
                    y: 32
                    width: parent.width - 12
                    Repeater {
                        model: panel.outputs
                        Rectangle {
                            id: device
                            required property var modelData
                            readonly property bool current: modelData === panel.sink
                            width: deviceCol.width
                            height: 32
                            radius: 10
                            color: deviceArea.containsMouse ? Theme.hover : "transparent"
                            Label {
                                x: 10
                                width: parent.width - 44
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                text: panel.nameOf(device.modelData)
                                color: device.current ? Theme.bright : Theme.fg
                            }
                            Label {
                                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                text: device.current ? "\u{f012c}" : ""
                                color: Theme.bright
                            }
                            MouseArea {
                                id: deviceArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Pipewire.preferredDefaultAudioSink = device.modelData
                            }
                        }
                    }
                }
            }
        }
    }
}
