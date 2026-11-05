// Turns wheel events into whole notches (120 units each): hi-res wheels and touchpads send
// fractions, sideways scrolling (y = 0) adds nothing. Emits `notch(±1)` per whole notch.
import QtQuick

QtObject {
    signal notch(int dir)
    property real acc: 0
    function feed(dy: real): void {
        acc += dy;
        while (Math.abs(acc) >= 120) {
            const d = Math.sign(acc);
            acc -= 120 * d;
            notch(d);
        }
    }
}
