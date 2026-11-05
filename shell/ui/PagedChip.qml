// A chip with two pages that flips on scroll: scrolling down lifts the shown page out the
// top while the other rises from below (up: the other way). One flip per animation
// (cooldown), and the chip takes the shown page's width, gliding. Owners put two Pages in
// `first` / `second` (default content goes into the chip as usual).
import QtQuick
import qs

Chip {
    id: root
    property int page: 0
    property Page first
    property Page second
    readonly property real room: width - 2 * pad // inner width right now (width glides)
    interactive: true
    clip: true

    Timer { id: cooldown; interval: Theme.effects + 30 }
    onScrolled: dir => {
        if (cooldown.running || !first || !second) return;
        cooldown.start();
        flip(dir < 0 ? 1 : -1); // scroll down → new page comes from below
    }
    // Shows page `p` (e.g. a drawer opened by IPC for the other page); no-op if shown.
    function show(p: int): void { if (p !== page && first && second) flip(p === 1 ? 1 : -1); }
    // Shows page `p` at once, no motion (restoring the saved page at start).
    function jump(p: int): void {
        if (p === page || !first || !second) return;
        first.instant = true;
        second.instant = true;
        first.offset = p === 0 ? 0 : -1;
        second.offset = p === 1 ? 0 : 1;
        first.instant = false;
        second.instant = false;
        page = p;
    }
    // from: side the incoming page enters from (1 = below, -1 = above).
    function flip(from: int): void {
        const out = page === 0 ? first : second, into = page === 0 ? second : first;
        into.instant = true;
        into.offset = from;
        into.instant = false;
        into.offset = 0;
        out.offset = -from;
        page = 1 - page;
    }
}
