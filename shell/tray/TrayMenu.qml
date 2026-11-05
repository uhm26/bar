// Drawer content for a tray icon's menu (DBusMenu via QsMenuOpener), in the bar's style.
// Submenus open in place with a back row. Picking an entry runs it and closes the drawer.
import QtQuick
import Quickshell
import qs
import qs.ui

DrawerPage {
    id: tray
    property var item: null // the SystemTrayItem whose menu is shown
    kind: "tray"
    signal done
    property var stack: [] // submenus entered, innermost last
    readonly property var menu: stack.length ? stack[stack.length - 1] : (item?.menu ?? null)
    onItemChanged: stack = []
    onVisibleChanged: if (visible) stack = []

    // Theme icons the theme lacks render as a missing texture: hide them instead.
    function found(url: string): bool {
        if (!url.startsWith("image://icon/")) return true; // pixmaps from the app itself
        return Quickshell.hasThemeIcon(url.slice(13).split("?")[0]);
    }

    // DBusMenu labels mark mnemonics with "_" ("_Quit"); "__" is a literal underscore.
    function label(text: string): string {
        return text.replace(/__/g, "\u0000").replace(/_/g, "").replace(/\u0000/g, "_");
    }

    implicitWidth: 240
    implicitHeight: col.implicitHeight + 16
    opacity: Math.max(0, Math.min(1, (reveal - 0.45) / 0.55)) // same fade as the system panel

    // Only while shown: a bound opener keeps the app's menu open on DBus.
    QsMenuOpener { id: opener; menu: tray.visible ? tray.menu : null }

    Column {
        id: col
        x: 8
        y: 8
        width: parent.width - 16

        Item {
            width: parent.width
            height: 30
            Label {
                x: 10
                width: parent.width - 20
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: tray.stack.length ? "\u{f0141}  back"
                    : (tray.item?.tooltipTitle || tray.item?.title || tray.item?.id || "")
                font.pixelSize: 11
                color: Theme.dim
            }
            MouseArea {
                anchors.fill: parent
                enabled: tray.stack.length > 0
                cursorShape: Qt.PointingHandCursor
                onClicked: tray.stack = tray.stack.slice(0, -1)
            }
        }

        Repeater {
            model: opener.children
            Item {
                id: e
                required property var modelData
                readonly property bool sep: modelData.isSeparator
                readonly property bool checked: modelData.buttonType !== QsMenuButtonType.None
                    && modelData.checkState === Qt.Checked
                width: col.width
                height: sep ? 9 : 32

                Rectangle {
                    visible: e.sep
                    anchors.centerIn: parent
                    width: parent.width - 20
                    height: 1
                    color: Theme.hover
                }
                Rectangle {
                    visible: !e.sep
                    anchors.fill: parent
                    radius: 8
                    color: area.containsMouse ? Theme.hover : "transparent"
                }
                Image {
                    id: icon
                    visible: !e.sep && source != "" && tray.found(source)
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    sourceSize: Qt.size(32, 32)
                    source: e.modelData.icon
                }
                Label {
                    visible: !e.sep
                    x: icon.visible ? 34 : 10
                    width: parent.width - x - 30
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: tray.label(e.modelData.text)
                    color: e.modelData.enabled ? Theme.fg : Theme.dim
                }
                Label {
                    visible: !e.sep
                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    text: e.modelData.hasChildren ? "\u{f0142}" : e.checked ? "\u{f012c}" : ""
                    color: Theme.bright
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    enabled: !e.sep && e.modelData.enabled
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (e.modelData.hasChildren) {
                            tray.stack = tray.stack.concat([e.modelData]);
                        } else {
                            e.modelData.triggered();
                            tray.done();
                        }
                    }
                }
            }
        }
    }
}
