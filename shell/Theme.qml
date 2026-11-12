// Colors, sizes and motion of the bar. M3 roles in monochrome.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    // Flat monochrome by default; glass = see-through tint over Hyprland's blur.
    property bool glass: Saved.glass // saved (Saved.qml)
    // Shared with other apps that follow it live (the ferrite tools):
    // $XDG_RUNTIME_DIR/ferrite/glass = "1" glass, "0" solid.
    function shareGlass(): void {
        const v = glass ? 1 : 0;
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$XDG_RUNTIME_DIR/ferrite" && echo '
            + v + ' > "$XDG_RUNTIME_DIR/ferrite/glass"']);
    }
    onGlassChanged: { Saved.glass = glass; shareGlass(); }
    Component.onCompleted: shareGlass()

    // bg and menu are writable so an extra (extra/, `install.sh --extra`) can recolor them.
    property color bg: "#0d0d0d"
    readonly property real surfaceOpacity: glass ? 0.35 : 1 // bar + drawers
    // White over the bar at a given alpha (flat: same look as #1a1a1a / #262626 on #0d0d0d).
    // Only alpha differs between modes, so toggling fades instead of passing through gray.
    readonly property color container: Qt.rgba(1, 1, 1, glass ? 0.07 : 0.054)
    readonly property color containerHigh: Qt.rgba(1, 1, 1, glass ? 0.13 : 0.103) // open / selected
    readonly property color hover: Qt.rgba(1, 1, 1, 0.08) // M3 hover state layer
    // Floating menus: always opaque (a see-through menu over text is unreadable).
    property color menu: "#1c1c1c"
    readonly property color outline: Qt.rgba(1, 1, 1, 0.08)
    readonly property color fg: "#d4d4d4"
    readonly property color bright: "#ffffff"
    readonly property color dim: Qt.rgba(1, 1, 1, 0.6)
    readonly property color primary: "#ffffff"
    readonly property color primaryText: "#0d0d0d"
    readonly property color accent: "#d9c8af" // the one muted accent (text cursor), used rarely
    readonly property color error: "#c04a4a" // errors only (wrong password)

    readonly property int height: 40 // bar, = exclusive zone
    readonly property int corner: 18 // inner corners below the bar ends
    readonly property int edge: 20   // = Hyprland gaps_out: chips line up with windows
    readonly property int chip: 28
    readonly property int pad: 12
    readonly property int cell: 26   // one workspace
    readonly property int pill: 20
    readonly property int chipRadius: chip / 2 // full pill
    readonly property int pillRadius: pill / 2
    readonly property int gap: 8           // between chips
    readonly property int drawerMax: 640   // tallest drawer; the bar window reserves it
    readonly property int drawerRadius: 22 // bottom corners of a drawer
    readonly property int panelPad: 18

    // Launcher: field and result rows share one height and radius.
    readonly property int launcherWidth: 560
    readonly property int field: 40
    readonly property int fieldRadius: drawerRadius - pad // concentric in the body's corner
    readonly property int launcherIcon: 24 // icon grid

    // Arch package: ttf-roboto-mono-nerd.
    readonly property string font: "RobotoMono Nerd Font"
    readonly property int fontSize: 13
    readonly property int iconSize: 16
    readonly property int iconBox: 18 // fixed slot: icons differ in width

    // Spatial (move, resize): "graphic" easy-ease. Effects (fade, color): expo out.
    readonly property list<real> graphic: [0.76, 0, 0.12, 1, 1, 1]
    readonly property list<real> outExpo: [0.16, 1, 0.3, 1, 1, 1]
    readonly property int fastSpatial: 500
    // Drawers: same speed and curve both ways.
    readonly property list<real> drawerCurve: graphic
    readonly property int drawer: 500
    readonly property int lead: 380   // leading edge of the workspace pill
    readonly property int trail: 560  // trailing edge: the pill stretches on the way
    // Springs (ui/Spring.qml, seconds): snap = small UI, glide = bigger shapes.
    readonly property real snap: 0.15
    readonly property real glide: 0.22
    readonly property int fastEffects: 220
    readonly property int effects: 420
    readonly property int entrance: 850
    readonly property int stagger: 45
    readonly property int rise: 12
    readonly property int hold: 1000 // hold-to-fill for destructive actions (power menu)
}
