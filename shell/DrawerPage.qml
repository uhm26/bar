// One content of the bar's drawer (system, network, tray, sound, calendar, notifications).
// The drawer passes its current `kind` and `reveal`; `presence` cross-fades when the
// drawer switches content while open, and the page's own `reveal` (drawer reveal ×
// presence) drives its Sections. Hidden pages have no layout, no animations, no frames.
import QtQuick

Item {
    property string kind
    property string current: ""
    property real drawerReveal: 0
    property real presence: current === kind ? 1 : 0
    Behavior on presence {
        enabled: drawerReveal > 0
        NumberAnimation { duration: Theme.drawer; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.drawerCurve }
    }
    readonly property real reveal: drawerReveal * presence
    visible: presence > 0 && drawerReveal > 0
    width: implicitWidth
}
