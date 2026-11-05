// A drawer panel's header: round icon badge, title, optional caption; anything placed
// inside goes to the right side (pills, toggles).
import QtQuick
import qs

Item {
    id: header
    property string icon
    property string title
    property string subtitle
    default property alias trailing: rightSide.data // not `right`: Item owns that (FINAL)
    height: 40

    Rectangle {
        id: badge
        width: 40
        height: 40
        radius: 20
        color: Theme.containerHigh
        Label { anchors.centerIn: parent; text: header.icon; font.pixelSize: 20; color: Theme.bright }
    }
    Column {
        anchors { left: badge.right; leftMargin: 12; right: rightSide.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
        Label { text: header.title; font.pixelSize: 15; font.weight: Font.DemiBold; color: Theme.bright }
        Caption { visible: text !== ""; width: parent.width; elide: Text.ElideRight; text: header.subtitle }
    }
    Row {
        id: rightSide
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: 6
    }
}
