// App search results from the Rust helper `launcher` (src/launcher), kept running
// so a query costs one pipe round trip (~35 µs). Protocol: src/launcher/serve.rs.
// Replies come in query order, so the last one always belongs to the latest text.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var results: [] // [[id, name, icon]], best first, max 8

    function query(text: string): void { helper.write("q" + text.replace(/\n/g, " ") + "\n"); }
    function launch(id: string): void { helper.write("l" + id + "\n"); }
    // On open: new installs show up, the old list never flashes.
    function reset(): void { results = []; helper.write("r\n"); }
    function all(): void { helper.write("a\n"); } // every app, A→Z (browsing)

    // Theme name or absolute path → image URL; apps without one get the generic icon.
    function icon(name: string): string {
        if (name.startsWith("/")) return "file://" + name;
        return Quickshell.iconPath(name, true) || Quickshell.iconPath("application-x-executable", true);
    }

    Process {
        id: helper
        // sh adds ~/.local/bin: a session started by Hyprland often has it missing from PATH.
        command: ["sh", "-c", 'PATH="$PATH:$HOME/.local/bin" exec bar-launcher']
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => { try { root.results = JSON.parse(line); } catch (e) {} }
        }
        // Also covers a failed start (not installed / mid-install), which emits no `exited`.
        onRunningChanged: if (!running) retry.start()
    }
    Timer { id: retry; interval: 3000; onTriggered: helper.running = true }
}
