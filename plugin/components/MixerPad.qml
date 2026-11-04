pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.DCommon.Widgets
import "../lib/mixer.js" as Mixer

// the mixer: a dot on a line between two groups, or inside a polygon of three or more;
// drag it, scroll to nudge it, double-click to recentre
Item {
    id: pad

    property var groups: []
    property var factors: []
    property var dot: ({
            "x": 0.5,
            "y": 0.5
        })

    readonly property var vertices: Mixer.vertices(groups.length)

    // normalised, like the dot
    signal moved(var point)
    signal nudged(bool towardsVertex)
    signal recentred

    width: parent?.width ?? 0
    implicitHeight: groups.length === 2 ? line.height : polygon.height

    Item {
        id: line

        visible: pad.groups.length === 2
        width: parent.width
        height: Math.max(leftChip.height, handle.height + Theme.spacingS * 2)

        GroupBadge {
            id: leftChip

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            tone: 0
            icon: pad.groups[0]?.icon ?? ""
            name: pad.groups[0]?.name ?? ""
            factor: pad.factors[0] ?? 1
        }

        GroupBadge {
            id: rightChip

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            tone: 1
            icon: pad.groups[1]?.icon ?? ""
            name: pad.groups[1]?.name ?? ""
            factor: pad.factors[1] ?? 1
        }

        Item {
            id: track

            anchors.left: leftChip.right
            anchors.right: rightChip.left
            anchors.leftMargin: Theme.spacingM
            anchors.rightMargin: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            height: handle.height

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: Theme.spacingXS
                radius: height / 2
                color: Theme.surfaceContainerHighest
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
                color: Theme.primary
                opacity: lineDrag.pressed ? 0.16 : lineDrag.containsMouse ? 0.08 : 0

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
                color: Theme.primary
                border.width: 2
                border.color: Theme.surfaceContainer
            }

            MouseArea {
                id: lineDrag

                anchors.fill: parent
                anchors.margins: -Theme.spacingS
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                function place(mouse) {
                    const x = mouse.x + lineDrag.anchors.margins - handle.width / 2;
                    pad.moved({
                        "x": Math.max(0, Math.min(1, x / Math.max(1, track.width - handle.width))),
                        "y": 0.5
                    });
                }

                onPressed: mouse => place(mouse)
                onPositionChanged: mouse => {
                    if (pressed)
                        place(mouse);
                }
                onDoubleClicked: pad.recentred()
                onWheel: wheel => pad.nudged(wheel.angleDelta.y > 0)
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
        width: parent.width
        height: topRoom + (maxY - minY) * unit + bottomRoom

        StyledText {
            id: probe

            visible: false
            text: "Ag"
            font.pixelSize: Theme.fontSizeSmall
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: Theme.withAlpha(Theme.primary, 0.06)
                strokeColor: Theme.outlineVariant
                strokeWidth: 1.5
                joinStyle: ShapePath.RoundJoin

                PathPolyline {
                    path: pad.vertices.concat(pad.vertices.slice(0, 1)).map(v => polygon.at(v))
                }
            }

            // the centre, where all are full, to each vertex
            ShapePath {
                fillColor: "transparent"
                strokeColor: Theme.outlineVariant
                strokeWidth: 1
                strokeStyle: ShapePath.DashLine
                dashPattern: [2, 3]

                PathMultiline {
                    paths: pad.vertices.map(v => [polygon.at(Mixer.centre()), polygon.at(v)])
                }
            }
        }

        Repeater {
            model: pad.vertices

            // its group's icon in its tone, fading with its factor
            Rectangle {
                id: marker

                required property var modelData
                required property int index
                readonly property point centre: polygon.at(modelData)

                x: centre.x - width / 2
                y: centre.y - height / 2
                width: polygon.markerSize
                height: width
                radius: width / 2
                color: [Theme.primaryContainer, Theme.tertiaryContainer, Theme.secondaryContainer][index % 3]
                opacity: 0.45 + 0.55 * (pad.factors[index] ?? 1)

                DIcon {
                    anchors.centerIn: parent
                    name: pad.groups[marker.index]?.icon ?? ""
                    size: Theme.iconSizeSmall
                    color: [Theme.onPrimaryContainer, Theme.onTertiaryContainer, Theme.onSecondaryContainer][marker.index % 3]
                }
            }
        }

        Repeater {
            model: pad.vertices

            // name over factor: beside a side vertex, above or below a top or bottom one
            Column {
                id: label

                required property var modelData
                required property int index
                readonly property int side: polygon.side(modelData)
                readonly property point centre: polygon.at(modelData)
                readonly property real reach: polygon.markerSize / 2 + polygon.labelGap

                x: side > 0 ? centre.x + reach : side < 0 ? centre.x - reach - width : centre.x - width / 2
                y: side !== 0 ? centre.y - height / 2 : modelData.y < 0.5 ? centre.y - reach - height : centre.y + reach

                StyledText {
                    x: label.side < 0 ? label.width - width : label.side > 0 ? 0 : (label.width - width) / 2
                    width: Math.min(implicitWidth, polygon.labelWidth)
                    text: pad.groups[label.index]?.name ?? ""
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightMedium
                    color: Theme.surfaceText
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                }

                StyledText {
                    x: label.side < 0 ? label.width - width : label.side > 0 ? 0 : (label.width - width) / 2
                    text: Math.round((pad.factors[label.index] ?? 1) * 100) + "%"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
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
            color: Theme.primary
            opacity: polyDrag.pressed ? 0.16 : polyDrag.containsMouse ? 0.08 : 0

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
            color: Theme.primary
            border.width: 2
            border.color: Theme.surfaceContainer
        }

        MouseArea {
            id: polyDrag

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            onPressed: mouse => pad.moved(polygon.from(mouse.x, mouse.y))
            onPositionChanged: mouse => {
                if (pressed)
                    pad.moved(polygon.from(mouse.x, mouse.y));
            }
            onDoubleClicked: pad.recentred()
            onWheel: wheel => pad.nudged(wheel.angleDelta.y > 0)
        }
    }
}
