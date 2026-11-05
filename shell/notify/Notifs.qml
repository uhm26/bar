// The bar is the notification daemon (no other one runs here). Keeps every notification
// (history) until dismissed, and the ones currently shown as toasts. Do-not-disturb hides
// toasts except critical ones; history still fills.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs

Singleton {
    id: root
    property bool dnd: Saved.dnd // saved (Saved.qml)
    onDndChanged: Saved.dnd = dnd
    readonly property var list: server.trackedNotifications.values // oldest first
    property var toasts: [] // shown as toasts right now, oldest first
    property var times: ({}) // id → arrival Date (notifications carry no timestamp)

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true
        bodySupported: true
        onNotification: n => {
            root.times[n.id] = root.times[n.id] ?? new Date(); // before tracking: the history card reads it at once
            n.tracked = true;
            if (n.lastGeneration) return; // kept over a reload: already shown once, no toast again
            if (!root.dnd || n.urgency === NotificationUrgency.Critical) root.toasts = root.toasts.concat([n]);
        }
    }

    function hideToast(n: var): void { toasts = toasts.filter(t => t !== n); }
    function clear(): void { list.slice().forEach(n => n.dismiss()); toasts = []; }

    // Big picture: the notification image, or an app icon given as a file (Discord sends
    // the sender's avatar that way). Empty if neither.
    function picture(n: var): string {
        if (n?.image) return n.image;
        const i = n?.appIcon ?? "";
        if (i.startsWith("/")) return "file://" + i;
        return i.startsWith("file://") ? i : "";
    }

    // Small app icon: from the app's desktop entry (stable), else a theme icon name.
    function appIcon(n: var): string {
        // Desktop entries load in the background after start: reading the list here makes
        // bindings re-run once it is there (else the first card keeps an empty icon).
        if (DesktopEntries.applications.values.length === 0) return "";
        const entry = DesktopEntries.heuristicLookup(n?.desktopEntry || n?.appName || "");
        const name = entry?.icon || ((n?.appIcon ?? "").includes("/") ? "" : (n?.appIcon ?? ""));
        return name ? Quickshell.iconPath(name, true) : "";
    }
}
