pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Pipewire
import qs.Common

// a node's live level, drawn like dux's media visualiser: six round bars grown from the middle,
// the inner pair live and the outer ones a moment behind; quick up, damped down, grey dots when muted
Item {
    id: meter

    property var node: null
    // dux keeps popout content loaded after close, so this gates the capture stream
    property bool active: false

    // dux's bar geometry
    readonly property int bars: 6
    readonly property real barWidth: 2
    readonly property real gap: 1.5
    readonly property real minBarHeight: 3
    // per bar: steps from the middle, and its share of the full height
    readonly property var reach: [2, 1, 0, 0, 1, 2]
    readonly property var envelope: [0.6, 0.85, 1, 1, 0.85, 0.6]
    // ticks of delay per step outwards
    readonly property int lag: 2

    readonly property var audio: node?.audio ?? null
    readonly property bool muted: audio?.muted ?? false
    readonly property real volume: audio?.volume ?? 0
    readonly property bool isDevice: !!node && !node.isStream && node.properties?.["device.id"] !== undefined && node.properties?.["card.profile.device"] !== undefined

    // quickshell divides a stream's or virtual node's own volume out of its peak; a sink's
    // monitor taps before its volume, a source's capture after; scaled so 50% is half as tall
    readonly property real gain: {
        if (!node || node.isStream)
            return volume;
        if (isDevice)
            return node.isSink ? volume : 1;
        return node.isSink ? volume * volume : volume;
    }

    // smoothed 0..1, and its recent values, newest first
    property real level: 0
    property var history: new Array(Math.max(...reach) * lag + 1).fill(0)

    implicitWidth: bars * barWidth + (bars - 1) * gap
    implicitHeight: Theme.iconSizeMedium

    onActiveChanged: {
        if (!active)
            return;
        level = 0;
        history = history.map(() => 0);
    }

    PwNodePeakMonitor {
        id: monitor

        node: meter.node
        enabled: meter.active && meter.node !== null
    }

    Timer {
        interval: 33
        repeat: true
        running: monitor.enabled
        onTriggered: {
            const target = meter.muted ? 0 : Math.max(0, Math.min(1, monitor.peak * meter.gain));
            meter.level += (target - meter.level) * (target > meter.level ? 0.6 : 0.2);
            meter.history = [meter.level].concat(meter.history.slice(0, -1));
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: meter.gap

        Repeater {
            model: meter.bars

            Rectangle {
                required property int index
                readonly property real value: meter.muted ? 0 : (meter.history[meter.reach[index] * meter.lag] ?? 0) * meter.envelope[index]

                anchors.verticalCenter: parent.verticalCenter
                width: meter.barWidth
                height: meter.minBarHeight + value * (meter.height - meter.minBarHeight)
                radius: width / 2
                color: meter.muted ? Theme.onSurface_38 : Theme.primary

                Behavior on height {
                    NumberAnimation {
                        duration: 50
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.shortDuration
                    }
                }
            }
        }
    }
}
