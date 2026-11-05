// The launcher's shadow, in its own window under it: the same shadow as the bar's drawers
// (RectangularShadow, black 45 %, blur 14, 2 px offset), cast upward.
// It can't live in the launcher's window: Hyprland blurs that one wherever it is more than
// 20 % opaque (glass), which turned a shadow there into a frosted rim. This window has no
// blur rule and takes no input. The launcher's own shape is cut out of it, so glass mode
// doesn't get darker underneath.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs

PanelWindow {
    id: shadow
    required property var launcher // Launcher window: bodyX / bodyW / bodyH, screen
    readonly property int room: 24 // shadow reach beyond the launcher's window, px

    screen: launcher.screen
    anchors.bottom: true
    implicitWidth: launcher.implicitWidth + 2 * room
    implicitHeight: launcher.implicitHeight + room
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top // under the launcher (Overlay), over app windows
    WlrLayershell.namespace: "launcher-shadow"
    mask: Region {} // clicks go through

    Item { // one container: also lets a grab render sources + effect together
        anchors.fill: parent
        anchors.bottomMargin: -shadow.room // reaches `room` below the window, off-screen

        // The body runs on below the screen edge, so the shadow doesn't fade out there.
        Item {
            id: castLayer // full size, so the texture holds the whole blur
            anchors.fill: parent
            RectangularShadow {
                id: cast
                x: shadow.launcher.bodyX + shadow.room
                y: parent.height - height
                width: shadow.launcher.bodyW
                height: shadow.launcher.bodyH + shadow.room
                visible: shadow.launcher.bodyH > 0
                radius: Theme.drawerRadius
                offset.y: -2
                blur: 14
                color: Qt.rgba(0, 0, 0, 0.45)
            }
        }
        Silhouette {
            id: exact
            anchors.fill: parent
            anchors.bottomMargin: shadow.room // ends at the screen edge, like the launcher
            bodyX: shadow.launcher.bodyX + shadow.room
            bodyW: shadow.launcher.bodyW
            bodyH: shadow.launcher.bodyH
        }
        ShaderEffectSource { id: castTexture; anchors.fill: parent; sourceItem: castLayer; hideSource: true; visible: false }
        ShaderEffectSource { id: exactTexture; anchors.fill: parent; sourceItem: exact; hideSource: true; visible: false }
        MultiEffect {
            anchors.fill: parent
            source: castTexture
            maskEnabled: true
            maskInverted: true
            maskSource: exactTexture
        }
    }
}
