// System stats from the Rust helper `bar-sys` (src/ in this repo): one JSON line per second.
// Restarts it if it exits. Until the first line arrives, `ready` is false.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool ready: false
    property real cpu: 0
    property var temp: null // °C, or null if the machine has no k10temp
    property var up: null   // seconds since boot
    property real netDown: 0 // bytes/s
    property real netUp: 0
    property var netHistory: [] // [[down, up], ...] bytes/s, last 61 s, oldest first
    property var netApps: [] // [{ name, down, up }] TCP only, busiest first (while viewed)
    property real memUsed: 0
    property real memTotal: 0
    property real swapUsed: 0
    property real swapTotal: 0
    property var procs: [] // [{ name, cpu, mem, pids }], grouped by program
    readonly property real memPct: memTotal > 0 ? memUsed / memTotal * 100 : 0
    readonly property bool hasSwap: swapTotal > 0
    readonly property real swapPct: hasSwap ? swapUsed / swapTotal * 100 : 0

    // Bytes → "512M" / "1.4G".
    function size(bytes: real): string {
        const g = bytes / 1073741824;
        return g >= 1 ? g.toFixed(1) + "G" : Math.round(bytes / 1048576) + "M";
    }

    // Bytes/s → "999 B/s" / "1.2 MB/s" / "12 MB/s": at most 8 characters ("999 KB/s").
    function speed(bps: real): string {
        const units = ["B", "KB", "MB", "GB"];
        let v = bps, i = 0;
        while (v >= 999.5 && i < 3) { v /= 1024; i++; }
        return (i > 0 && v < 10 ? v.toFixed(1) : Math.round(v)) + " " + units[i] + "/s";
    }

    // Seconds → "3h 12m" / "2d 4h" / "12m".
    function duration(s: real): string {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return d > 0 ? d + "d " + h + "h" : h > 0 ? h + "h " + m + "m" : m + "m";
    }

    function apply(line: string): void {
        let d;
        try { d = JSON.parse(line); } catch (e) { return; }
        cpu = d.cpu;
        temp = d.temp;
        up = d.up;
        [netDown, netUp] = d.net ?? [0, 0]; // (totals since boot are not shown)
        netHistory = netHistory.concat([[netDown, netUp]]).slice(-61);
        if (d.apps) netApps = d.apps.map(a => ({ name: a[0], down: a[1], up: a[2] }));
        [memUsed, memTotal] = d.mem;
        [swapUsed, swapTotal] = d.swap;
        // null = list switched off: keep the last one, so a drawer opens with rows instead
        // of an empty list while the first fresh scan runs (~0.2 s).
        if (d.procs) procs = d.procs.map(p => ({ name: p[0], cpu: p[1], mem: p[2], pids: p[3] }));
        const first = !ready;
        ready = true;
        if (first) tell();
    }

    // Panels showing the process list (viewers) or the per-app network list (netViewers).
    // The helper does that work only while someone looks; sets, so adding or removing
    // twice is harmless.
    property var viewers: []
    property var netViewers: []
    // Add/remove `who` in a viewer set; tell bar-sys only when the set turns (non-)empty.
    function setViewer(name: string, who: var, on: bool): void {
        const was = root[name].length > 0;
        root[name] = root[name].filter(v => v !== who).concat(on ? [who] : []);
        if ((root[name].length > 0) !== was) tell();
    }
    function view(who: var, on: bool): void { setViewer("viewers", who, on); }
    function viewNet(who: var, on: bool): void { setViewer("netViewers", who, on); }
    function tell(): void {
        helper.write(viewers.length > 0 ? "procs on\n" : "procs off\n");
        helper.write(netViewers.length > 0 ? "net on\n" : "net off\n");
    }

    Process {
        id: helper
        // sh adds ~/.local/bin: a session started by Hyprland often has it missing from PATH.
        command: ["sh", "-c", 'PATH="$PATH:$HOME/.local/bin" exec bar-sys']
        running: true
        stdinEnabled: true
        // No tell() on start: bar-sys starts with both lists on; the first report fills
        // them, then apply() switches off what no drawer shows.
        stdout: SplitParser { onRead: line => root.apply(line) }
        // Also covers a failed start (bar-sys missing / mid-install), which emits no `exited`.
        onRunningChanged: if (!running) {
            root.ready = false;
            root.procs = []; // no stale pids for the kill menu
            root.netApps = [];
            retry.start();
        }
    }
    Timer { id: retry; interval: 3000; onTriggered: helper.running = true }
}
