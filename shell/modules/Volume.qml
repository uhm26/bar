// Volume of the default sink: speaker icon + percent. Click = sound drawer (Bar), right-click
// = mute, scroll = ±5 %.
// Icon and number sit in fixed-width slots so the chip never changes size.
import QtQuick
import qs
import qs.ui
import Quickshell.Services.Pipewire

Chip {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink?.audio != null
    readonly property bool muted: ready && sink.audio.muted
    readonly property int percent: ready ? Math.round(sink.audio.volume * 100) : 0
    interactive: ready
    pad: 10 // compact
    onRightClicked: sink.audio.muted = !sink.audio.muted
    onScrolled: dir => sink.audio.volume = Math.max(0, Math.min(Math.max(1, sink.audio.volume), sink.audio.volume + dir * 0.05))

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] } // keeps volume/mute live
    TextMetrics { id: widest; font: number.font; text: "100%" }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        // Nerd Font Material icons: volume off / low / medium / high.
        Label {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.iconBox
            horizontalAlignment: Text.AlignHCenter
            text: root.muted || !root.ready ? "\u{f0581}" : root.percent < 34 ? "\u{f057f}"
                : root.percent < 67 ? "\u{f0580}" : "\u{f057e}"
            font.pixelSize: Theme.iconSize
            color: root.muted ? Theme.dim : Theme.bright
        }
        Label {
            id: number
            anchors.verticalCenter: parent.verticalCenter
            width: Math.ceil(widest.advanceWidth)
            horizontalAlignment: Text.AlignLeft // short values leave room at the chip end, not mid-chip
            text: root.ready ? root.percent + "%" : "--"
            color: root.muted ? Theme.dim : Theme.fg
        }
    }
}
