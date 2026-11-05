//@ pragma IconTheme mono
// ^ icon theme for app and menu icons (without one Qt finds none). install.sh sets it to
//   your desktop's theme.
//@ pragma Env QSG_USE_SIMPLE_ANIMATION_DRIVER=1
// ^ with two monitors at different refresh rates, Qt's default driver paces animations to
//   the slower one; the simple driver keeps each screen smooth.
// Entry: one bar per screen, plus IPC.
// Toggle flat/glass: `qs -p shell ipc call bar toggleGlass`.
// Open/close a drawer on the focused monitor: `qs -p shell ipc call bar drawer <name>`,
// name = sys, net, vol, cal, notif, media or power. Do-not-disturb: `qs -p shell ipc call bar toggleDnd`.
// App launcher: Hyprland global shortcut `quickshell:launcher` (SUPER+R, no process per
// press), or `qs -p shell ipc call launcher toggle`.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.notify
import qs.launcher
import qs.lock

ShellRoot {
    id: root
    Variants {
        id: bars
        model: Quickshell.screens
        Bar {}
    }

    Toasts {}

    // Launcher: one window (+ its shadow) that moves to the focused monitor when it opens.
    // One per screen cost ~15 MB heap and ~7 threads per window.
    Launcher { id: launcher }
    function toggleLauncher(): void {
        if (launcher.open) { launcher.open = false; return; }
        const s = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name);
        if (s) launcher.screen = s;
        launcher.open = true;
    }
    // Lock: Hyprland global shortcut `quickshell:lock` (bind it in hypr), or IPC `bar lock`.
    GlobalShortcut {
        name: "lock"
        description: "Lock the screen"
        onPressed: Lock.lock()
    }
    GlobalShortcut {
        name: "launcher"
        description: "Open or close the app launcher"
        onPressed: root.toggleLauncher()
    }
    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggleLauncher(); }
    }

    IpcHandler {
        target: "bar"
        function toggleGlass(): void { Theme.glass = !Theme.glass; }
        function toggleDnd(): void { Notifs.dnd = !Notifs.dnd; }
        function lock(): void { Lock.lock(); } // no unlock over IPC: only the password unlocks
        function drawer(name: string): void {
            if (!["sys", "net", "vol", "cal", "notif", "media", "power"].includes(name)) return; // tray needs an icon
            const bar = bars.instances.find(b => b.screen.name === Hyprland.focusedMonitor?.name);
            bar?.toggle(name);
        }
    }
}
