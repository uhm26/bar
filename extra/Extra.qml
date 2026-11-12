// Extras: optional additions, installed only with `install.sh --extra` (into the shell's
// extra/ folder, where shell.qml finds and loads this file). The plain bar never has them.
//
// AMOLED: every background pure black (bar, panels, menus, notifications, launcher, lock).
// Toggle: `qs -c bar ipc call extra toggleAmoled`. Remembered across restarts.
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Scope {
    id: root
    property bool amoled: false

    // Own state file, so the core's state.json never learns about extras.
    FileView {
        id: file
        path: Quickshell.statePath("extra.json")
        blockLoading: true
        printErrors: false // first run: no file yet
    }
    Component.onCompleted: {
        try {
            amoled = JSON.parse(file.text()).amoled === true;
        } catch (e) {} // missing or broken file: defaults
    }
    function save(): void {
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "${1%/*}" && printf %s "$2" > "$1"', "sh", file.path,
            JSON.stringify({ amoled: amoled })]);
    }

    Binding { target: Theme; property: "bg"; value: "#000000"; when: root.amoled }
    Binding { target: Theme; property: "menu"; value: "#000000"; when: root.amoled }

    IpcHandler {
        target: "extra"
        function toggleAmoled(): void { root.amoled = !root.amoled; root.save(); }
    }
}
