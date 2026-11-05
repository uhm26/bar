// A label that changes text with a quick fade + 6 px rise instead of jumping (track skips).
// `fitWidth`: the text's width capped at `maxWidth`; it glides to the new text's width while
// that fades in (bind `width: fitWidth` to use it). `swapping` is true while a change runs.
import QtQuick
import qs
import qs.ui

Label {
    id: swap
    property string target
    property real lift: 0
    property real maxWidth: Infinity
    property real fitWidth: Math.min(maxWidth, implicitWidth) // live, except during a change
    readonly property bool swapping: change.running
    transform: Translate { y: swap.lift }
    Component.onCompleted: text = target
    onTargetChanged: if (target !== text) change.restart()
    SequentialAnimation {
        id: change
        ParallelAnimation {
            NumberAnimation { target: swap; property: "opacity"; to: 0; duration: Theme.fastEffects / 2 }
            NumberAnimation { target: swap; property: "lift"; to: -6; duration: Theme.fastEffects / 2 }
        }
        ScriptAction {
            script: {
                resize.from = swap.fitWidth;
                swap.fitWidth = resize.from; // freeze (drops the binding) before the text changes it
                swap.text = swap.target;
                swap.lift = 6;
                resize.to = Math.min(swap.maxWidth, swap.implicitWidth);
            }
        }
        ParallelAnimation {
            NumberAnimation { target: swap; property: "opacity"; to: 1; duration: Theme.effects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.outExpo }
            NumberAnimation { target: swap; property: "lift"; to: 0; duration: Theme.effects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.outExpo }
            NumberAnimation { id: resize; target: swap; property: "fitWidth"; duration: Theme.effects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.outExpo }
        }
        ScriptAction { script: swap.fitWidth = Qt.binding(() => Math.min(swap.maxWidth, swap.implicitWidth)) }
    }
}
