// Round picture (sender avatar, notification image). Retries a few times when loading
// fails: Discord writes the avatar file a moment after sending the notification, so the
// first try often finds nothing.
import QtQuick
import QtQuick.Effects
import qs

Item {
    id: av
    property string source
    property int size: 48
    property int tries: 0
    width: size
    height: size
    visible: source !== ""

    Image {
        id: img
        anchors.fill: parent
        sourceSize: Qt.size(av.size * 2, av.size * 2)
        fillMode: Image.PreserveAspectCrop
        source: av.source
        cache: false
        visible: false // drawn through the round mask below
        onStatusChanged: if (status === Image.Error && av.tries < 10) retry.start() // ~2 s
    }
    Timer {
        id: retry
        interval: 200
        onTriggered: { av.tries++; img.source = ""; img.source = av.source; }
    }
    Rectangle { id: mask; anchors.fill: parent; radius: width / 2; visible: false; layer.enabled: true }
    MultiEffect {
        anchors.fill: parent
        source: img
        maskEnabled: true
        maskSource: mask
        opacity: img.status === Image.Ready ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.effects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.outExpo }
        }
    }
    // Placeholder while (re)loading.
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.containerHigh
        visible: img.status !== Image.Ready
    }
}
