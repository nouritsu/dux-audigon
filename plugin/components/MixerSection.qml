pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.DCommon.Widgets

// the popout's mixer: its heading with the stash of excluded groups beside it, and the pad. A group
// excluded from the pad flies into the stash crossed out; clicking it there brings it back
Column {
    id: section

    // the plugin's daemon, and the popout's menu
    required property var daemon
    required property var menu

    readonly property bool bypassed: daemon?.bypassed ?? false

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

    // a stash icon's middle, in the pad's coordinates
    function stashPoint(name) {
        const item = stashIcons.itemAt((daemon?.stash ?? []).findIndex(group => group.name === name));
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
                    values: section.daemon?.stash ?? []
                }

                // small and crossed out; it pops in once its marker has landed
                Item {
                    id: stashed

                    required property var modelData
                    readonly property color tint: section.daemon?.styles[modelData.index]?.content ?? Theme.surfaceVariantText

                    width: Theme.iconSizeSmall + Theme.spacingXS
                    height: width
                    opacity: pad.inFlight(modelData.name) ? 0 : 0.7

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.shorterDuration
                        }
                    }

                    DIcon {
                        anchors.centerIn: parent
                        name: stashed.modelData.icon
                        size: Theme.iconSizeSmall
                        color: stashed.tint
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 1.5
                        height: Theme.iconSizeSmall + 2
                        radius: width / 2
                        rotation: 45
                        color: stashed.tint
                    }

                    StateLayer {
                        cornerRadius: Theme.cornerRadiusFull
                        tooltipText: `Bring back ${stashed.modelData.name}`
                        tooltipSide: "top"
                        onClicked: {
                            pad.launch(stashed.modelData.name, stashed.mapToItem(pad, stashed.width / 2, stashed.height / 2));
                            section.daemon.setExcluded(stashed.modelData.index, false);
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
                dot: section.daemon?.effectiveDot ?? ({
                        "x": 0.5,
                        "y": 0.5
                    })
                stashNames: (section.daemon?.stash ?? []).map(group => group.name)
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
