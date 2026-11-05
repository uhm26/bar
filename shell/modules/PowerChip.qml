// Power chip at the bar's right end: just the power icon. Click: power drawer (Bar).
import QtQuick
import qs
import qs.ui

Chip {
    interactive: true
    Label {
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.iconBox
        horizontalAlignment: Text.AlignHCenter
        text: "\u{f0425}" // Nerd Font Material: power
        font.pixelSize: Theme.iconSize
        color: Theme.bright
    }
}
