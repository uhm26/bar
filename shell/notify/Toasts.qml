// Toasts: new notifications as cards under the bar, top right of the focused screen.
// The cards animate themselves (NotifCard): in from the right, out on timeout, click,
// close or swipe; the others glide into the gap. A timed-out toast stays in the history
// drawer; a closed one is dismissed. The window stays mapped (empty input mask when idle):
// mapping it per toast added Hyprland's layer fade on top of the card's own slide.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import qs

PanelWindow {
    id: win
    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    anchors { top: true; right: true }
    margins { top: Theme.height + 10; right: Theme.edge - 20 }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "bar-toast" // Hyprland layer rule: blur for glass mode
    color: "transparent"
    implicitWidth: 360 + 40 // 20 px each side for the shadow
    // Fixed size (input only on the cards): resizing the layer every frame while a card grows
    // would mean a compositor round trip per frame.
    implicitHeight: 900
    mask: Region { item: stack }

    Column {
        id: stack
        x: 20
        spacing: 8
        Repeater {
            // ScriptModel keeps existing toasts' items when one is added or removed.
            model: ScriptModel { values: Notifs.toasts.slice().reverse() } // newest on top
            NotifCard {
                id: toast
                required property var modelData
                n: modelData
                floating: true
                timeout: modelData.urgency === NotificationUrgency.Critical ? 0
                    : modelData.expireTimeout > 0 ? modelData.expireTimeout // ms
                    : modelData.expireTimeout === 0 ? 0 : 5000 // 0 = the app says never expire
                onGone: dismissed => dismissed ? modelData.dismiss() : Notifs.hideToast(modelData)
                // Closed by the app or from the history drawer: drop the toast.
                Connections {
                    target: toast.modelData
                    function onClosed(reason) { Notifs.hideToast(toast.modelData); }
                }
            }
        }
    }
}
