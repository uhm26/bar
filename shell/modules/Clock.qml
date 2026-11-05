// Clock chip: time bright + date (dd.MM) dim; scroll → media page (PagedChip) with
// previous / play-pause / next and the track. Follows the player that is playing, else the
// first one. Click: calendar on the clock page (Bar), the media drawer on the media page (Bar).
// The track sits in a fixed-width slot, so the chip doesn't jump on every track change.
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs
import qs.ui
import qs.media

PagedChip {
    id: root
    first: time
    second: media
    glide: !trackText.swapping
    readonly property var players: Mpris.players.values
    readonly property var player: players.find(p => p.isPlaying) ?? players[0] ?? null
    readonly property string track: !player ? "nothing playing"
        : [player.trackTitle, player.trackArtist].filter(s => s).join(" — ") || player.identity

    TextMetrics { id: slot; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.weight: Font.Medium; text: "x".repeat(24) }

    component Button: Rectangle {
        id: button
        property string glyph
        property bool active: true
        signal pressed
        width: 22
        height: 22
        radius: 11
        anchors.verticalCenter: parent.verticalCenter
        color: area.containsMouse && active ? Theme.hover : "transparent"
        Label { anchors.centerIn: parent; text: button.glyph; font.pixelSize: Theme.iconSize; color: button.active ? Theme.bright : Theme.dim }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            enabled: button.active
            cursorShape: Qt.PointingHandCursor
            onClicked: button.pressed()
        }
    }

    Item {
        width: root.page === 0 ? time.width : media.width
        height: root.height

        Page {
            room: root.room
            centered: true
            id: time
            Label { text: Qt.formatDateTime(Now.date, "HH:mm"); color: Theme.bright }
            Label { text: Qt.formatDateTime(Now.date, "dd.MM"); color: Theme.dim }
        }
        Page {
            room: root.room
            centered: true
            id: media
            offset: 1
            spacing: 2
            // Nerd Font Material icons: skip previous, play / pause, skip next.
            Label { visible: !root.player; anchors.verticalCenter: parent.verticalCenter; text: "\u{f075a}"; font.pixelSize: Theme.iconSize; color: Theme.dim }
            Button { visible: root.player !== null; glyph: "\u{f04ae}"; active: root.player?.canGoPrevious ?? false; onPressed: root.player.previous() }
            Button {
                visible: root.player !== null
                glyph: root.player?.isPlaying ? "\u{f03e4}" : "\u{f040a}"
                active: root.player?.canTogglePlaying ?? false
                onPressed: root.player.togglePlaying()
            }
            Button { visible: root.player !== null; glyph: "\u{f04ad}"; active: root.player?.canGoNext ?? false; onPressed: root.player.next() }
            SwapText { // track changes fade, the width glides with them (chip follows, no own glide)
                id: trackText
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: root.player ? 8 : 4
                maxWidth: Math.ceil(slot.advanceWidth) + leftPadding // long titles elide at 24 chars
                width: fitWidth
                elide: Text.ElideRight
                target: root.track
                color: root.player ? Theme.fg : Theme.dim
            }
        }
    }
}
