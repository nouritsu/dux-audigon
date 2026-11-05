pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.DCommon.Widgets

// the popout's mixer: its heading with the stash beside it, and the pad. Every group off the shape
// sits in the stash, idle ones in their colours and excluded ones greyed; a group flies out of the
// stash onto the shape when it starts playing and back in when it stops or is excluded
Column {
    id: section

    // the plugin's daemon, and the popout's menu
    required property var daemon
    required property var menu

    readonly property bool bypassed: daemon?.bypassed ?? false
    // the popout is open
    property bool live: true

    function groupMenu(index) {
        const muted = daemon.muted[index] ?? false;
        const excluded = daemon.excluded[index] ?? false;
        return [
            {
                "icon": muted ? "volume_up" : "volume_off",
                "text": muted ? "Unmute" : "Mute",
                "action": () => section.daemon.toggleGroupMute(index)
            },
            {
                "icon": excluded ? "add_circle" : "do_not_disturb_on",
                "text": excluded ? "Include" : "Exclude",
                "action": () => section.daemon.setExcluded(index, !excluded)
            }
        ];
    }

    function shapeMenu() {
        return [
            {
                "icon": "power_settings_new",
                "text": section.bypassed ? "Enable" : "Disable",
                "action": () => section.daemon.toggleBypass()
            }
        ];
    }

    // a stash icon's middle, in the pad's coordinates; every group has one, collapsed while it's on the shape
    function stashPoint(name) {
        const item = stashIcons.itemAt((daemon?.groups ?? []).findIndex(group => group.name === name));
        return item ? item.mapToItem(pad, item.width / 2, item.height / 2) : null;
    }

    width: parent?.width ?? 0
    spacing: Theme.groupedListGap

    Item {
        width: parent.width
        height: heading.implicitHeight

        SectionLabel {
            id: heading

            width: implicitWidth
            text: section.bypassed ? "Mixer · off" : "Mixer"
        }

        Row {
            anchors.left: heading.right
            anchors.leftMargin: Theme.spacingXS
            anchors.verticalCenter: heading.verticalCenter
            anchors.verticalCenterOffset: (heading.topPadding - heading.bottomPadding) / 2
            spacing: Theme.spacingXXS

            Repeater {
                id: stashIcons

                model: ScriptModel {
                    values: (section.daemon?.groups ?? []).map(group => group.name)
                }

                // a small marker in its colours, greyed while excluded, a muted icon while muted; it
                // collapses while its group is on the shape and shows again once its marker has landed
                Item {
                    id: stashed

                    required property string modelData
                    readonly property int index: (section.daemon?.groups ?? []).findIndex(group => group.name === modelData)
                    readonly property var group: section.daemon?.groups[index] ?? ({})
                    readonly property var style: section.daemon?.styles[index] ?? ({})
                    readonly property bool onShape: (section.daemon?.mixNames ?? []).includes(modelData)
                    readonly property bool excluded: section.daemon?.excluded[index] ?? false
                    readonly property bool muted: section.daemon?.muted[index] ?? false
                    readonly property real size: pad.stashSize

                    width: onShape ? 0 : size
                    // a collapsed one leaves no gap in the row
                    visible: width > 0.5
                    height: size
                    opacity: onShape || pad.inFlight(modelData) ? 0 : 1

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.mediumDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.shorterDuration
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: stashed.size
                        height: width
                        radius: width / 2
                        scale: stashed.width / stashed.size
                        color: stashed.excluded ? Theme.surfaceContainerHighest : stashed.style.container ?? Theme.primaryContainer

                        DIcon {
                            anchors.centerIn: parent
                            name: stashed.muted && !stashed.excluded ? "volume_off" : stashed.group.icon ?? ""
                            size: Theme.iconSizeSmall - Theme.spacingXXS
                            color: stashed.excluded ? Theme.onSurface_38 : stashed.style.content ?? Theme.onPrimaryContainer
                        }
                    }

                    // left brings an excluded one back, right opens its menu
                    StateLayer {
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cornerRadius: Theme.cornerRadiusFull
                        tooltipText: stashed.excluded ? `Bring back ${stashed.modelData}` : `${stashed.modelData}: nothing playing`
                        tooltipSide: "top"
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton)
                                section.menu.openAt(stashed, mouse.x, mouse.y, section.groupMenu(stashed.index));
                            else if (stashed.excluded)
                                section.daemon.setExcluded(stashed.index, false);
                        }
                    }
                }
            }
        }
    }

    DListRow {
        width: parent.width
        implicitHeight: body.implicitHeight + Theme.spacingS * 2

        Column {
            id: body

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.spacingS
            anchors.rightMargin: Theme.spacingS
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingS

            MixerPad {
                id: pad

                width: parent.width
                groups: section.daemon?.mixGroups ?? []
                factors: section.daemon?.mixEffective ?? []
                muted: section.daemon?.mixMuted ?? []
                bypassed: section.bypassed
                live: section.live
                dot: section.daemon?.effectiveDot ?? ({
                        "x": 0.5,
                        "y": 0.5
                    })
                stashPoint: name => section.stashPoint(name)
                onMoved: point => section.daemon?.setDot(point)
                onNudged: towardsVertex => section.daemon?.nudgeDot(towardsVertex)
                onRecentred: section.daemon?.recentre()
                onEnableRequested: section.daemon?.toggleBypass()
                onGroupMenuRequested: (index, x, y) => section.menu.openAt(pad, x, y, section.groupMenu(index))
                onShapeMenuRequested: (x, y) => section.menu.openAt(pad, x, y, section.shapeMenu())
            }
        }
    }
}
