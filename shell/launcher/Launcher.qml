// App launcher on one screen: a search field grows up out of the bottom edge (drawer
// curve, gothic corners at the edge). The first letter expands it upward to full size
// (spring) with the field on top and matches below, best first; it stays that size while
// typing and only shrinks back when the field is empty again. Scrolling on the empty field
// opens it too, with every app A→Z to scroll through.
// Rows live as long as their app stays in the results: a keystroke glides them to their
// new rank instead of rebuilding the list; new rows rise in, dropped rows fade out.
// The window always exists, so opening is instant; closed it takes no input.
// Keys: type, Down/Tab next, Up/Shift+Tab back, Enter launch, Esc close.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs
import qs.ui

PanelWindow {
    id: win
    property bool open: false
    property int selected: 0
    readonly property var results: Apps.results
    readonly property int rows: results.length
    property var rank: ({}) // app id → row, for the current results
    readonly property int maxRows: 8 // = the helper's LIMIT
    readonly property int fieldH: 2 * Theme.pad + Theme.field
    readonly property int fullH: fieldH + Theme.gap + maxRows * Theme.field + Theme.pad
    readonly property int listTop: Theme.pad + Theme.field + Theme.gap
    readonly property bool typing: field.text !== ""
    // Scrolling on the empty field: the full panel with every app, A→Z.
    property bool browsing: false
    property int top: 0 // first visible row; the list scrolls in whole rows
    property real wheelAcc: 0
    readonly property int maxTop: Math.max(0, rows - maxRows)

    function scrollBy(n: int): void {
        top = Math.max(0, Math.min(maxTop, top + n));
        selected = Math.max(top, Math.min(top + maxRows - 1, selected)); // stays in view
    }
    function select(i: int): void {
        selected = Math.max(0, Math.min(rows - 1, i));
        if (selected < top) top = selected;
        else if (selected >= top + maxRows) top = selected - maxRows + 1;
    }

    function launch(i: int): void {
        if (i < 0 || i >= rows) return;
        Apps.launch(results[i][0]);
        open = false;
    }

    // Keep rows that are still in the results, revive ones fading out, add new ones.
    function sync(): void {
        const r = {};
        results.forEach((a, i) => r[a[0]] = i);
        rank = r;
        const have = {};
        for (let i = 0; i < shown.count; i++) {
            const id = shown.get(i).appId;
            have[id] = true;
            shown.setProperty(i, "gone", !(id in r));
        }
        for (const a of results)
            if (!have[a[0]]) shown.append({ appId: a[0], name: a[1], icon: a[2], gone: false });
    }
    onResultsChanged: if (open) sync() // closed: stays idle

    // Reset before it shows: empty field and list, field height.
    onOpenChanged: if (open) {
        Apps.reset(); shown.clear(); field.text = "";
        browsing = false; selected = 0; top = 0; wheelAcc = 0;
        grow.jump(); view.jump(); slide.jump(); // highlight starts on row 0, no glide from the last pick
    }
    onRowsChanged: { selected = Math.min(selected, Math.max(0, rows - 1)); top = Math.min(top, maxTop); }

    anchors.bottom: true // screen: set by shell.qml on open (the focused monitor)
    implicitWidth: Theme.launcherWidth + 2 * Theme.corner

    implicitHeight: fullH
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "launcher" // Hyprland layer rule adds blur by this name
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { item: body }

    // Click anywhere else closes it. Grabbing while the body is still 0 px tall (empty
    // input mask) got cleared at once, so it closed the moment it opened.
    HyprlandFocusGrab {
        windows: [win]
        active: win.open && body.height > 0
        onCleared: win.open = false
    }

    property real reveal: open ? 1 : 0
    Behavior on reveal {
        NumberAnimation { duration: Theme.drawer; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.drawerCurve }
    }
    Spring { id: grow; target: win.typing || win.browsing ? win.fullH : win.fieldH }
    Spring { id: view; target: win.top * Theme.field } // list scroll offset, px

    ListModel { id: shown } // { appId, name, icon, gone }

    // The surface: the shape, opaque in one layer whose opacity is the glass tint (like the
    // bar's Surface.qml), so the body and its fillets never double up where they overlap.
    // Its shadow lives in LauncherShadow (own window: this one is blurred by Hyprland).
    Silhouette {
        anchors.fill: parent
        bodyX: win.bodyX
        bodyW: win.bodyW
        bodyH: win.bodyH
        layer.enabled: true
        opacity: Theme.surfaceOpacity
        Behavior on opacity {
            NumberAnimation { duration: Theme.effects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.outExpo }
        }
    }
    LauncherShadow { launcher: win }
    // Body geometry, shared with the shadow window.
    readonly property real bodyX: body.x
    readonly property real bodyW: body.width
    readonly property real bodyH: body.height

    Item {
        id: body
        width: Theme.launcherWidth
        height: win.reveal * grow.value
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
        clip: true

        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.pad }
            height: Theme.field
            radius: Theme.fieldRadius
            color: Theme.container

            TextInput {
                id: field
                anchors { fill: parent; leftMargin: Theme.pad; rightMargin: Theme.pad }
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                focus: win.open
                color: Theme.fg
                selectionColor: Theme.containerHigh
                selectedTextColor: Theme.bright
                font { family: Theme.font; pixelSize: Theme.fontSize; weight: Font.Medium }
                // Still cursor in the accent: no blink = no repaints while idle.
                cursorDelegate: Rectangle { width: 2; color: Theme.accent; visible: field.cursorVisible }
                onTextChanged: { win.browsing = false; win.selected = 0; win.top = 0; Apps.query(text); }
                Keys.onPressed: event => {
                    const k = event.key;
                    if (k === Qt.Key_Escape) win.open = false;
                    else if (k === Qt.Key_Return || k === Qt.Key_Enter) win.launch(win.selected);
                    else if (k === Qt.Key_Down || k === Qt.Key_Tab) win.select(win.selected + 1);
                    else if (k === Qt.Key_Up || k === Qt.Key_Backtab) win.select(win.selected - 1);
                    else return;
                    event.accepted = true;
                }
            }
            Label {
                anchors { left: field.left; verticalCenter: parent.verticalCenter }
                text: "Search"
                color: Theme.dim
                visible: field.text === ""
            }
        }

        Label {
            x: 2 * Theme.pad
            y: win.listTop + (Theme.field - height) / 2
            text: "No matches"
            color: Theme.dim
            opacity: win.typing && win.rows === 0 ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: Theme.fastEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.outExpo }
            }
        }


        // The rows' window: 8 rows tall, scrolled by `view` (spring) so nothing jumps.
        Item {
            id: list
            y: win.listTop
            width: body.width
            height: win.maxRows * Theme.field
            clip: true

            Item {
                y: -view.value
                width: list.width

                // Selection: one highlight that glides between rows.
                Rectangle {
                    x: Theme.pad
                    width: list.width - 2 * Theme.pad
                    height: Theme.field
                    radius: Theme.fieldRadius
                    color: Theme.containerHigh
                    opacity: win.rows > 0 ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: Theme.fastEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.outExpo }
                    }
                    y: slide.value
                    Spring { id: slide; duration: Theme.snap; target: win.selected * Theme.field }
                }

                Repeater {
                    model: shown
                    delegate: Item {
                        id: row
                        required property string appId
                        required property string name
                        required property string icon
                        required property bool gone
                        required property int index
                        readonly property int slot: win.rank[appId] ?? -1
                        property int at: 0 // last slot it had: a leaving row fades where it was
                        onSlotChanged: if (slot >= 0) at = slot
                        // 0 → 1 on arrival (rises in), back to 0 when dropped, then removed.
                        property real presence: 0
                        Behavior on presence {
                            NumberAnimation { duration: Theme.fastEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.outExpo }
                        }
                        onPresenceChanged: if (gone && presence === 0) Qt.callLater(() => { if (row.gone) shown.remove(row.index); })
                        Component.onCompleted: {
                            at = Math.max(0, slot);
                            pos.jump();
                            presence = Qt.binding(() => row.gone ? 0 : 1);
                        }

                        x: Theme.pad
                        y: pos.value + (1 - presence) * Theme.rise
                        opacity: presence
                        width: list.width - 2 * Theme.pad
                        height: Theme.field
                        Spring { id: pos; target: row.at * Theme.field }

                        IconImage {
                            id: iconImg
                            anchors { left: parent.left; leftMargin: Theme.pad; verticalCenter: parent.verticalCenter }
                            implicitSize: Theme.launcherIcon
                            source: Apps.icon(row.icon)
                        }
                        Label {
                            anchors { left: iconImg.right; leftMargin: Theme.pad; right: parent.right; rightMargin: Theme.pad; verticalCenter: parent.verticalCenter }
                            text: row.name
                            elide: Text.ElideRight
                            color: row.slot === win.selected ? Theme.bright : Theme.fg
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: !row.gone
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            // Real pointer motion only: rows moving under a resting cursor
                            // (scrolling, growing) must not steal the selection.
                            onPositionChanged: win.selected = row.slot
                            onClicked: win.launch(row.slot)
                        }
                    }
                }
            }

            // Where you are in a list longer than 8 rows: a thin bar in the right padding.
            Rectangle {
                x: list.width - Theme.pad / 2 - width / 2
                width: 2
                radius: 1
                color: Theme.dim
                opacity: win.rows > win.maxRows ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: Theme.fastEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.outExpo }
                }
                height: list.height * win.maxRows / Math.max(win.rows, 1)
                y: view.value / Math.max(win.rows * Theme.field, 1) * list.height
            }
        }

        // Wheel anywhere on it: the first notch on the empty field opens the full list,
        // then one row per notch. On top of everything so nothing can swallow the wheel
        // (a WheelHandler here never fired); no buttons, so clicks and hover pass through.
        // Same notch logic as ui/Chip.qml: whole notches (120) only.
        MouseArea {
            anchors.fill: parent
            z: 1
            acceptedButtons: Qt.NoButton
            onWheel: wheel => {
                if (!win.typing && !win.browsing) { win.browsing = true; Apps.all(); return; }
                win.wheelAcc += wheel.angleDelta.y;
                while (Math.abs(win.wheelAcc) >= 120) {
                    const d = Math.sign(win.wheelAcc);
                    win.wheelAcc -= 120 * d;
                    win.scrollBy(-d);
                }
            }
        }
    }
}
