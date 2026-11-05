// Album cover that never shows an empty frame: a new URL loads into the hidden one of two
// images and crossfades in only once it has loaded. Empty URLs (SoundCloud reports none for a
// moment between tracks) keep the current cover. Rounded via a mask; a note when there's none.
import QtQuick
import QtQuick.Effects
import qs
import qs.ui

Item {
    id: cover
    property string source
    property int radius: 16
    property bool front: true // true: a is in front
    readonly property bool any: a.status === Image.Ready || b.status === Image.Ready

    onSourceChanged: {
        if (source === "" || source === (front ? a : b).source.toString()) return;
        (front ? b : a).source = source; // load behind; swap in onReady
    }
    // Still empty after 1.5 s: the track really has no cover, so let the old one go.
    Timer {
        interval: 1500
        running: cover.source === ""
        onTriggered: { a.source = ""; b.source = ""; }
    }

    Rectangle {
        anchors.fill: parent
        radius: cover.radius
        color: Theme.containerHigh
        Label { anchors.centerIn: parent; visible: !cover.any; text: "\u{f075a}"; font.pixelSize: cover.width / 3; color: Theme.dim }
    }

    Item {
        id: stack
        anchors.fill: parent
        component Art: Image {
            id: art
            property bool inFront
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(2 * cover.width, 2 * cover.height)
            asynchronous: true
            opacity: inFront && status === Image.Ready ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: Theme.effects; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.outExpo }
            }
        }
        Art {
            id: a
            inFront: cover.front
            onStatusChanged: if (status === Image.Ready && !cover.front) cover.front = true
        }
        Art {
            id: b
            inFront: !cover.front
            onStatusChanged: if (status === Image.Ready && cover.front) cover.front = false
        }
    }
    Item {
        id: mask
        anchors.fill: parent
        Rectangle { anchors.fill: parent; radius: cover.radius }
    }
    // Effects fed via ShaderEffectSource (a hidden layered item renders nothing; AGENTS).
    ShaderEffectSource { id: stackTexture; anchors.fill: parent; sourceItem: stack; hideSource: true; visible: false }
    ShaderEffectSource { id: maskTexture; anchors.fill: parent; sourceItem: mask; hideSource: true; visible: false }
    MultiEffect {
        anchors.fill: parent
        source: stackTexture
        maskEnabled: true
        maskSource: maskTexture
        visible: cover.any
    }
}
