pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets

// the mixer: a dot on a line between two groups; drag it, scroll to nudge it, double-click to recentre
Item {
    id: pad

    property var groups: []
    property var factors: []
    property var dot: ({
            "x": 0.5,
            "y": 0.5
        })

    // normalised, like the dot
    signal moved(var point)
    signal nudged(bool towardsVertex)
    signal recentred

    width: parent?.width ?? 0
    implicitHeight: line.height

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
                opacity: drag.pressed ? 0.16 : drag.containsMouse ? 0.08 : 0

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
                id: drag

                anchors.fill: parent
                anchors.margins: -Theme.spacingS
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                function place(mouse) {
                    const x = mouse.x + drag.anchors.margins - handle.width / 2;
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
}
