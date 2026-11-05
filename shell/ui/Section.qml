// A block of a drawer panel that fades and drops in during the drawer's `reveal` (0..1),
// a little after the block before it (`step`). Closing plays the same steps in reverse.
import QtQuick
import qs

Item {
    property real reveal: 1
    property int step: 0
    readonly property real shown: {
        const start = 0.45 + step * 0.1;
        return Math.max(0, Math.min(1, (reveal - start) / (1 - start)));
    }
    opacity: shown
    transform: Translate { y: (1 - shown) * -Theme.rise }
}
