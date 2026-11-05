// Tray icons (StatusNotifierItem). Left click: activate (or the menu, if the app only has
// a menu), right click: its menu in the drawer, middle: secondary action, wheel: scroll.
// Hidden while no app has a tray icon.
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs
import qs.ui

Chip {
    id: root
    signal menu(var item)
    visible: SystemTray.items.values.length > 0

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        Repeater {
            model: SystemTray.items
            Item {
                id: icon
                required property var modelData
                width: Theme.iconSize
                height: Theme.iconSize
                // Discord sends a status dot (green = online) as its tray icon, not its logo:
                // show a logo instead. assets/discord.png if you put one there (not shipped:
                // it is Discord's artwork), else the icon theme's "discord", else the dot.
                readonly property bool discord: (modelData.id ?? "").startsWith("discord")
                property bool noLocalLogo: false
                readonly property string themeLogo: discord ? Quickshell.iconPath("discord", true) : ""
                Image {
                    anchors.fill: parent
                    sourceSize: Qt.size(32, 32)
                    source: !icon.discord ? icon.modelData.icon
                        : !icon.noLocalLogo ? Qt.resolvedUrl("../assets/discord.png")
                        : icon.themeLogo || icon.modelData.icon
                    onStatusChanged: if (status === Image.Error && icon.discord) icon.noLocalLogo = true
                    smooth: true
                    mipmap: true
                }
                MouseArea {
                    anchors { fill: parent; margins: -4 }
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        const it = icon.modelData;
                        if (mouse.button === Qt.MiddleButton) it.secondaryActivate();
                        else if (mouse.button === Qt.RightButton || it.onlyMenu) { if (it.hasMenu) root.menu(it); }
                        else it.activate();
                    }
                    onWheel: wheel => icon.modelData.scroll(wheel.angleDelta.y, false)
                }
            }
        }
    }
}
