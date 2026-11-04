pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Pipewire
import qs.Common

// a node's live level as rising bars: quick up, damped down, with a slow peak hold; flat and dim when muted
Item {
    id: meter

    property var node: null
    // dux keeps popout content loaded after close, so this gates the capture stream
    property bool active: false
    property int segments: 8
    property real segmentWidth: 3
    property real gap: 2

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

    // 0..1, smoothed
    property real level: 0
    property real held: 0

    implicitWidth: segments * segmentWidth + (segments - 1) * gap
    implicitHeight: Theme.iconSizeSmall - Theme.spacingXXS

    onActiveChanged: {
        if (!active)
            return;
        level = 0;
        held = 0;
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
            meter.level = target > meter.level ? meter.level + (target - meter.level) * 0.6 : meter.level + (target - meter.level) * 0.18;
            meter.held = Math.max(target, meter.held - 0.015);
        }
    }

    Row {
        anchors.bottom: parent.bottom
        spacing: meter.gap

        Repeater {
            model: meter.segments

            // each bar fills as the level passes it, so the edge moves smoothly
            Rectangle {
                id: segment

                required property int index
                readonly property real fill: Math.max(0, Math.min(1, meter.level * meter.segments - index))
                readonly property bool isHeld: !meter.muted && meter.held > 0.02 && Math.min(meter.segments - 1, Math.floor(meter.held * meter.segments)) === index

                anchors.bottom: parent.bottom
                width: meter.segmentWidth
                height: meter.height * (0.4 + 0.6 * index / Math.max(1, meter.segments - 1))
                radius: width / 2
                color: meter.muted ? Theme.outlineVariant : Theme.surfaceContainerHighest

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Theme.primary
                    opacity: segment.isHeld ? Math.max(segment.fill, 0.5) : segment.fill
                }
            }
        }
    }
}
