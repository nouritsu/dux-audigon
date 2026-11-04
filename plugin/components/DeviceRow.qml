pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets

// the default output or input: device picker, then mute and volume
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
        anchors.leftMargin: Theme.spacingS
        anchors.rightMargin: Theme.spacingS
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingXS

        Item {
            id: header

            width: parent.width
            height: picker.height

            DDropdown {
                id: picker

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                dropdownWidth: header.width - meter.width - Theme.spacingS * 2
                compactMode: true
                transientSurfaceTracker: row.transientSurfaceTracker
                options: row.devices.map(device => AudioService.displayName(device))
                optionValues: row.devices.map(device => device.name)
                optionIcons: row.devices.map(device => row.isInput ? "mic" : AudioService.sinkIcon(device))
                currentValue: row.node?.name ?? ""
                emptyText: row.isInput ? "No input devices" : "No output devices"
                onValueChanged: value => {
                    const device = row.devices.find(d => d.name === value);
                    if (device)
                        row.picked(device);
                }
            }

            LevelMeter {
                id: meter

                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingXS
                anchors.verticalCenter: parent.verticalCenter
                node: row.node
                active: row.metering
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
