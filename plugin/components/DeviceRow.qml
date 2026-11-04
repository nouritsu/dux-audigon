pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.DCommon.Widgets

// the default output or input: its header line unfolds the devices below it, then mute and volume
DListRow {
    id: row

    property var node: null
    property var devices: []
    property bool isInput: false
    property int maxVolume: 100
    property bool metering: false
    // set by the popout, so only one row is unfolded and both fold when it closes
    property bool expanded: false

    readonly property var audio: node?.audio ?? null
    readonly property int level: audio ? Math.round(audio.volume * 100) : 0
    readonly property bool muted: audio?.muted ?? false

    signal toggled
    signal picked(var device)

    function deviceIcon(device) {
        return isInput ? "mic" : AudioService.sinkIcon(device);
    }

    width: parent?.width ?? 0
    implicitHeight: body.implicitHeight + Theme.spacingS * 2

    Column {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        // the header's own padding brings its icon in line with the app rows'
        anchors.leftMargin: Theme.spacingXS
        anchors.rightMargin: Theme.spacingS
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingXXS

        Item {
            id: header

            width: parent.width
            height: Theme.buttonHeightXS

            // icon, name and chevron, like dux's own menu labels
            Row {
                id: label

                readonly property real maxWidth: header.width - meter.width - Theme.spacingXS - Theme.spacingS * 2

                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingS

                DIcon {
                    id: headerIcon

                    anchors.verticalCenter: parent.verticalCenter
                    name: row.deviceIcon(row.node)
                    size: Theme.iconSizeMedium
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, label.maxWidth - headerIcon.width - chevron.width - label.spacing * 2)
                    text: row.node ? AudioService.displayName(row.node) : row.isInput ? "No input device" : "No output device"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightMedium
                    color: row.node ? Theme.surfaceText : Theme.surfaceVariantText
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                }

                DIcon {
                    id: chevron

                    anchors.verticalCenter: parent.verticalCenter
                    name: "arrow_drop_down"
                    size: Theme.iconSizeMedium
                    color: Theme.surfaceVariantText
                    rotation: row.expanded ? 180 : 0

                    Behavior on rotation {
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }
            }

            LevelMeter {
                id: meter

                anchors.left: label.right
                anchors.leftMargin: Theme.spacingXS
                anchors.verticalCenter: parent.verticalCenter
                node: row.node
                active: row.metering
            }

            // the whole line is the target, not just the label
            StateLayer {
                cornerRadius: height / 2
                onClicked: row.toggled()
            }
        }

        // the devices, unfolded in place: no menu window to lose a click to
        Item {
            id: fold

            width: parent.width
            height: row.expanded ? options.implicitHeight : 0
            opacity: row.expanded ? 1 : 0
            visible: height > 0
            clip: true

            Behavior on height {
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

            Column {
                id: options

                width: parent.width
                topPadding: Theme.spacingXXS
                bottomPadding: Theme.spacingXS
                spacing: Theme.spacingXXS

                Repeater {
                    model: ScriptModel {
                        values: row.devices
                    }

                    // the current one sits in a filled pill, like a selected navigation item
                    Item {
                        id: option

                        required property var modelData
                        readonly property bool current: modelData === row.node

                        width: options.width
                        height: Theme.buttonHeightXS

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: Theme.secondaryContainer
                            visible: option.current
                        }

                        DIcon {
                            id: optionIcon

                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            name: row.deviceIcon(option.modelData)
                            size: Theme.iconSizeMedium
                            color: option.current ? Theme.onSecondaryContainer : Theme.surfaceVariantText
                        }

                        StyledText {
                            anchors.left: optionIcon.right
                            anchors.right: check.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            text: AudioService.displayName(option.modelData)
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: option.current ? Theme.fontWeightMedium : Font.Normal
                            color: option.current ? Theme.onSecondaryContainer : Theme.surfaceText
                            wrapMode: Text.NoWrap
                            elide: Text.ElideRight
                        }

                        DIcon {
                            id: check

                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            name: "check"
                            size: Theme.iconSizeSmall
                            color: Theme.onSecondaryContainer
                            visible: option.current
                        }

                        StateLayer {
                            cornerRadius: height / 2
                            stateColor: option.current ? Theme.onSecondaryContainer : Theme.surfaceText
                            onClicked: row.picked(option.modelData)
                        }
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: Math.max(muteButton.height, slider.height)

            DActionButton {
                id: muteButton

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                buttonSize: Theme.buttonHeightXS
                iconSize: Theme.iconSizeMedium
                iconName: row.isInput ? (row.muted ? "mic_off" : "mic") : AudioService.volumeIconName(row.node)
                iconColor: row.muted ? Theme.surfaceVariantText : Theme.primary
                tooltipText: row.muted ? "Unmute" : "Mute"
                enabled: row.audio !== null
                onClicked: row.audio.muted = !row.audio.muted
            }

            VolumeSlider {
                id: slider

                anchors.left: muteButton.right
                anchors.right: valueText.left
                anchors.leftMargin: Theme.spacingXS
                anchors.rightMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                maximum: row.maxVolume
                level: row.level
                muted: row.muted
                enabled: row.audio !== null
                onSliderValueChanged: newValue => {
                    if (row.audio)
                        row.audio.volume = newValue / 100;
                }
            }

            StyledText {
                id: valueText

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                text: row.level + "%"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
