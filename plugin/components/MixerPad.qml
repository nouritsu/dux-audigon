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

    // three or more: each vertex a group, their factors in the chips below
    Column {
        id: polygon

        visible: pad.groups.length >= 3
        width: parent.width
        spacing: Theme.spacingS

        Item {
            id: area

            // room for the vertex markers
            readonly property real inset: Theme.buttonHeightXS / 2 + 2
            readonly property real span: width - inset * 2

            function at(p) {
                return Qt.point(inset + p.x * span, inset + p.y * span);
            }

            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width, 200)
            height: width

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: Theme.withAlpha(Theme.primary, 0.06)
                    strokeColor: Theme.outlineVariant
                    strokeWidth: 1.5
                    joinStyle: ShapePath.RoundJoin

                    PathPolyline {
                        path: pad.vertices.concat(pad.vertices.slice(0, 1)).map(v => area.at(v))
                    }
                }

                // the centre to each vertex
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Theme.outlineVariant
                    strokeWidth: 1
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [2, 3]

                    PathMultiline {
                        paths: pad.vertices.map(v => [area.at(Mixer.centre()), area.at(v)])
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
                    readonly property point centre: area.at(modelData)

                    x: centre.x - width / 2
                    y: centre.y - height / 2
                    width: Theme.buttonHeightXS - Theme.spacingXS
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

            Rectangle {
                readonly property point centre: area.at(pad.dot)

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

                readonly property point centre: area.at(pad.dot)

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

                function place(mouse) {
                    pad.moved({
                        "x": (mouse.x - area.inset) / area.span,
                        "y": (mouse.y - area.inset) / area.span
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

        Flow {
            width: parent.width
            spacing: Theme.spacingXS

            Repeater {
                model: pad.groups

                GroupBadge {
                    required property var modelData
                    required property int index

                    tone: index
                    icon: modelData.icon
                    name: modelData.name
                    factor: pad.factors[index] ?? 1
                }
            }
        }
    }
}
