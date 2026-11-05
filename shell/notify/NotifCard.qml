// One notification card: sender picture with the app logo as a badge (or the app icon in a
// round tile), title + time, body, actions; close (✕) appears on hover.
// Motion: slides in from the right; swipe it right to throw it away (springs back if not
// far enough); every exit (click, close, swipe, timeout) slides out + fades, then the gap
// closes, and only then `gone(dismissed)` fires. A toast (`timeout` > 0) leaves after its
// timeout (paused while hovered).
import QtQuick
import QtQuick.Effects
import qs
import qs.ui

Item {
    id: card
    property var n: null
    property bool floating: false // toast: own surface + shadow; history: a Card in the drawer
    property int timeout: 0 // ms, 0 = stays
    signal gone(bool dismissed)

    readonly property var actions: (n?.actions ?? []).filter(a => a.identifier !== "default")
    readonly property var defaultAction: (n?.actions ?? []).find(a => a.identifier === "default") ?? null
    readonly property string picture: Notifs.picture(n)
    readonly property string appIcon: n ? Notifs.appIcon(n) : ""

    property real swipe: floating ? 80 : 0 // px to the right; enters from 80
    property real collapse: floating ? 0 : 1 // height factor: grows 0 → 1 in, back to 0 out
    property bool leaving: false
    property bool dismissed: false
    width: 360
    height: body.height * collapse // fractional: rounding stalls the animation (AGENTS)

    // Enter: slide in from the right while the height grows from 0, so cards below get
    // pushed down in step (no overlap); exit runs the same steps backwards (`exit`).
    Component.onCompleted: { swipe = 0; collapse = 1; }
    Behavior on collapse {
        enabled: !card.leaving
        NumberAnimation { duration: Theme.fastSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.graphic }
    }
    Behavior on swipe {
        enabled: !drag.active && !card.leaving
        NumberAnimation { duration: Theme.effects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.outExpo }
    }

    function leave(dismiss: bool): void {
        if (leaving) return;
        leaving = true;
        dismissed = dismiss;
        exit.start();
    }
    SequentialAnimation {
        id: exit
        NumberAnimation { target: card; property: "swipe"; to: card.width + 40; duration: Theme.fastEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.graphic }
        NumberAnimation { target: card; property: "collapse"; to: 0; duration: Theme.fastSpatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.graphic }
        ScriptAction { script: card.gone(card.dismissed) }
    }

    // Timeout for toasts, paused while hovered; then it leaves. A Timer, not an animation:
    // a running animation makes every bar window render at full rate (all windows
    // at the screen rate for the toast's whole 5 s).
    property real remaining: timeout // ms left
    property real startedAt: 0
    Timer {
        id: life
        interval: Math.max(1, card.remaining)
        running: card.floating && card.timeout > 0 && !hover.hovered && !card.leaving
        onRunningChanged: {
            if (running) card.startedAt = Date.now();
            else if (!card.leaving) card.remaining = Math.max(1, card.remaining - (Date.now() - card.startedAt));
        }
        onTriggered: card.leave(false)
    }

    RectangularShadow {
        visible: card.floating
        x: body.x
        width: body.width
        height: card.height // grows with the card, no shadow pop
        radius: body.radius
        offset.y: 3
        blur: 16
        color: Qt.rgba(0, 0, 0, 0.45) // very slight shadow
        opacity: body.opacity
    }

    // Clips vertically while the card grows in or collapses (wide: a thrown card flies freely).
    Item {
        width: card.width + 400
        height: card.height
        clip: card.collapse < 1
    Rectangle {
        id: body
        x: card.swipe
        width: card.width
        height: Math.max(lead.height, content.implicitHeight) + 24
        radius: 16
        // Toasts: the bar's own color and glass tint; history: a card inside the drawer.
        color: card.floating ? Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, Theme.surfaceOpacity) : Theme.container
        border { width: card.floating ? 1 : 0; color: Theme.outline }
        opacity: (1 - Math.min(1, Math.max(0, card.swipe) / card.width)) * card.collapse

        HoverHandler { id: hover }
        DragHandler {
            id: drag
            target: null
            yAxis.enabled: false
            onTranslationChanged: if (active) card.swipe = Math.max(0, translation.x)
            onActiveChanged: if (!active) {
                if (card.swipe > 90) card.leave(true);
                else card.swipe = 0; // Behavior springs it back
            }
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: card.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton && card.defaultAction) card.defaultAction.invoke();
                card.leave(mouse.button === Qt.RightButton || card.defaultAction !== null);
            }
        }

        // Left: the sender's picture with the app's logo as a small badge on its corner;
        // without a picture, the app icon in a round tile.
        Item {
            id: lead
            x: 12
            y: 12
            width: 44
            height: 44
            Avatar { id: avatar; anchors.fill: parent; size: 44; source: card.picture }
            Rectangle {
                visible: !avatar.visible
                anchors.fill: parent
                radius: width / 2
                color: Theme.containerHigh
                Image {
                    id: tileIcon
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    sourceSize: Qt.size(48, 48)
                    source: card.appIcon
                    visible: source != ""
                }
                Label { visible: !tileIcon.visible; anchors.centerIn: parent; text: "\u{f009a}"; font.pixelSize: 20; color: Theme.bright }
            }
            Rectangle {
                visible: avatar.visible && card.appIcon !== ""
                anchors { right: parent.right; bottom: parent.bottom; rightMargin: -4; bottomMargin: -4 }
                width: 20
                height: 20
                radius: 10
                color: body.color.a < 1 ? Theme.menu : body.color // ring in the card's color
                Image { anchors.centerIn: parent; width: 14; height: 14; sourceSize: Qt.size(28, 28); source: card.appIcon }
            }
        }

        // Right: title + time on one line, body below, then actions.
        Column {
            id: content
            anchors { left: lead.right; leftMargin: 12; right: parent.right; rightMargin: 12 }
            y: 12
            spacing: 2
            Item {
                width: parent.width
                height: title.implicitHeight
                Label {
                    id: title
                    width: parent.width - time.width - 8
                    elide: Text.ElideRight
                    text: card.n?.summary || card.n?.appName || ""
                    font.weight: Font.DemiBold
                    color: Theme.bright
                }
                Caption {
                    id: time
                    anchors { right: parent.right; verticalCenter: title.verticalCenter }
                    text: card.n && Notifs.times[card.n.id] ? Qt.formatTime(Notifs.times[card.n.id], "HH:mm") : ""
                    opacity: closeButton.opacity > 0 ? 1 - closeButton.opacity : 1 // the ✕ takes its place on hover
                }
            }
            Label {
                visible: text !== ""
                width: parent.width
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: (card.n?.body ?? "").replace(/<[^>]*>/g, "")
                color: Theme.fg
            }
            Row {
                visible: card.actions.length > 0
                spacing: 8
                topPadding: 8
                Repeater {
                    model: card.actions
                    Rectangle {
                        id: action
                        required property var modelData
                        width: actionLabel.implicitWidth + 24
                        height: 28
                        radius: 14
                        color: actionArea.containsMouse ? Theme.containerHigh : Theme.container
                        Label { id: actionLabel; anchors.centerIn: parent; text: action.modelData.text; font.pixelSize: 11 }
                        MouseArea {
                            id: actionArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { action.modelData.invoke(); card.leave(true); }
                        }
                    }
                }
            }
        }

        // Close: only on hover, where the time is.
        Rectangle {
            id: closeButton
            anchors { right: parent.right; top: parent.top; margins: 8 }
            width: 24
            height: 24
            radius: 12
            color: closeArea.containsMouse ? Theme.hover : "transparent"
            opacity: hover.hovered ? 1 : 0
            visible: opacity > 0
            Behavior on opacity {
                NumberAnimation { duration: Theme.fastEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.outExpo }
            }
            Label { anchors.centerIn: parent; text: "\u{f0156}"; font.pixelSize: 14; color: Theme.dim }
            MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: card.leave(true)
            }
        }
    }
    }
}
