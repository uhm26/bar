// What a locked screen shows: big time, date, password field, error line. The typed text
// lives in Lock.buffer so every screen's field shows the same dots.
import QtQuick
import qs
import qs.ui

Rectangle {
    id: root
    color: Theme.bg
    property real shown: 0 // entrance: rises and fades in
    Component.onCompleted: shown = 1
    Behavior on shown {
        NumberAnimation { duration: Theme.entrance; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.outExpo }
    }

    Column {
        anchors.centerIn: parent
        spacing: 8
        opacity: root.shown
        transform: Translate { y: (1 - root.shown) * Theme.rise * 2 }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(Now.date, "HH:mm")
            font.pixelSize: 96
            font.weight: Font.Medium
            color: Theme.bright
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(Now.date, "dddd d MMMM").toLowerCase()
            font.pixelSize: 15
            color: Theme.dim
        }
        Item { width: 1; height: 32 }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 280
            height: Theme.field
            radius: Theme.fieldRadius
            color: Theme.container
            border { width: 1; color: Lock.error ? Theme.error : Theme.outline }
            opacity: Lock.busy ? 0.6 : 1
            TextInput {
                id: field
                anchors { fill: parent; leftMargin: Theme.pad; rightMargin: Theme.pad }
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                clip: true
                focus: true
                readOnly: Lock.busy
                echoMode: TextInput.Password
                passwordCharacter: "•"
                color: Theme.bright
                font { family: Theme.font; pixelSize: Theme.fontSize; weight: Font.Medium }
                cursorDelegate: Rectangle { width: 2; color: Theme.accent; visible: field.cursorVisible }
                onTextChanged: if (text !== Lock.buffer) Lock.buffer = text
                Keys.onReturnPressed: Lock.submit()
                Keys.onEnterPressed: Lock.submit()
                Keys.onEscapePressed: Lock.buffer = ""
                Connections {
                    target: Lock
                    function onBufferChanged() { if (field.text !== Lock.buffer) field.text = Lock.buffer; }
                }
            }
            Label {
                anchors.centerIn: parent
                visible: field.text === ""
                text: Lock.busy ? "checking" : "password"
                color: Theme.dim
            }
        }
        Caption {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Lock.error || " "
            color: Theme.error
            opacity: Lock.error ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: Theme.fastEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.outExpo }
            }
        }
    }
}
