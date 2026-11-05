// Text in the bar's font; color changes fade.
import QtQuick
import qs

Text {
    color: Theme.fg
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
    font.weight: Font.Medium
    Behavior on color {
        ColorAnimation { duration: Theme.fastEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.outExpo }
    }
}
