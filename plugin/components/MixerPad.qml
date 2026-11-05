pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.Common
import qs.DCommon.Widgets
import "../lib/mixer.js" as Mixer

// the mixer: a dot among the groups that are playing. One sits alone, two at the ends of a track,
// three or more on a polygon, and the shape morphs as groups come, go or are excluded. Drag the dot,
// scroll to nudge it, double- or middle-click to recentre; right-click a group or the shape for its menu
Item {
    id: pad

    // the shape's groups, in order: {index, name, icon, style: {accent, container, content}}
    property var groups: []
    // per group, after mutes
    property var factors: []
    property var muted: []
    property bool bypassed: false
    // where the dot is in use
    property var dot: Mixer.centre()
    // where a group's stash icon is in this item, from the section; every group off the shape has one
    property var stashPoint: name => null
    // the popout is open: reshapes animate only then, and one cut off by closing it finishes at once
    property bool live: true

    signal moved(var point)
    signal nudged(bool towardsVertex)
    signal recentred
    signal enableRequested
    // in this item's coordinates
    signal groupMenuRequested(int index, real x, real y)
    signal shapeMenuRequested(real x, real y)

    // what's drawn: every group shown or on its way out, in order, and the last known of each
    property var keys: []
    property var known: ({})
    // the reshape in progress: key -> {from, to}, each {x, y, s}, for the outline; and a group
    // flying into the stash or out of it, its marker leaving the outline to get there
    property var moves: ({})
    property var flights: ({})
    property real t: 1
    readonly property bool morphing: t < 1

    readonly property color closedFill: Theme.withAlpha(Theme.onSurface, 0.08)
    readonly property color dotColor: bypassed ? Theme.surfaceVariantText : Theme.primary
    readonly property real markerSize: Theme.buttonHeightXS - Theme.spacingXS
    // a stash icon is a small marker
    readonly property real stashSize: Theme.iconSizeSmall + Theme.spacingXS
    readonly property real stashScale: stashSize / markerSize
    readonly property real labelGap: Theme.spacingXS
    readonly property real labelWidth: 80
    readonly property real labelHeight: probe.implicitHeight * 2

    // the outline's extent in mixer units, as drawn; a triangle leaves the bottom of its circle empty
    readonly property var drawn: keys.map(key => outlineAt(key)).filter(p => p !== null)
    readonly property real minY: drawn.length > 0 ? Math.min(...drawn.map(p => p.y)) : 0.5
    readonly property real maxY: drawn.length > 0 ? Math.max(...drawn.map(p => p.y)) : 0.5
    readonly property bool hasTop: drawn.some(p => side(p) === 0 && p.y < 0.5)
    readonly property bool hasBottom: drawn.some(p => side(p) === 0 && p.y >= 0.5)

    // room around the shape for markers and labels, and pixels per mixer unit
    readonly property real sideRoom: markerSize / 2 + labelGap + labelWidth
    readonly property real edgeRoom: Math.max(markerSize, labelHeight) / 2 + 2
    readonly property real topRoom: hasTop ? markerSize / 2 + labelGap + labelHeight : edgeRoom
    readonly property real bottomRoom: hasBottom ? markerSize / 2 + labelGap + labelHeight : edgeRoom
    readonly property real unit: Math.max(80, Math.min(200, width - sideRoom * 2))

    // the track for two, the outline and spokes for three or more, the dot for two or more
    property real lineAlpha: groups.length === 2 ? 1 : 0
    property real polyAlpha: groups.length >= 3 ? 1 : 0
    property real dotAlpha: groups.length >= 2 ? 1 : 0

    Behavior on lineAlpha {
        NumberAnimation {
            duration: Theme.mediumDuration
        }
    }

    Behavior on polyAlpha {
        NumberAnimation {
            duration: Theme.mediumDuration
        }
    }

    Behavior on dotAlpha {
        NumberAnimation {
            duration: Theme.mediumDuration
        }
    }

    width: parent?.width ?? 0
    implicitHeight: keys.length === 0 ? placeholder.implicitHeight + Theme.spacingS * 2 : topRoom + (maxY - minY) * unit + bottomRoom
    opacity: bypassed ? 0.38 : 1

    Behavior on implicitHeight {
        enabled: !pad.morphing
        NumberAnimation {
            duration: Theme.mediumDuration
            easing.type: Theme.emphasizedEasing
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.shortDuration
        }
    }

    // left of centre -1, right 1, top or bottom 0
    function side(p) {
        const dx = p.x - 0.5;
        return Math.abs(dx) > 0.2 ? (dx > 0 ? 1 : -1) : 0;
    }

    function at(p) {
        return Qt.point(width / 2 + (p.x - 0.5) * unit, topRoom + (p.y - minY) * unit);
    }

    function from(x, y) {
        return {
            "x": (x - width / 2) / unit + 0.5,
            "y": (y - topRoom) / unit + minY
        };
    }

    function mix(a, b, e) {
        return a + (b - a) * e;
    }

    function outlineAt(key) {
        const m = moves[key];
        if (!m)
            return null;
        return {
            "x": mix(m.from.x, m.to.x, t),
            "y": mix(m.from.y, m.to.y, t),
            "s": mix(m.from.s, m.to.s, t)
        };
    }

    function outlinePixel(key) {
        const p = outlineAt(key);
        return p ? at(p) : at(Mixer.centre());
    }

    // a marker follows the outline, unless it's flying to or from the stash
    function markerPixel(key) {
        const m = moves[key];
        const flight = flights[key];
        if (!m)
            return at(Mixer.centre());
        if (flight?.toStash) {
            const end = stashPoint(key) ?? at(m.to);
            return Qt.point(mix(flight.from.x, end.x, t), mix(flight.from.y, end.y, t));
        }
        if (flight?.from) {
            const end = at(m.to);
            return Qt.point(mix(flight.from.x, end.x, t), mix(flight.from.y, end.y, t));
        }
        return outlinePixel(key);
    }

    function markerScale(key) {
        const flight = flights[key];
        if (flight?.toStash)
            return mix(1, stashScale, t);
        if (flight?.from)
            return mix(stashScale, 1, t);
        return outlineAt(key)?.s ?? 0;
    }

    function labelOpacity(key) {
        const flight = flights[key];
        if (flight?.toStash)
            return Math.max(0, 1 - 2 * t);
        if (flight?.from)
            return Math.max(0, 2 * t - 1);
        return outlineAt(key)?.s ?? 0;
    }

    function groupAtKey(key) {
        return groups.findIndex(group => group.name === key);
    }

    function mutedOf(key) {
        const at = groupAtKey(key);
        return at >= 0 && (muted[at] ?? false);
    }

    function factorOf(key) {
        const at = groupAtKey(key);
        return at >= 0 ? factors[at] ?? 1 : 0;
    }

    function inFlight(name) {
        return morph.running && !!flights[name]?.toStash;
    }

    // the groups changed: morph from what's drawn now to their new places
    function reshape(animate) {
        const names = groups.map(group => group.name);
        const verts = Mixer.vertices(names.length);
        const after = {};
        names.forEach((name, i) => after[name] = verts[i]);
        const before = {};
        for (const key of keys) {
            const p = outlineAt(key);
            if (p && p.s > 0.001)
                before[key] = p;
        }
        const nextKnown = Object.assign({}, known);
        for (const group of groups)
            nextKnown[group.name] = group;
        const order = name => nextKnown[name]?.index ?? 0;
        const union = Array.from(new Set(keys.concat(names))).sort((a, b) => order(a) - order(b));
        const nextMoves = Mixer.transition(union, before, after);
        // one caught halfway keeps the size it had
        for (const key in nextMoves) {
            if (before[key])
                nextMoves[key].from.s = before[key].s;
        }
        // leaving: into its stash icon; joining: out of it, from where the icon sits as it collapses
        const nextFlights = {};
        for (const key of union) {
            if (!after[key] && before[key])
                nextFlights[key] = {
                    "toStash": true,
                    "from": markerPixel(key)
                };
            else if (after[key] && !before[key]) {
                const from = stashPoint(key);
                if (from)
                    nextFlights[key] = {
                        "from": from
                    };
            }
        }
        known = nextKnown;
        moves = nextMoves;
        flights = nextFlights;
        keys = union;
        if (animate) {
            t = 0;
            morph.restart();
        } else {
            morph.stop();
            t = 1;
            settle();
        }
    }

    // the morph is done: drop the groups that left and pin the rest where they ended
    function settle() {
        const names = groups.map(group => group.name);
        const pinned = {};
        for (const name of names) {
            const to = moves[name]?.to;
            if (to)
                pinned[name] = {
                    "from": to,
                    "to": to
                };
        }
        moves = pinned;
        flights = {};
        keys = names.filter(name => pinned[name] !== undefined);
    }

    onGroupsChanged: reshape(live)
    onLiveChanged: {
        if (!live && morphing) {
            morph.stop();
            t = 1;
            settle();
        }
    }
    Component.onCompleted: reshape(false)

    NumberAnimation {
        id: morph

        target: pad
        property: "t"
        from: 0
        to: 1
        duration: Theme.mediumDuration * 1.5
        easing.type: Easing.InOutCubic
        onFinished: pad.settle()
    }

    StyledText {
        id: probe

        visible: false
        text: "Ag"
        font.pixelSize: Theme.fontSizeSmall
    }

    StyledText {
        id: placeholder

        anchors.centerIn: parent
        visible: pad.keys.length === 0
        text: "Nothing playing"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
    }

    // each sector, between the centre and two neighbouring vertices, tinted by both; closed off by either one's mute
    Repeater {
        model: pad.keys.length >= 3 ? pad.keys.length : 0

        Shape {
            id: slice

            required property int index
            readonly property string a: pad.keys[index] ?? ""
            readonly property string b: pad.keys[(index + 1) % pad.keys.length] ?? ""
            readonly property point pa: pad.outlinePixel(a)
            readonly property point pb: pad.outlinePixel(b)
            readonly property point pc: pad.at(Mixer.centre())
            readonly property bool open: !pad.mutedOf(a) && !pad.mutedOf(b)
            readonly property color tintA: open ? Theme.withAlpha(pad.known[a]?.style?.accent ?? Theme.primary, 0.12) : pad.closedFill
            readonly property color tintB: open ? Theme.withAlpha(pad.known[b]?.style?.accent ?? Theme.primary, 0.12) : pad.closedFill

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            opacity: pad.polyAlpha

            ShapePath {
                strokeColor: "transparent"
                startX: slice.pc.x
                startY: slice.pc.y

                fillGradient: LinearGradient {
                    x1: slice.pa.x
                    y1: slice.pa.y
                    x2: slice.pb.x
                    y2: slice.pb.y

                    GradientStop {
                        position: 0
                        color: slice.tintA
                    }

                    GradientStop {
                        position: 1
                        color: slice.tintB
                    }
                }

                PathLine {
                    x: slice.pa.x
                    y: slice.pa.y
                }

                PathLine {
                    x: slice.pb.x
                    y: slice.pb.y
                }

                PathLine {
                    x: slice.pc.x
                    y: slice.pc.y
                }
            }
        }
    }

    Shape {
        id: lines

        readonly property point centre: pad.at(Mixer.centre())
        readonly property var spokes: pad.keys.map((key, i) => {
            const n = pad.keys.length;
            const left = pad.keys[(i + n - 1) % n];
            const right = pad.keys[(i + 1) % n];
            return {
                "open": !pad.mutedOf(key),
                // no open sector beside it: the spoke is the dot's only way there
                "alone": (pad.mutedOf(key) || pad.mutedOf(left)) && (pad.mutedOf(key) || pad.mutedOf(right)),
                "path": [lines.centre, pad.outlinePixel(key)]
            };
        })

        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // two groups: a track, each half the group's at its end, a muted one's faded
        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.withAlpha(Theme.surfaceContainerHighest, pad.lineAlpha)
            strokeWidth: Theme.spacingXS
            capStyle: ShapePath.RoundCap

            PathMultiline {
                paths: lines.spokes.filter(s => s.open).map(s => s.path)
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.withAlpha(pad.closedFill, pad.lineAlpha)
            strokeWidth: Theme.spacingXS
            capStyle: ShapePath.RoundCap

            PathMultiline {
                paths: lines.spokes.filter(s => !s.open).map(s => s.path)
            }
        }

        // three or more: the outline, dashed spokes to unmuted vertices, a solid one where it's all that's left
        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.withAlpha(Theme.outlineVariant, pad.polyAlpha)
            strokeWidth: 1.5
            joinStyle: ShapePath.RoundJoin

            PathPolyline {
                path: pad.keys.length >= 3 ? pad.keys.concat(pad.keys.slice(0, 1)).map(key => pad.outlinePixel(key)) : []
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.withAlpha(Theme.outlineVariant, pad.polyAlpha)
            strokeWidth: 1
            strokeStyle: ShapePath.DashLine
            dashPattern: [2, 3]

            PathMultiline {
                paths: lines.spokes.filter(s => s.open && !s.alone).map(s => s.path)
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.withAlpha(Theme.primary, 0.5 * pad.polyAlpha)
            strokeWidth: 2
            capStyle: ShapePath.RoundCap

            PathMultiline {
                paths: lines.spokes.filter(s => s.open && s.alone).map(s => s.path)
            }
        }
    }

    // the centre, where all are full
    Rectangle {
        readonly property point centre: pad.at(Mixer.centre())

        x: centre.x - width / 2
        y: centre.y - height / 2
        width: Theme.spacingXS
        height: width
        radius: width / 2
        color: Theme.outlineVariant
        opacity: pad.dotAlpha
    }

    Repeater {
        id: markers

        model: ScriptModel {
            values: pad.keys
        }

        // its group's icon in its colours, fading with its factor; greyed with a muted icon when muted
        Rectangle {
            id: marker

            required property string modelData
            readonly property var group: pad.known[modelData] ?? ({})
            readonly property point centre: pad.markerPixel(modelData)
            readonly property bool muted: pad.mutedOf(modelData)

            x: centre.x - width / 2
            y: centre.y - height / 2
            width: pad.markerSize
            height: width
            radius: width / 2
            scale: pad.markerScale(modelData)
            color: muted ? Theme.surfaceContainerHighest : group.style?.container ?? Theme.primaryContainer
            opacity: muted ? 1 : 0.45 + 0.55 * pad.factorOf(modelData)

            DIcon {
                anchors.centerIn: parent
                name: marker.muted ? "volume_off" : marker.group.icon ?? ""
                size: Theme.iconSizeSmall
                color: marker.muted ? Theme.surfaceVariantText : marker.group.style?.content ?? Theme.onPrimaryContainer
            }
        }
    }

    Repeater {
        id: labels

        model: ScriptModel {
            values: pad.keys
        }

        // name over factor: beside a side vertex, above or below a top or bottom one
        Item {
            id: label

            required property string modelData
            readonly property var p: pad.outlineAt(modelData) ?? Mixer.centre()
            readonly property int side: pad.side(p)
            readonly property point centre: pad.markerPixel(modelData)
            readonly property real reach: pad.markerSize / 2 + pad.labelGap
            readonly property bool muted: pad.mutedOf(modelData)

            x: side > 0 ? centre.x + reach : side < 0 ? centre.x - reach - width : centre.x - width / 2
            y: side !== 0 ? centre.y - height / 2 : p.y < 0.5 ? centre.y - reach - height : centre.y + reach
            width: texts.implicitWidth
            height: texts.implicitHeight
            opacity: pad.labelOpacity(modelData)

            Column {
                id: texts

                StyledText {
                    x: label.side < 0 ? label.width - width : label.side > 0 ? 0 : (label.width - width) / 2
                    width: Math.min(implicitWidth, pad.labelWidth)
                    text: pad.known[label.modelData]?.name ?? ""
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightMedium
                    color: label.muted ? Theme.surfaceVariantText : Theme.surfaceText
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                }

                StyledText {
                    x: label.side < 0 ? label.width - width : label.side > 0 ? 0 : (label.width - width) / 2
                    text: label.muted ? "Muted" : Math.round(pad.factorOf(label.modelData) * 100) + "%"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }
        }
    }

    // hover and press ring, then the dot; it glides with the shape while that morphs
    Item {
        id: dotHolder

        readonly property point target: pad.at(pad.dot)

        x: target.x
        y: target.y
        opacity: pad.dotAlpha

        Behavior on x {
            enabled: pad.morphing
            NumberAnimation {
                duration: Theme.mediumDuration
            }
        }

        Behavior on y {
            enabled: pad.morphing
            NumberAnimation {
                duration: Theme.mediumDuration
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: dotHandle.width + Theme.spacingM
            height: width
            radius: width / 2
            color: pad.dotColor
            opacity: pad.bypassed ? 0 : drag.pressed ? 0.16 : drag.containsMouse ? 0.08 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.shorterDuration
                }
            }
        }

        Rectangle {
            id: dotHandle

            anchors.centerIn: parent
            width: Theme.iconSizeSmall + Theme.spacingXS
            height: width
            radius: width / 2
            color: pad.dotColor
            border.width: 2
            border.color: Theme.surfaceContainer
        }
    }

    // left drags the dot, or turns the mixer back on while it's off; right-click opens a group's
    // menu over its marker or name, the shape's anywhere on it
    MouseArea {
        id: drag

        // when a left click last turned the mixer back on
        property double enabledAt: 0

        // a group's marker or label under the pointer, as its index, else -1
        function groupAt(x, y) {
            for (let i = 0; i < pad.keys.length; i++) {
                for (const item of [markers.itemAt(i), labels.itemAt(i)]) {
                    if (item && item.opacity > 0.5 && item.contains(item.mapFromItem(pad, x, y)))
                        return pad.known[pad.keys[i]]?.index ?? -1;
                }
            }
            return -1;
        }

        function onShape(x, y) {
            const n = pad.groups.length;
            if (n >= 3)
                return Mixer.inside(Mixer.vertices(n), pad.from(x, y));
            if (n === 2) {
                const a = pad.at(Mixer.vertices(2)[0]);
                const b = pad.at(Mixer.vertices(2)[1]);
                return x >= a.x - pad.markerSize / 2 && x <= b.x + pad.markerSize / 2 && Math.abs(y - a.y) <= pad.markerSize / 2;
            }
            return false;
        }

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: pad.groups.length >= 2 ? Qt.PointingHandCursor : Qt.ArrowCursor
        preventStealing: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        onPressed: mouse => {
            if (mouse.button === Qt.RightButton) {
                const group = groupAt(mouse.x, mouse.y);
                if (group >= 0)
                    pad.groupMenuRequested(group, mouse.x, mouse.y);
                else if (onShape(mouse.x, mouse.y))
                    pad.shapeMenuRequested(mouse.x, mouse.y);
            } else if (pad.bypassed) {
                if (mouse.button === Qt.LeftButton && onShape(mouse.x, mouse.y)) {
                    enabledAt = Date.now();
                    pad.enableRequested();
                }
            } else if (pad.groups.length < 2) {
                return;
            } else if (mouse.button === Qt.MiddleButton) {
                pad.recentred();
            } else {
                pad.moved(pad.from(mouse.x, mouse.y));
            }
        }
        onPositionChanged: mouse => {
            if (!pad.bypassed && pad.groups.length >= 2 && pressedButtons & Qt.LeftButton)
                pad.moved(pad.from(mouse.x, mouse.y));
        }
        // like a middle-click; a double-click that just turned the mixer on leaves the dot be
        onDoubleClicked: mouse => {
            if (mouse.button === Qt.LeftButton && !pad.bypassed && pad.groups.length >= 2 && Date.now() - enabledAt > 600)
                pad.recentred();
        }
        onWheel: wheel => {
            if (!pad.bypassed && pad.groups.length >= 2)
                pad.nudged(wheel.angleDelta.y > 0);
        }
    }
}
