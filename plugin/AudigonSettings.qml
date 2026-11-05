pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.DCommon.Widgets
import "components"
import "lib/colors.js" as Colors
import "lib/groups.js" as Groups

PluginSettings {
    id: root

    pluginId: "audigon"

    // for the groups' colours
    readonly property var daemon: PluginService.pluginDaemonInstances[pluginId] ?? null
    readonly property var roleOptions: ["Game", "Communication", "Music", "Movie", "Notification", "Production", "Accessibility"]
    // as the daemon reads them, defaults until something is saved
    property var groups: []

    Component.onCompleted: reloadGroups()
    onPluginServiceChanged: reloadGroups()

    function reloadGroups() {
        groups = Groups.normalise(loadValue("groups", null));
    }

    function saveGroups(list) {
        groups = Groups.normalise(list);
        saveValue("groups", groups);
    }

    function updateGroup(index, field, value) {
        if (JSON.stringify(groups[index]?.[field]) === JSON.stringify(value))
            return;
        const next = groups.map(group => Object.assign({}, group));
        next[index][field] = value;
        saveGroups(next);
    }

    function moveGroup(index, by) {
        const to = index + by;
        if (to < 0 || to >= groups.length)
            return;
        const next = groups.slice();
        const moved = next.splice(index, 1)[0];
        next.splice(to, 0, moved);
        saveGroups(next);
    }

    function removeGroup(index) {
        if (groups.length > 2)
            saveGroups(groups.filter((_, i) => i !== index));
    }

    function addGroup() {
        if (groups.length < Groups.maxGroups())
            saveGroups(groups.concat({}));
    }

    function validPattern(pattern) {
        if (!pattern)
            return true;
        try {
            new RegExp(pattern);
            return true;
        } catch (e) {
            return false;
        }
    }

    property var themeColorOptions: Colors.keys().map(key => ({
                "label": Colors.label(key),
                "value": key
            }))

    StyledText {
        width: parent.width
        text: "Audigon"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Bar display, scrolling and the mixer"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    // ── Bar Display ──
    StyledRect {
        width: parent.width
        height: barDisplayColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: barDisplayColumn

            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Bar Display"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            ToggleSetting {
                settingKey: "showSpeaker"
                label: "Show Speaker"
                description: "Display speaker icon in the bar"
                defaultValue: true
            }

            ToggleSetting {
                settingKey: "showSpeakerValue"
                label: "Show Speaker Volume"
                description: "Display numeric volume percentage next to speaker icon"
                defaultValue: true
            }

            ToggleSetting {
                settingKey: "showMic"
                label: "Show Microphone"
                description: "Display microphone icon in the bar"
                defaultValue: false
            }

            ToggleSetting {
                settingKey: "showMicValue"
                label: "Show Microphone Volume"
                description: "Display numeric input level next to microphone icon"
                defaultValue: false
            }

            StyledText {
                text: "Widget Colours"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.surfaceText
                topPadding: Theme.spacingS
            }

            SelectionSetting {
                settingKey: "speakerIconColorKey"
                label: "Speaker Icon Colour"
                description: "Theme colour for the speaker icon"
                options: root.themeColorOptions
                defaultValue: "primary"
            }

            SelectionSetting {
                settingKey: "speakerTextColorKey"
                label: "Speaker Text Colour"
                description: "Theme colour for the speaker volume text"
                options: root.themeColorOptions
                defaultValue: "surfaceText"
            }

            SelectionSetting {
                settingKey: "micIconColorKey"
                label: "Mic Icon Colour"
                description: "Theme colour for the microphone icon"
                options: root.themeColorOptions
                defaultValue: "primary"
            }

            SelectionSetting {
                settingKey: "micTextColorKey"
                label: "Mic Text Colour"
                description: "Theme colour for the microphone volume text"
                options: root.themeColorOptions
                defaultValue: "surfaceText"
            }
        }
    }

    // ── Scroll Behaviour ──
    StyledRect {
        width: parent.width
        height: scrollColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: scrollColumn

            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Scroll Behaviour"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            SliderSetting {
                settingKey: "volumeScrollStep"
                label: "Output Volume Scroll Step"
                description: "How much the speaker volume changes per scroll tick"
                minimum: 1
                maximum: 20
                defaultValue: 2
                unit: "%"
            }

            SliderSetting {
                settingKey: "micVolumeScrollStep"
                label: "Input Volume Scroll Step"
                description: "How much the microphone volume changes per scroll tick"
                minimum: 1
                maximum: 20
                defaultValue: 2
                unit: "%"
            }

            SliderSetting {
                settingKey: "maxVolumePercent"
                label: "Max Volume"
                description: "The highest volume for apps and the output device, up to 500%"
                minimum: 100
                maximum: 500
                defaultValue: 100
                unit: "%"
            }
        }
    }

    // ── Mixer ──
    StyledRect {
        width: parent.width
        height: mixerColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: mixerColumn

            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Mixer"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            ToggleSetting {
                settingKey: "mixerEnabled"
                label: "Mixer"
                description: "A dot in the popout scales each group of apps; every app keeps its own level"
                defaultValue: true
            }

            SliderSetting {
                settingKey: "mixerRange"
                label: "Fade depth"
                description: "How far a group fades, evenly, as the dot moves away from it, before it goes silent at the far vertex"
                minimum: 20
                maximum: 60
                defaultValue: 40
                unit: " dB"
            }

            StyledText {
                width: parent.width
                text: "Each group is a vertex. A stream joins the first group it matches; a group with no rules takes the rest. Patterns are case-insensitive regexes."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }

            // by count, so an edit updates the cards in place instead of rebuilding them, which
            // would drop the focus from the next field
            Repeater {
                model: root.groups.length

                StyledRect {
                    id: groupCard

                    required property int index
                    // clamped, as a removed card can update once more before it goes
                    readonly property var group: root.groups[Math.min(index, root.groups.length - 1)]
                    readonly property var style: root.daemon?.styleFor(group.color, index) ?? ({})

                    width: mixerColumn.width
                    height: groupColumn.implicitHeight + Theme.spacingM * 2
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHighest

                    Column {
                        id: groupColumn

                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        Item {
                            width: parent.width
                            height: Theme.buttonHeightXS

                            GroupBadge {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                style: groupCard.style
                                icon: groupCard.group.icon
                                name: groupCard.group.name
                                showFactor: false
                            }

                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter

                                DActionButton {
                                    buttonSize: Theme.buttonHeightXS
                                    iconName: "arrow_upward"
                                    iconSize: Theme.iconSizeMedium
                                    enabled: groupCard.index > 0
                                    tooltipText: "Move up"
                                    onClicked: root.moveGroup(groupCard.index, -1)
                                }

                                DActionButton {
                                    buttonSize: Theme.buttonHeightXS
                                    iconName: "arrow_downward"
                                    iconSize: Theme.iconSizeMedium
                                    enabled: groupCard.index < root.groups.length - 1
                                    tooltipText: "Move down"
                                    onClicked: root.moveGroup(groupCard.index, 1)
                                }

                                DActionButton {
                                    buttonSize: Theme.buttonHeightXS
                                    iconName: "delete"
                                    iconSize: Theme.iconSizeMedium
                                    enabled: root.groups.length > 2
                                    tooltipText: "Remove"
                                    onClicked: root.removeGroup(groupCard.index)
                                }
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.spacingS

                            DTextField {
                                width: parent.width - iconPicker.width - parent.spacing
                                placeholderText: "Name"
                                text: groupCard.group.name
                                onEditingFinished: root.updateGroup(groupCard.index, "name", text)
                            }

                            DIconPicker {
                                id: iconPicker

                                currentIcon: groupCard.group.icon
                                onIconSelected: iconName => root.updateGroup(groupCard.index, "icon", iconName)
                            }
                        }

                        DTextField {
                            width: parent.width
                            placeholderText: "App names or binaries"
                            text: groupCard.group.apps
                            isError: !root.validPattern(text)
                            supportingText: isError ? "Not a valid regex" : ""
                            onEditingFinished: root.updateGroup(groupCard.index, "apps", text)
                        }

                        DTextField {
                            width: parent.width
                            placeholderText: "Window app ids"
                            text: groupCard.group.appIds
                            isError: !root.validPattern(text)
                            supportingText: isError ? "Not a valid regex" : ""
                            onEditingFinished: root.updateGroup(groupCard.index, "appIds", text)
                        }

                        StyledText {
                            text: "Media roles"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        DFilterChips {
                            width: parent.width
                            model: root.roleOptions
                            multiSelect: true
                            showCounts: false
                            selectedValues: groupCard.group.roles
                            onSelectionToggled: (chip, selected) => {
                                const role = root.roleOptions[chip];
                                const roles = groupCard.group.roles.filter(r => r !== role);
                                if (selected)
                                    roles.push(role);
                                root.updateGroup(groupCard.index, "roles", roles);
                            }
                        }

                        DToggle {
                            width: parent.width
                            text: "Steam games"
                            description: "Anything Steam launched, native or Proton"
                            checked: groupCard.group.steam
                            onToggled: checked => root.updateGroup(groupCard.index, "steam", checked)
                        }

                        DToggle {
                            width: parent.width
                            text: "gamemode games"
                            description: "Processes registered with gamemoded"
                            checked: groupCard.group.gamemode
                            onToggled: checked => root.updateGroup(groupCard.index, "gamemode", checked)
                        }

                        DToggle {
                            width: parent.width
                            text: "Playing media"
                            description: "Apps with a media player open, playing or paused, like a browser with a video"
                            checked: groupCard.group.mpris
                            onToggled: checked => root.updateGroup(groupCard.index, "mpris", checked)
                        }

                        // the theme's tone for its place, or a colour of its own
                        Item {

                            width: parent.width
                            height: Theme.buttonHeightXS

                            StyledText {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: groupCard.group.color ? "Colour" : "Colour: theme"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }

                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingXS

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Theme.iconSizeMedium
                                    height: width
                                    radius: width / 2
                                    color: groupCard.style.accent ?? Theme.primary
                                    border.width: 1
                                    border.color: Theme.outlineVariant
                                }

                                DActionButton {
                                    buttonSize: Theme.buttonHeightXS
                                    iconName: "palette"
                                    iconSize: Theme.iconSizeMedium
                                    tooltipText: "Pick a colour"
                                    onClicked: {
                                        const picker = PopoutService.colorPickerModal;
                                        if (!picker)
                                            return;
                                        picker.selectedColor = groupCard.style.accent ?? Theme.primary;
                                        picker.pickerTitle = `${groupCard.group.name} colour`;
                                        picker.onColorSelectedCallback = picked => root.updateGroup(groupCard.index, "color", picked.toString());
                                        picker.show();
                                    }
                                }

                                DActionButton {
                                    buttonSize: Theme.buttonHeightXS
                                    iconName: "format_color_reset"
                                    iconSize: Theme.iconSizeMedium
                                    tooltipText: "Theme colour"
                                    visible: groupCard.group.color !== ""
                                    onClicked: root.updateGroup(groupCard.index, "color", "")
                                }
                            }
                        }
                    }
                }
            }

            DButton {
                enabled: root.groups.length < Groups.maxGroups()
                text: "Add group"
                iconName: "add"
                onClicked: root.addGroup()
            }
        }
    }

    // ── Info ──
    StyledRect {
        width: parent.width
        height: infoColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surface

        Column {
            id: infoColumn

            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            Row {
                spacing: Theme.spacingM

                DIcon {
                    name: "info"
                    size: Theme.iconSize
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "Usage"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            StyledText {
                text: "• Scroll on the widget to change volume (input / output)\n• Click the widget to open the audio panel; the pin in its header keeps it open while you click elsewhere\n• Pick devices and set their volumes under Input/Output\n• Set per-app volumes under Applications\n• Middle-click an app's volume slider to reset it to 100%\n• Drag the mixer's dot to balance its groups; scroll to nudge it, double- or middle-click to recentre\n• Right-click a group in the mixer, or its badge on an app, to mute or exclude it; a muted group's side closes off, an excluded one waits greyed in the stash until clicked\n• Right-click the mixer's shape to switch it off; left-click turns it back on\n• Groups with nothing playing wait in the stash beside \"Mixer\" in their colours, and fly onto the shape as they start"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                width: parent.width
                lineHeight: 1.4
            }
        }
    }
}
