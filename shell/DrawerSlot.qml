// One drawer slot: rolls down out of the bar under the chip of the page it shows. The bar
// has two, so on a switch to the other side the old slot rolls up at its chip while the
// other rolls down at the new one, at the same time. Pages move into the slot showing them
// (Bar.place). Opening and closing move only the height: width and x stay at their final
// values, so it never drifts sideways (it did while the width morphed, because the edge
// clamp pushed it over as it grew). `kind` stays while closing, so the page stays drawn.
import QtQuick

Item {
    id: slot
    property string kind: ""
    property bool shown: false
    property var pages: ({})
    property var chips: ({})
    property real barWidth: 0
    readonly property Item content: pages[kind] ?? null
    readonly property Item chip: chips[kind] ?? null

    property real reveal: shown ? 1 : 0
    Behavior on reveal {
        NumberAnimation { duration: Theme.drawer; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.drawerCurve }
    }
    readonly property real minX: 2 * Theme.corner // clear of the bar's own corners
    readonly property real targetW: content ? content.implicitWidth : 0
    // Fractional on purpose: rounding to whole px stalled the height in ~17 % of frames.
    width: targetW
    // Glides when the slot changes content while open (same side, tray submenus); jumps
    // while closed, where nobody sees it.
    property real contentH: content ? content.implicitHeight : 0
    Behavior on contentH {
        enabled: slot.reveal > 0
        NumberAnimation { duration: Theme.drawer; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.drawerCurve }
    }
    height: Math.min(Theme.drawerMax, contentH) * reveal
    // Hangs centered under its chip, clamped clear of the bar's ends. The center target is
    // rounded: a chip resizing around its middle (clock flip) then doesn't move it, so the
    // center glide isn't restarted every frame (it was, and x lagged the width: the drawer
    // morphed from one side, then slid to center). x itself follows the gliding width.
    property real cx: chip ? Math.round(chip.x + chip.width / 2) : 0
    Behavior on cx {
        enabled: slot.reveal >= 1
        NumberAnimation { duration: Theme.drawer; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.drawerCurve }
    }
    x: chip ? Math.max(minX, Math.min(barWidth - minX - width, cx - width / 2)) : 0
    // Switching content while fully open: width glides like the height.
    Behavior on width {
        enabled: slot.reveal >= 1
        NumberAnimation { duration: Theme.drawer; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.drawerCurve }
    }
    y: Theme.height
    clip: true
}
