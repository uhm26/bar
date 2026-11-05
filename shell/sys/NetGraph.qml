// Network speed over the last 60 s: download as a soft area + white line, upload as a dim
// line. New samples drift in from the right (a transform on a 30 Hz timer, so the path is
// rebuilt once a second). Scale: the window's peak, at least 64 KB/s.
import QtQuick
import QtQuick.Shapes
import qs

Item {
    id: g
    readonly property int span: 60 // seconds on screen
    readonly property var values: visible ? Sys.netHistory : []
    readonly property real peak: Math.max(65536, ...values.map(v => Math.max(v[0], v[1])))
    readonly property real step: width / span
    clip: true

    // Points for one series (0 = down, 1 = up); `area` closes it along the bottom.
    function points(which: int, area: bool): var {
        const n = values.length;
        if (n < 2) return [];
        const x0 = width + step - (n - 1) * step; // newest point one step past the edge
        const pts = values.map((v, i) => Qt.point(x0 + i * step, height - 1 - (height - 2) * v[which] / peak));
        if (area) pts.push(Qt.point(x0 + (n - 1) * step, height), Qt.point(x0, height));
        return pts;
    }

    // Faint guides at half and full scale.
    Repeater {
        model: 2
        Rectangle {
            required property int index
            y: index * (g.height - 1) / 2
            width: g.width
            height: 1
            color: Theme.outline
        }
    }

    Shape {
        width: g.width
        height: g.height
        preferredRendererType: Shape.CurveRenderer
        transform: Translate { id: slide }
        ShapePath {
            strokeColor: "transparent"
            fillColor: Qt.rgba(1, 1, 1, 0.08)
            PathPolyline { path: g.points(0, true) }
        }
        ShapePath {
            strokeColor: Theme.bright
            strokeWidth: 1.5
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap
            PathPolyline { path: g.points(0, false) }
        }
        ShapePath {
            strokeColor: Theme.dim
            strokeWidth: 1.5
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap
            PathPolyline { path: g.points(1, false) }
        }
    }

    // Each new sample: everything drifts one step left during the next second. Driven by a
    // 30 Hz timer, not an animation: the drift is ~6 px/s, and a 165 Hz animation cost 14.5 %
    // of a core for steps of 0.04 px. At 30 Hz it is 0.2 px per step.
    property real since: 0 // ms since the last sample
    onValuesChanged: { since = 0; slide.x = 0; }
    Timer {
        interval: 33
        repeat: true
        running: g.visible
        onTriggered: {
            g.since = Math.min(1000, g.since + interval);
            slide.x = -g.step * g.since / 1000;
        }
    }
}
