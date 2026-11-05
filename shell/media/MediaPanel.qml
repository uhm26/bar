// Drawer content for the clock's media page, landscape: cover left; right: player, title,
// artist · album, controls and the
// seek bar on one row. Plain drawer gray behind it.
import QtQuick
import Quickshell.Services.Mpris
import qs
import qs.ui

DrawerPage {
    id: panel
    kind: "media"
    readonly property var players: Mpris.players.values
    property var chosen: null
    readonly property var player: players.includes(chosen) ? chosen : players.find(p => p.isPlaying) ?? players[0] ?? null
    readonly property string art: player?.trackArtUrl ?? ""
    readonly property int cover: 120
    implicitWidth: 672
    implicitHeight: cover + 2 * Theme.panelPad


    // Position isn't pushed by players: ask while the seek bar is visible and playing.
    Timer {
        interval: 250
        repeat: true
        running: panel.visible && (panel.player?.isPlaying ?? false)
        onTriggered: panel.player.positionChanged()
    }
    function time(s: real): string {
        const t = Math.max(0, Math.floor(s));
        return Math.floor(t / 60) + ":" + String(t % 60).padStart(2, "0");
    }
    function cycle(by: int): void {
        const i = players.indexOf(player);
        chosen = players[(i + by + players.length) % players.length];
    }

    component Control: Rectangle {
        id: control
        property string glyph
        property bool big: false
        property bool active: true
        signal pressed
        width: big ? 44 : 34
        height: width
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        color: big ? Theme.primary : area.containsMouse && active ? Theme.hover : "transparent"
        scale: area.pressed ? 0.92 : 1
        Behavior on scale {
            NumberAnimation { duration: Theme.fastEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.outExpo }
        }
        Label {
            anchors.centerIn: parent
            text: control.glyph
            font.pixelSize: control.big ? 22 : 18
            color: control.big ? Theme.primaryText : control.active ? Theme.bright : Theme.dim
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            enabled: control.active
            cursorShape: Qt.PointingHandCursor
            onClicked: control.pressed()
        }
    }

    // Cover: crossfades on skips, never an empty frame (Cover.qml).
    Section {
        reveal: panel.reveal
        step: 0
        x: Theme.panelPad
        y: Theme.panelPad
        width: panel.cover
        height: panel.cover
        Cover { anchors.fill: parent; source: panel.art }
    }

    // Right column.
    Item {
        id: info
        x: Theme.panelPad + panel.cover + 20
        y: Theme.panelPad
        width: panel.width - x - Theme.panelPad
        height: panel.cover

        Section {
            reveal: panel.reveal
            step: 1
            width: parent.width
            height: 58
            Caption {
                width: parent.width - (switcher.visible ? switcher.width + 8 : 0)
                elide: Text.ElideRight
                text: (panel.player?.identity ?? "media").toLowerCase()
            }
            Row {
                id: switcher
                anchors.right: parent.right
                visible: panel.players.length > 1
                spacing: 2
                Control { glyph: "\u{f0141}"; width: 22; onPressed: panel.cycle(-1) }
                Control { glyph: "\u{f0142}"; width: 22; onPressed: panel.cycle(1) }
            }
            SwapText {
                y: 16
                width: parent.width
                elide: Text.ElideRight
                target: panel.player?.trackTitle || "nothing playing"
                font.pixelSize: 18
                font.weight: Font.DemiBold
                color: Theme.bright
            }
            SwapText {
                y: 40
                width: parent.width
                elide: Text.ElideRight
                target: [panel.player?.trackArtist, panel.player?.trackAlbum].filter(s => s).join("  ·  ")
                color: Theme.dim
            }
        }

        // Controls and seek bar on one row.
        Section {
            reveal: panel.reveal
            step: 3
            anchors.bottom: parent.bottom
            width: parent.width
            height: 44
            Row {
                id: controls
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                // Nerd Font Material icons: skip previous, play / pause, skip next.
                Control { glyph: "\u{f04ae}"; active: panel.player?.canGoPrevious ?? false; onPressed: panel.player.previous() }
                Control {
                    big: true
                    glyph: panel.player?.isPlaying ? "\u{f03e4}" : "\u{f040a}"
                    active: panel.player?.canTogglePlaying ?? false
                    onPressed: panel.player.togglePlaying()
                }
                Control { glyph: "\u{f04ad}"; active: panel.player?.canGoNext ?? false; onPressed: panel.player.next() }
            }
            Row {
                anchors { left: controls.right; leftMargin: 16; right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 10
                visible: panel.player?.lengthSupported ?? false
                Caption {
                    id: elapsed
                    anchors.verticalCenter: parent.verticalCenter
                    text: panel.time(panel.player?.position ?? 0)
                }
                Slider {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - elapsed.width - total.width - 2 * parent.spacing
                    value: panel.player && panel.player.length > 0 ? panel.player.position / panel.player.length : 0
                    onMoved: v => { if (panel.player?.canSeek) panel.player.position = v * panel.player.length; }
                }
                Caption {
                    id: total
                    anchors.verticalCenter: parent.verticalCenter
                    text: panel.time(panel.player?.length ?? 0)
                }
            }
        }
    }
}
