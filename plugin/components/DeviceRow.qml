pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets

// the default output or input: its name opens the device menu, then mute and volume
DListRow {
    id: row

    property var node: null
    property var devices: []
    property bool isInput: false
    property int maxVolume: 100
    property bool metering: false
    // the popout's, so the picker's menu doesn't count as a click outside it
    property var transientSurfaceTracker: null

    readonly property var audio: node?.audio ?? null
    readonly property int level: audio ? Math.round(audio.volume * 100) : 0
    readonly property bool muted: audio?.muted ?? false

    signal picked(var device)

    width: parent?.width ?? 0
    implicitHeight: body.implicitHeight + Theme.spacingS * 2

    Column {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        // the trigger's own padding brings its icon in line with the app rows'
        anchors.leftMargin: Theme.spacingXS
        anchors.rightMargin: Theme.spacingS
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingXXS

        Item {
            id: header

            width: parent.width
            height: Theme.buttonHeightXS

            // icon, name and chevron, with a pill state layer, like dux's own menu labels
            Item {
                id: trigger

                readonly property real maxWidth: header.width - meter.width - Theme.spacingXS

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(triggerRow.implicitWidth + Theme.spacingS * 2, maxWidth)
                height: Theme.buttonHeightXS

                Row {
                    id: triggerRow

                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingS

                    DIcon {
                        id: deviceIcon

                        anchors.verticalCenter: parent.verticalCenter
                        name: row.isInput ? "mic" : AudioService.sinkIcon(row.node)
                        size: Theme.iconSizeMedium
                        color: Theme.surfaceVariantText
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, trigger.maxWidth - Theme.spacingS * 2 - deviceIcon.width - chevron.width - triggerRow.spacing * 2)
                        text: row.node ? AudioService.displayName(row.node) : picker.emptyText
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
                        rotation: picker.menuOpen ? 180 : 0

                        Behavior on rotation {
                            NumberAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }
                    }
                }

                StateLayer {
                    cornerRadius: height / 2
                    tooltipText: row.isInput ? "Input device" : "Output device"
                    tooltipSide: "top"
                    onClicked: picker.openDropdownMenu()
                }
            }

            LevelMeter {
                id: meter

                anchors.left: trigger.right
                anchors.leftMargin: Theme.spacingXS
                anchors.verticalCenter: parent.verticalCenter
                node: row.node
                active: row.metering
            }

            // menu only; the label above is its trigger
            DDropdown {
                id: picker

                showTrigger: false
                focusPolicy: Qt.NoFocus
                compactMode: true
                popupAnchorItem: trigger
                popupWidth: header.width
                transientSurfaceTracker: row.transientSurfaceTracker
                options: row.devices.map(device => AudioService.displayName(device))
                optionValues: row.devices.map(device => device.name)
                optionIcons: row.devices.map(device => row.isInput ? "mic" : AudioService.sinkIcon(device))
                currentValue: row.node?.name ?? ""
                emptyText: row.isInput ? "No input device" : "No output device"
                onValueChanged: value => {
                    const device = row.devices.find(d => d.name === value);
                    if (device)
                        row.picked(device);
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
