pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.DCommon.Widgets
import "../lib/mixer.js" as Mixer

// the mixer: a dot on a line between two groups, or inside a polygon of three or more; drag it,
// scroll to nudge it, middle-click to recentre. Right-click a group to mute it, closing off its
// side of the shape, or the shape itself to switch the mixer off and on
Item {
    id: pad

    property var groups: []
    // after mutes
    property var factors: []
    property var muted: []
    property bool bypassed: false
    // where the dot is in use: held out of muted groups' sides
    property var dot: ({
            "x": 0.5,
            "y": 0.5
        })

    readonly property var vertices: Mixer.vertices(groups.length)
    readonly property color openFill: Theme.withAlpha(Theme.primary, 0.06)
    readonly property color closedFill: Theme.withAlpha(Theme.onSurface, 0.08)
    readonly property color dotColor: bypassed ? Theme.surfaceVariantText : Theme.primary

    // normalised, like the dot
    signal moved(var point)
    signal nudged(bool towardsVertex)
    signal recentred
    signal muteToggled(int index)
    signal bypassToggled

    width: parent?.width ?? 0
    implicitHeight: groups.length === 2 ? line.height : polygon.height

    Item {
        id: line

        visible: pad.groups.length === 2
        width: parent.width
        height: Math.max(leftChip.height, handle.height + Theme.spacingS * 2)
        opacity: pad.bypassed ? 0.38 : 1

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.shortDuration
            }
        }

        GroupBadge {
            id: leftChip

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            tone: 0
            icon: pad.groups[0]?.icon ?? ""
            name: pad.groups[0]?.name ?? ""
            factor: pad.factors[0] ?? 1
            muted: pad.muted[0] ?? false
            muteable: true
            onMuteToggled: pad.muteToggled(0)
        }

        GroupBadge {
            id: rightChip

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            tone: 1
            icon: pad.groups[1]?.icon ?? ""
            name: pad.groups[1]?.name ?? ""
            factor: pad.factors[1] ?? 1
            muted: pad.muted[1] ?? false
            muteable: true
            onMuteToggled: pad.muteToggled(1)
        }

        Item {
            id: track

            anchors.left: leftChip.right
            anchors.right: rightChip.left
            anchors.leftMargin: Theme.spacingM
            anchors.rightMargin: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            height: handle.height

            // each half belongs to the group at its end; a muted group's half fades out
            Repeater {
                model: 2

                Rectangle {
                    required property int index

                    x: index * track.width / 2
                    y: (track.height - height) / 2
                    width: track.width / 2
                    height: Theme.spacingXS
                    radius: height / 2
                    color: pad.muted[index] ? pad.closedFill : Theme.surfaceContainerHighest
                }
            }

            // the centre, where both are full
            Rectangle {
                anchors.centerIn: parent
                width: 2
                height: handle.height - Theme.spacingXS
                radius: 1
                color: Theme.outlineVariant
            }

            // hover and press ring, then the dot
            Rectangle {
                anchors.centerIn: handle
                width: handle.width + Theme.spacingM
                height: width
                radius: width / 2
                color: pad.dotColor
                opacity: pad.bypassed ? 0 : lineDrag.pressed ? 0.16 : lineDrag.containsMouse ? 0.08 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.shorterDuration
                    }
                }
            }

            Rectangle {
                id: handle

                x: pad.dot.x * (track.width - width)
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.iconSizeSmall + Theme.spacingXS
                height: width
                radius: width / 2
                color: pad.dotColor
                border.width: 2
                border.color: Theme.surfaceContainer
            }

            // the chips take their own right-clicks; anywhere on the track switches the mixer
            MouseArea {
                id: lineDrag

                anchors.fill: parent
                anchors.margins: -Theme.spacingS
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                function place(mouse) {
                    const x = mouse.x + lineDrag.anchors.margins - handle.width / 2;
                    pad.moved({
                        "x": Math.max(0, Math.min(1, x / Math.max(1, track.width - handle.width))),
                        "y": 0.5
                    });
                }

                onPressed: mouse => {
                    if (mouse.button === Qt.RightButton)
                        pad.bypassToggled();
                    else if (pad.bypassed)
                        return;
                    else if (mouse.button === Qt.MiddleButton)
                        pad.recentred();
                    else
                        place(mouse);
                }
                onPositionChanged: mouse => {
                    if (!pad.bypassed && pressedButtons & Qt.LeftButton)
                        place(mouse);
                }
                onWheel: wheel => {
                    if (!pad.bypassed)
                        pad.nudged(wheel.angleDelta.y > 0);
                }
            }
        }
    }

    // three or more: a marker at each vertex, its group's name and factor beside it
    Item {
        id: polygon

        // the polygon's extent in mixer units; a triangle leaves the bottom of its circle empty
        readonly property real minY: Math.min(...pad.vertices.map(v => v.y))
        readonly property real maxY: Math.max(...pad.vertices.map(v => v.y))

        readonly property real markerSize: Theme.buttonHeightXS - Theme.spacingXS
        readonly property real labelGap: Theme.spacingXS
        readonly property real labelWidth: 80
        readonly property real labelHeight: probe.implicitHeight * 2
        readonly property bool hasTop: pad.vertices.some(v => side(v) === 0 && v.y < 0.5)
        readonly property bool hasBottom: pad.vertices.some(v => side(v) === 0 && v.y > 0.5)

        // room around the polygon for markers and labels
        readonly property real sideRoom: markerSize / 2 + labelGap + labelWidth
        readonly property real edgeRoom: Math.max(markerSize, labelHeight) / 2 + 2
        readonly property real topRoom: hasTop ? markerSize / 2 + labelGap + labelHeight : edgeRoom
        readonly property real bottomRoom: hasBottom ? markerSize / 2 + labelGap + labelHeight : edgeRoom

        // pixels per mixer unit
        readonly property real unit: Math.max(80, Math.min(200, width - sideRoom * 2))

        // left of centre -1, right 1, top or bottom 0
        function side(v) {
            const dx = v.x - 0.5;
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

        visible: pad.groups.length >= 3
        opacity: pad.bypassed ? 0.38 : 1
        width: parent.width
        height: topRoom + (maxY - minY) * unit + bottomRoom

        StyledText {
            id: probe

            visible: false
            text: "Ag"
            font.pixelSize: Theme.fontSizeSmall
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.shortDuration
            }
        }

        // the sectors between the centre and two neighbouring vertices, closed off by either one's mute
        readonly property var sectors: pad.vertices.map((v, i) => {
            const j = (i + 1) % pad.vertices.length;
            return {
                "open": !(pad.muted[i] ?? false) && !(pad.muted[j] ?? false),
                "path": [polygon.at(Mixer.centre()), polygon.at(v), polygon.at(pad.vertices[j]), polygon.at(Mixer.centre())]
            };
        })
        // spokes to unmuted vertices; one with no open sector beside it is the dot's only way there
        readonly property var spokes: pad.vertices.map((v, i) => ({
                    "open": !(pad.muted[i] ?? false),
                    "alone": !(sectors[i]?.open ?? false) && !(sectors[(i + pad.vertices.length - 1) % pad.vertices.length]?.open ?? false),
                    "path": [polygon.at(Mixer.centre()), polygon.at(v)]
                }))

        // a vertex's marker or label under the pointer, else -1
        function groupAt(x, y) {
            for (let i = 0; i < pad.vertices.length; i++) {
                for (const item of [markers.itemAt(i), labels.itemAt(i)]) {
                    if (item && item.contains(item.mapFromItem(polygon, x, y)))
                        return i;
                }
            }
            return -1;
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: pad.openFill
                strokeColor: "transparent"

                PathMultiline {
                    paths: polygon.sectors.filter(s => s.open).map(s => s.path)
                }
            }

            ShapePath {
                fillColor: pad.closedFill
                strokeColor: "transparent"

                PathMultiline {
                    paths: polygon.sectors.filter(s => !s.open).map(s => s.path)
                }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: Theme.outlineVariant
                strokeWidth: 1.5
                joinStyle: ShapePath.RoundJoin

                PathPolyline {
                    path: pad.vertices.concat(pad.vertices.slice(0, 1)).map(v => polygon.at(v))
                }
            }

            // the centre, where all are full, to each unmuted vertex
            ShapePath {
                fillColor: "transparent"
                strokeColor: Theme.outlineVariant
                strokeWidth: 1
                strokeStyle: ShapePath.DashLine
                dashPattern: [2, 3]

                PathMultiline {
                    paths: polygon.spokes.filter(s => s.open && !s.alone).map(s => s.path)
                }
            }

            // a spoke that's all the dot has left towards its vertex
            ShapePath {
                fillColor: "transparent"
                strokeColor: Theme.withAlpha(Theme.primary, 0.5)
                strokeWidth: 2
                capStyle: ShapePath.RoundCap

                PathMultiline {
                    paths: polygon.spokes.filter(s => s.open && s.alone).map(s => s.path)
                }
            }
        }

        Repeater {
            id: markers

            model: pad.vertices

            // its group's icon in its tone, fading with its factor; greyed with a muted icon when muted
            Rectangle {
                id: marker

                required property var modelData
                required property int index
                readonly property point centre: polygon.at(modelData)
                readonly property bool muted: pad.muted[index] ?? false

                x: centre.x - width / 2
                y: centre.y - height / 2
                width: polygon.markerSize
                height: width
                radius: width / 2
                color: muted ? Theme.surfaceContainerHighest : [Theme.primaryContainer, Theme.tertiaryContainer, Theme.secondaryContainer][index % 3]
                opacity: muted ? 1 : 0.45 + 0.55 * (pad.factors[index] ?? 1)

                DIcon {
                    anchors.centerIn: parent
                    name: marker.muted ? "volume_off" : pad.groups[marker.index]?.icon ?? ""
                    size: Theme.iconSizeSmall
                    color: marker.muted ? Theme.surfaceVariantText : [Theme.onPrimaryContainer, Theme.onTertiaryContainer, Theme.onSecondaryContainer][marker.index % 3]
                }
            }
        }

        Repeater {
            id: labels

            model: pad.vertices

            // name over factor: beside a side vertex, above or below a top or bottom one
            Item {
                id: label

                required property var modelData
                required property int index
                readonly property int side: polygon.side(modelData)
                readonly property point centre: polygon.at(modelData)
                readonly property real reach: polygon.markerSize / 2 + polygon.labelGap
                readonly property bool muted: pad.muted[index] ?? false

                x: side > 0 ? centre.x + reach : side < 0 ? centre.x - reach - width : centre.x - width / 2
                y: side !== 0 ? centre.y - height / 2 : modelData.y < 0.5 ? centre.y - reach - height : centre.y + reach
                width: texts.implicitWidth
                height: texts.implicitHeight

                Column {
                    id: texts

                    StyledText {
                        x: label.side < 0 ? label.width - width : label.side > 0 ? 0 : (label.width - width) / 2
                        width: Math.min(implicitWidth, polygon.labelWidth)
                        text: pad.groups[label.index]?.name ?? ""
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Theme.fontWeightMedium
                        color: label.muted ? Theme.surfaceVariantText : Theme.surfaceText
                        wrapMode: Text.NoWrap
                        elide: Text.ElideRight
                    }

                    StyledText {
                        x: label.side < 0 ? label.width - width : label.side > 0 ? 0 : (label.width - width) / 2
                        text: label.muted ? "Muted" : Math.round((pad.factors[label.index] ?? 1) * 100) + "%"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                }
            }
        }

        // hover and press ring, then the dot
        Rectangle {
            readonly property point centre: polygon.at(pad.dot)

            x: centre.x - width / 2
            y: centre.y - height / 2
            width: polyHandle.width + Theme.spacingM
            height: width
            radius: width / 2
            color: pad.dotColor
            opacity: pad.bypassed ? 0 : polyDrag.pressed ? 0.16 : polyDrag.containsMouse ? 0.08 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.shorterDuration
                }
            }
        }

        Rectangle {
            id: polyHandle

            readonly property point centre: polygon.at(pad.dot)

            x: centre.x - width / 2
            y: centre.y - height / 2
            width: Theme.iconSizeSmall + Theme.spacingXS
            height: width
            radius: width / 2
            color: pad.dotColor
            border.width: 2
            border.color: Theme.surfaceContainer
        }

        // right-click: a vertex's marker or label mutes its group, inside the shape switches the mixer
        MouseArea {
            id: polyDrag

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

            onPressed: mouse => {
                if (mouse.button === Qt.RightButton) {
                    const group = polygon.groupAt(mouse.x, mouse.y);
                    if (group >= 0)
                        pad.muteToggled(group);
                    else if (Mixer.inside(pad.vertices, polygon.from(mouse.x, mouse.y)))
                        pad.bypassToggled();
                } else if (pad.bypassed) {
                    return;
                } else if (mouse.button === Qt.MiddleButton) {
                    pad.recentred();
                } else {
                    pad.moved(polygon.from(mouse.x, mouse.y));
                }
            }
            onPositionChanged: mouse => {
                if (!pad.bypassed && pressedButtons & Qt.LeftButton)
                    pad.moved(polygon.from(mouse.x, mouse.y));
            }
            onWheel: wheel => {
                if (!pad.bypassed)
                    pad.nudged(wheel.angleDelta.y > 0);
            }
        }
    }
}
