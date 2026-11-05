// Bell chip: bell (crossed out with do-not-disturb) and the number of notifications in the
// history, if any. Click: history drawer (Bar).
import QtQuick
import qs
import qs.ui
import qs.notify

Chip {
    interactive: true
    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: Notifs.dnd ? "\u{f009b}" : "\u{f009a}"
            font.pixelSize: Theme.iconSize
            color: Notifs.list.length ? Theme.bright : Theme.dim
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            visible: Notifs.list.length > 0
            text: Notifs.list.length
        }
    }
}
