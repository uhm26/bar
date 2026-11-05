// Named Saved, not State: QtQuick already has a `State` type (it shadowed this singleton).
// What the user set, kept across bar restarts and reboots: glass, do-not-disturb and the
// page each paged chip shows (system/network, clock/media). One JSON file in Quickshell's
// state dir. Read (blocking) before the bars draw, so nothing flips at start.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property string path: Quickshell.statePath("state.json")
    property bool glass: false
    property bool dnd: false
    property int sysPage: 0
    property int clockPage: 0
    property bool ready: false // no saving before the file was read

    FileView {
        id: file
        path: root.path
        blockLoading: true
        printErrors: false // first run: no file yet
    }
    Component.onCompleted: {
        try {
            const j = JSON.parse(file.text());
            glass = j.glass === true;
            dnd = j.dnd === true;
            sysPage = j.sysPage === 1 ? 1 : 0;
            clockPage = j.clockPage === 1 ? 1 : 0;
        } catch (e) {} // missing or broken file: defaults
        ready = true;
    }
    // Rare (a click or a scroll), so a tiny shell write is fine; it also creates the dir,
    // which Quickshell doesn't make for statePath.
    function save(): void {
        if (!ready) return;
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "${1%/*}" && printf %s "$2" > "$1"', "sh", path,
            JSON.stringify({ glass: glass, dnd: dnd, sysPage: sysPage, clockPage: clockPage })]);
    }
    onGlassChanged: save()
    onDndChanged: save()
    onSysPageChanged: save()
    onClockPageChanged: save()
}
