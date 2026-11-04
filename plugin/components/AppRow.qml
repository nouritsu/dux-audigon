pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.Common
import qs.DCommon.Widgets

// one playback stream: icon, name, meter and group badge, then volume; middle-click the slider for 100%
DListRow {
    id: row

    property var node: null
    property string name: ""
    property string iconSource: ""
    property string fallbackIcon: "graphic_eq"
    property int level: 0
    property int maxVolume: 100
    property bool metering: false
    // its mixer group, {tone, icon, name, factor, muted}; null when ungrouped
    property var group: null
    readonly property bool muted: node?.audio?.muted ?? false

    signal levelSet(int value)
    signal resetRequested
    signal muteToggled
    signal groupMuteToggled

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
                width: Math.min(implicitWidth, header.width - icon.width - meter.width - Theme.spacingS * 2 - (badge.visible ? badge.width + Theme.spacingS : 0))
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

            GroupBadge {
                id: badge

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: row.group !== null
                tone: row.group?.tone ?? 0
                icon: row.group?.icon ?? ""
                name: row.group?.name ?? ""
                factor: row.group?.factor ?? 1
                muted: row.group?.muted ?? false
                muteable: true
                onMuteToggled: row.groupMuteToggled()
            }
        }

        Item {
            width: parent.width
            height: Math.max(slider.height, Theme.buttonHeightXS)

            Row {
                id: controls

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

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

                // middle only; left drags still reach the slider
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.MiddleButton
                    onClicked: row.resetRequested()
                }
            }
        }
    }
}
