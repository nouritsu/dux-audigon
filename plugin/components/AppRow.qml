pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.Common
import qs.DCommon.Widgets

// one playback stream: icon and name, then volume; the chevron shows a fine-adjust knob and reset
DListRow {
    id: row

    property var node: null
    property string name: ""
    property string iconSource: ""
    property string fallbackIcon: "graphic_eq"
    property int level: 0
    property int maxVolume: 100
    property int wheelStep: 2
    property bool metering: false
    readonly property bool muted: node?.audio?.muted ?? false

    property bool expanded: false
    property real controlsProgress: expanded ? 1 : 0

    signal levelSet(int value)
    signal nudged(int delta)
    signal resetRequested
    signal muteToggled

    Behavior on controlsProgress {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }

    width: parent?.width ?? 0
    implicitHeight: body.implicitHeight + Theme.spacingS * 2

    Column {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingS
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingXXS

        Item {
            id: header

            width: parent.width
            height: Theme.iconSizeMedium + Theme.spacingXS

            Item {
                id: icon

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.iconSizeMedium
                height: Theme.iconSizeMedium

                IconImage {
                    id: appIcon

                    anchors.fill: parent
                    source: row.iconSource
                    asynchronous: true
                    mipmap: true
                    smooth: true
                }

                DIcon {
                    anchors.centerIn: parent
                    visible: appIcon.status !== Image.Ready
                    name: row.fallbackIcon
                    size: Theme.iconSizeMedium
                    color: Theme.surfaceText
                }
            }

            StyledText {
                id: nameText

                anchors.left: icon.right
                anchors.leftMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, header.width - icon.width - meter.width - Theme.spacingS * 2)
                text: row.name
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightMedium
                color: Theme.surfaceText
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
            }

            LevelMeter {
                id: meter

                anchors.left: nameText.right
                anchors.leftMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                node: row.node
                active: row.metering
            }
        }

        Item {
            width: parent.width
            height: Math.max(slider.height, Theme.buttonHeightXS)

            Row {
                id: controls

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                // drag or scroll: volume steps, like the pill's wheel
                Item {
                    id: knob

                    property real dragAccum: 0
                    property real lastX: 0
                    property real lastY: 0
                    readonly property real angle: -135 + Math.max(0, Math.min(1, row.level / row.maxVolume)) * 270

                    width: Theme.buttonHeightXS * row.controlsProgress
                    height: Theme.buttonHeightXS
                    opacity: row.controlsProgress
                    visible: row.controlsProgress > 0
                    enabled: row.controlsProgress > 0.1
                    clip: true

                    Rectangle {
                        anchors.centerIn: parent
                        width: Theme.buttonHeightXS - Theme.spacingS
                        height: width
                        radius: width / 2
                        color: knobLayer.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                        border.width: 1
                        border.color: knobLayer.containsMouse ? Theme.surfaceVariantText : Theme.outlineVariant
                    }

                    Rectangle {
                        id: indicator

                        x: (parent.width - width) / 2
                        y: parent.height / 2 - height - 2
                        width: 3
                        height: parent.height * 0.25
                        radius: 2
                        color: knobLayer.containsMouse ? Theme.primary : Theme.surfaceVariantText

                        transform: Rotation {
                            origin.x: indicator.width / 2
                            origin.y: indicator.height + 2
                            angle: knob.angle
                        }
                    }

                    // hover and tooltip only; presses go to the drag handler
                    StateLayer {
                        id: knobLayer

                        acceptedButtons: Qt.NoButton
                        cornerRadius: Theme.cornerRadiusFull
                        tooltipText: "Drag or scroll to adjust"
                        tooltipSide: "top"
                    }

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: event => {
                            row.nudged(event.angleDelta.y > 0 ? row.wheelStep : -row.wheelStep);
                            event.accepted = true;
                        }
                    }

                    DragHandler {
                        target: null
                        grabPermissions: PointerHandler.CanTakeOverFromAnything
                        onActiveChanged: {
                            if (!active)
                                return;
                            knob.dragAccum = 0;
                            knob.lastX = translation.x;
                            knob.lastY = translation.y;
                        }
                        onTranslationChanged: {
                            // right and up raise it
                            knob.dragAccum += (translation.x - knob.lastX) + (knob.lastY - translation.y);
                            knob.lastX = translation.x;
                            knob.lastY = translation.y;
                            const steps = Math.trunc(knob.dragAccum / 4);
                            if (steps !== 0) {
                                row.nudged(steps * row.wheelStep);
                                knob.dragAccum -= steps * 4;
                            }
                        }
                    }
                }

                DActionButton {
                    width: Theme.buttonHeightXS * row.controlsProgress
                    buttonSize: Theme.buttonHeightXS
                    iconName: "restart_alt"
                    iconSize: Theme.iconSizeSmall
                    iconColor: Theme.surfaceVariantText
                    opacity: row.controlsProgress
                    visible: row.controlsProgress > 0
                    enabled: row.controlsProgress > 0.1
                    tooltipText: "Reset volume"
                    tooltipSide: "top"
                    onClicked: row.resetRequested()
                }

                DActionButton {
                    buttonSize: Theme.buttonHeightXS
                    iconName: row.expanded ? "chevron_left" : "chevron_right"
                    iconSize: Theme.iconSizeMedium
                    iconColor: Theme.surfaceVariantText
                    onClicked: row.expanded = !row.expanded
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    text: row.level + "%"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    horizontalAlignment: Text.AlignRight
                }

                Item {
                    width: Theme.spacingXS
                    height: 1
                }

                DActionButton {
                    buttonSize: Theme.buttonHeightXS
                    iconName: row.muted ? "volume_off" : "volume_up"
                    iconSize: Theme.iconSizeMedium
                    iconColor: row.muted ? Theme.surfaceVariantText : Theme.primary
                    tooltipText: row.muted ? "Unmute" : "Mute"
                    onClicked: row.muteToggled()
                }
            }

            VolumeSlider {
                id: slider

                anchors.left: parent.left
                anchors.right: controls.left
                anchors.rightMargin: Theme.spacingXS
                anchors.verticalCenter: parent.verticalCenter
                maximum: row.maxVolume
                level: row.level
                muted: row.muted
                onSliderValueChanged: newValue => row.levelSet(newValue)
            }
        }
    }
}
