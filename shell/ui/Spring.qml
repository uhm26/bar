// Critically damped spring (ζ = 1, ω = 2π/duration, closed form with the real frame time;
// motion rules). `value` follows `target`: never overshoots, and a new target mid-move
// keeps the speed (no jolt, unlike restarting a bezier). Frames only while moving.
// Set `target`, read `value`; `jump()` lands at once (e.g. while nobody sees it).
import QtQuick
import qs

FrameAnimation {
    property real target: 0
    property real value: 0
    property real velocity: 0
    property real duration: Theme.glide // seconds
    readonly property real omega: 2 * Math.PI / duration

    function jump(): void { value = target; velocity = 0; }

    running: (value !== target || velocity !== 0) && !isNaN(target) // a NaN target never settles
    Component.onCompleted: jump()
    onTriggered: {
        const dt = Math.min(frameTime, 1 / 30); // a stalled frame must not teleport it
        const x0 = value - target, v0 = velocity, w = omega, e = Math.exp(-w * dt);
        let x = (x0 + (v0 + w * x0) * dt) * e;
        let v = (v0 - w * (v0 + w * x0) * dt) * e;
        // Crossing the target would be overshoot; close enough is done (0.05 px).
        if (x * x0 < 0 || (Math.abs(x) < 0.05 && Math.abs(v * dt) < 0.05)) { x = 0; v = 0; }
        velocity = v;
        value = target + x;
    }
}
