// One bar per screen: full-width top bar with inner rounded corners, plus drawers that
// grow down out of it under their chip (one open at a time). The window reserves room
// for the tallest drawer; only the bar and an open drawer take input.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import qs.modules
import qs.sys
import qs.tray
import qs.audio
import qs.calendar
import qs.notify
import qs.media
import qs.power

PanelWindow {
    id: bar
    required property var modelData
    property string open: "" // name of the open drawer ("sys", "tray"), "" = none
    property var trayItem: null // whose menu the tray drawer shows
    function toggle(name: string): void {
        const closing = open === name; // before the flip below, which may switch `open`
        // Keep the chips' pages in step with the drawer (IPC can open either page's drawer).
        if (name === "sys" || name === "net") sysChip.show(name === "net" ? 1 : 0);
        if (name === "cal" || name === "media") clock.show(name === "media" ? 1 : 0);
        if (closing) open = ""; else switchTo(name);
    }
    function openTray(item: var): void {
        if (open === "tray" && trayItem === item) { open = ""; return; }
        trayItem = item;
        switchTo("tray");
    }

    // Which part of the bar a drawer hangs from: 0 left (system/network), 1 center
    // (calendar/media), 2 right (tray, notifications, volume).
    function side(kind: string): int {
        return kind === "sys" || kind === "net" ? 0 : kind === "cal" || kind === "media" ? 1 : 2;
    }
    // Same side: the open slot morphs into the new page (width, x, height glide). Other
    // side: that slot rolls up where it is while the other slot rolls down at the new chip,
    // at the same time. Closing = `open = ""` (a slot is shown while it's the active one).
    property int active: 0
    readonly property var slots: [slotA, slotB]
    readonly property var pages: ({ sys: panel, net: netPanel, tray: trayMenu, vol: volPanel, cal: calPanel, notif: notifPanel, media: mediaPanel, power: powerPanel })
    readonly property var chips: ({ sys: sysChip, net: sysChip, tray: trayChip, vol: volume, cal: clock, notif: notifChip, media: clock, power: powerChip })
    function switchTo(name: string): void {
        if (open !== "" && side(open) !== side(name)) active = 1 - active;
        const slot = slots[active];
        if (pages[name].parent !== slot) pages[name].parent = slot;
        slot.kind = name;
        open = name;
    }

    screen: modelData
    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.height + Theme.drawerMax
    exclusiveZone: Theme.height
    color: "transparent"
    WlrLayershell.namespace: "bar" // Hyprland layer rule adds blur by this name
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region {
        item: body
        Region { item: slotA }
        Region { item: slotB }
    }

    // Click outside the bar closes the drawer.
    HyprlandFocusGrab {
        windows: [bar]
        active: bar.open !== ""
        onCleared: bar.open = ""
    }

    // The tray app quit while its menu is open: close instead of showing an empty drawer.
    Connections {
        target: SystemTray.items
        function onValuesChanged() {
            if (bar.open === "tray" && !SystemTray.items.values.includes(bar.trayItem)) bar.open = "";
        }
    }

    Surface {
        anchors.fill: parent
        drawers: bar.slots
    }

    Item {
        id: body
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: Theme.height

        // Middle-click on empty bar space: glass ↔ solid. Chips sit above `body`, so a
        // middle-click that lands on one (tray: secondary action) is left to the chip.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.MiddleButton
            onClicked: mouse => {
                if (bar.contentItem.childAt(mouse.x, mouse.y) === body) Theme.glass = !Theme.glass;
            }
        }
    }

    // Left: workspaces, system. Center: clock. Right: tray, bell, volume, power.
    Workspaces {
        id: workspaces
        order: 0
        screen: bar.modelData
        anchors { left: parent.left; leftMargin: Theme.edge; verticalCenter: body.verticalCenter }
    }
    SysChip {
        id: sysChip
        order: 1
        highlighted: bar.open === "sys" || bar.open === "net"
        onClicked: bar.toggle(page === 0 ? "sys" : "net") // the page shown picks the drawer
        // Flipping the chip with its drawer open turns the drawer into the other one.
        onPageChanged: {
            Saved.sysPage = page;
            if (bar.open === "sys" || bar.open === "net") bar.switchTo(page === 0 ? "sys" : "net");
        }
        Component.onCompleted: jump(Saved.sysPage) // the page it showed before a restart
        anchors { left: workspaces.right; leftMargin: Theme.gap; verticalCenter: body.verticalCenter }
    }
    TrayChip {
        id: trayChip
        order: 2
        highlighted: bar.open === "tray"
        onMenu: item => bar.openTray(item)
        anchors { right: notifChip.left; rightMargin: Theme.gap; verticalCenter: body.verticalCenter }
    }
    NotifChip {
        id: notifChip
        order: 3
        highlighted: bar.open === "notif"
        onClicked: bar.toggle("notif")
        anchors { right: volume.left; rightMargin: Theme.gap; verticalCenter: body.verticalCenter }
    }
    Clock {
        id: clock
        order: 4
        highlighted: bar.open === "cal" || bar.open === "media"
        // The page shown picks the drawer (calendar / media); flipping morphs between them.
        onClicked: bar.toggle(page === 0 ? "cal" : "media")
        onPageChanged: {
            Saved.clockPage = page;
            if (bar.open === "cal" || bar.open === "media") bar.switchTo(page === 0 ? "cal" : "media");
        }
        Component.onCompleted: jump(Saved.clockPage)
        anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: body.verticalCenter }
    }
    Volume {
        id: volume
        order: 5
        highlighted: bar.open === "vol"
        onClicked: bar.toggle("vol")
        anchors { right: powerChip.left; rightMargin: Theme.gap; verticalCenter: body.verticalCenter }
    }
    PowerChip {
        id: powerChip
        order: 6
        highlighted: bar.open === "power"
        onClicked: bar.toggle("power")
        anchors { right: parent.right; rightMargin: Theme.edge; verticalCenter: body.verticalCenter }
    }

    // Two drawer slots (DrawerSlot): the active one is shown while a drawer is open.
    DrawerSlot {
        id: slotA
        shown: bar.open !== "" && bar.active === 0
        pages: bar.pages
        chips: bar.chips
        barWidth: bar.width
        focus: shown
        Keys.onEscapePressed: bar.open = ""
    }
    DrawerSlot {
        id: slotB
        shown: bar.open !== "" && bar.active === 1
        pages: bar.pages
        chips: bar.chips
        barWidth: bar.width
        focus: shown
        Keys.onEscapePressed: bar.open = ""
    }

    // The pages, made once; each lives in the slot that shows it (switchTo moves it), and
    // takes that slot's kind and reveal (DrawerPage: cross-fade, Section cascade).
    SysPanel { id: panel; parent: slotA; current: parent?.kind ?? ""; drawerReveal: parent?.reveal ?? 0; anchors.horizontalCenter: parent?.horizontalCenter }
    NetPanel { id: netPanel; parent: slotA; current: parent?.kind ?? ""; drawerReveal: parent?.reveal ?? 0; anchors.horizontalCenter: parent?.horizontalCenter }
    VolumePanel { id: volPanel; parent: slotA; current: parent?.kind ?? ""; drawerReveal: parent?.reveal ?? 0; anchors.horizontalCenter: parent?.horizontalCenter }
    CalendarPanel { id: calPanel; parent: slotA; current: parent?.kind ?? ""; drawerReveal: parent?.reveal ?? 0; anchors.horizontalCenter: parent?.horizontalCenter }
    NotifPanel { id: notifPanel; parent: slotA; current: parent?.kind ?? ""; drawerReveal: parent?.reveal ?? 0; anchors.horizontalCenter: parent?.horizontalCenter }
    MediaPanel { id: mediaPanel; parent: slotA; current: parent?.kind ?? ""; drawerReveal: parent?.reveal ?? 0; anchors.horizontalCenter: parent?.horizontalCenter }
    PowerPanel { id: powerPanel; parent: slotA; current: parent?.kind ?? ""; drawerReveal: parent?.reveal ?? 0; anchors.horizontalCenter: parent?.horizontalCenter; onDone: bar.open = "" }
    TrayMenu {
        id: trayMenu
        parent: slotA
        current: parent?.kind ?? ""
        drawerReveal: parent?.reveal ?? 0
        anchors.horizontalCenter: parent?.horizontalCenter
        item: bar.trayItem
        onDone: bar.open = ""
    }
}
