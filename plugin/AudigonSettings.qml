pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.DCommon.Widgets
import "components"

PluginSettings {
    id: root

    pluginId: "audigon"

    // the daemon normalises what's saved, so its defaults show until something is
    readonly property var daemon: PluginService.pluginDaemonInstances[pluginId] ?? null
    readonly property int maxGroups: daemon?.maxGroups ?? 8
    readonly property var roleOptions: ["Game", "Communication", "Music", "Movie", "Notification", "Production", "Accessibility"]
    property var groups: []

    Component.onCompleted: reloadGroups()
    onDaemonChanged: reloadGroups()
    onPluginServiceChanged: reloadGroups()

    function reloadGroups() {
        groups = daemon ? daemon.normalise(loadValue("groups", null)) : [];
    }

    function saveGroups(list) {
        groups = list;
        saveValue("groups", list);
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
        if (groups.length >= maxGroups)
            return;
        saveGroups(groups.concat([
            {
                "name": `Group ${groups.length + 1}`,
                "icon": "graphic_eq",
                "apps": "",
                "appIds": "",
                "roles": [],
                "steam": false,
                "gamemode": false
            }
        ]));
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

    property var themeColorOptions: [
        {
            label: "Primary",
            value: "primary"
        },
        {
            label: "Primary Text",
            value: "primaryText"
        },
        {
            label: "Primary Container",
            value: "primaryContainer"
        },
        {
            label: "Secondary",
            value: "secondary"
        },
        {
            label: "Surface",
            value: "surface"
        },
        {
            label: "Surface Text",
            value: "surfaceText"
        },
        {
            label: "Surface Variant",
            value: "surfaceVariant"
        },
        {
            label: "Surface Variant Text",
            value: "surfaceVariantText"
        },
        {
            label: "Surface Tint",
            value: "surfaceTint"
        },
        {
            label: "Background",
            value: "background"
        },
        {
            label: "Background Text",
            value: "backgroundText"
        },
        {
            label: "Outline",
            value: "outline"
        },
        {
            label: "Surface Container",
            value: "surfaceContainer"
        },
        {
            label: "Surface Container High",
            value: "surfaceContainerHigh"
        },
        {
            label: "Surface Container Highest",
            value: "surfaceContainerHighest"
        },
        {
            label: "Error",
            value: "error"
        },
        {
            label: "Warning",
            value: "warning"
        },
        {
            label: "Info",
            value: "info"
        }
    ]

    StyledText {
        width: parent.width
        text: "Audigon"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Configure bar display and volume scroll behavior"
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
                text: "Widget Colors"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.surfaceText
                topPadding: Theme.spacingS
            }

            SelectionSetting {
                settingKey: "speakerIconColorKey"
                label: "Speaker Icon Color"
                description: "Theme color for the speaker icon"
                options: root.themeColorOptions
                defaultValue: "primary"
            }

            SelectionSetting {
                settingKey: "speakerTextColorKey"
                label: "Speaker Text Color"
                description: "Theme color for the speaker volume text"
                options: root.themeColorOptions
                defaultValue: "surfaceText"
            }

            SelectionSetting {
                settingKey: "micIconColorKey"
                label: "Mic Icon Color"
                description: "Theme color for the microphone icon"
                options: root.themeColorOptions
                defaultValue: "primary"
            }

            SelectionSetting {
                settingKey: "micTextColorKey"
                label: "Mic Text Color"
                description: "Theme color for the microphone volume text"
                options: root.themeColorOptions
                defaultValue: "surfaceText"
            }
        }
    }

    // ── Scroll Behavior ──
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
                text: "Scroll Behavior"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            Timer {
                id: speakerStepDebounce
                interval: 300
                repeat: false
                onTriggered: {
                    root.saveValue("volumeScrollStep", Math.round(speakerStepSlider.value));
                }
            }

            Column {
                width: parent.width
                spacing: 2

                Row {
                    width: parent.width
                    height: 24
                    spacing: Theme.spacingM

                    StyledText {
                        text: "Output Volume Scroll Step"
                        font.pixelSize: Theme.fontSizeSmall
                        width: 180
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    DSlider {
                        id: speakerStepSlider
                        width: parent.width - 180 - Theme.spacingM - speakerStepValue.width - Theme.spacingM
                        minimum: 1
                        maximum: 20
                        showValue: false
                        anchors.verticalCenter: parent.verticalCenter

                        Binding {
                            target: speakerStepSlider
                            property: "value"
                            value: root.loadValue("volumeScrollStep", 2)
                        }

                        onSliderValueChanged: newValue => {
                            speakerStepDebounce.restart();
                        }
                    }

                    StyledText {
                        id: speakerStepValue
                        text: Math.round(speakerStepSlider.value) + "%"
                        font.pixelSize: Theme.fontSizeSmall
                        width: 50
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                StyledText {
                    text: "How much the speaker volume changes per scroll tick"
                    font.pixelSize: Theme.fontSizeSmall * 0.9
                    opacity: 0.5
                    width: parent.width
                    wrapMode: Text.Wrap
                }
            }

            Timer {
                id: micStepDebounce
                interval: 300
                repeat: false
                onTriggered: {
                    root.saveValue("micVolumeScrollStep", Math.round(micStepSlider.value));
                }
            }

            Column {
                width: parent.width
                spacing: 2

                Row {
                    width: parent.width
                    height: 24
                    spacing: Theme.spacingM

                    StyledText {
                        text: "Input Volume Scroll Step"
                        font.pixelSize: Theme.fontSizeSmall
                        width: 180
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    DSlider {
                        id: micStepSlider
                        width: parent.width - 180 - Theme.spacingM - micStepValue.width - Theme.spacingM
                        minimum: 1
                        maximum: 20
                        showValue: false
                        anchors.verticalCenter: parent.verticalCenter

                        Binding {
                            target: micStepSlider
                            property: "value"
                            value: root.loadValue("micVolumeScrollStep", 2)
                        }

                        onSliderValueChanged: newValue => {
                            micStepDebounce.restart();
                        }
                    }

                    StyledText {
                        id: micStepValue
                        text: Math.round(micStepSlider.value) + "%"
                        font.pixelSize: Theme.fontSizeSmall
                        width: 50
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                StyledText {
                    text: "How much the microphone volume changes per scroll tick"
                    font.pixelSize: Theme.fontSizeSmall * 0.9
                    opacity: 0.5
                    width: parent.width
                    wrapMode: Text.Wrap
                }
            }

            Timer {
                id: maxVolumeDebounce
                interval: 300
                repeat: false
                onTriggered: {
                    root.saveValue("maxVolumePercent", Math.round(maxVolumeSlider.value));
                }
            }

            Column {
                width: parent.width
                spacing: 2

                Row {
                    width: parent.width
                    height: 24
                    spacing: Theme.spacingM

                    StyledText {
                        text: "Max Volume"
                        font.pixelSize: Theme.fontSizeSmall
                        width: 180
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    DSlider {
                        id: maxVolumeSlider
                        width: parent.width - 180 - Theme.spacingM - maxVolumeValue.width - Theme.spacingM
                        minimum: 100
                        maximum: 500
                        showValue: false
                        anchors.verticalCenter: parent.verticalCenter

                        Binding {
                            target: maxVolumeSlider
                            property: "value"
                            value: root.loadValue("maxVolumePercent", 100)
                        }

                        onSliderValueChanged: newValue => {
                            maxVolumeDebounce.restart();
                        }
                    }

                    StyledText {
                        id: maxVolumeValue
                        text: Math.round(maxVolumeSlider.value) + "%"
                        font.pixelSize: Theme.fontSizeSmall
                        width: 50
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                StyledText {
                    text: "Maximum allowed per-app volume (up to 500%)"
                    font.pixelSize: Theme.fontSizeSmall * 0.9
                    opacity: 0.5
                    width: parent.width
                    wrapMode: Text.Wrap
                }
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

            StyledText {
                width: parent.width
                text: "Each group is a vertex. A stream joins the first group it matches; a group with no rules takes the rest. Patterns are case-insensitive regexes."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: root.groups

                StyledRect {
                    id: groupCard

                    required property var modelData
                    required property int index

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
                                tone: groupCard.index
                                icon: groupCard.modelData.icon
                                name: groupCard.modelData.name || `Group ${groupCard.index + 1}`
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
                                text: groupCard.modelData.name
                                onEditingFinished: root.updateGroup(groupCard.index, "name", text)
                            }

                            DIconPicker {
                                id: iconPicker

                                currentIcon: groupCard.modelData.icon
                                onIconSelected: iconName => root.updateGroup(groupCard.index, "icon", iconName)
                            }
                        }

                        DTextField {
                            width: parent.width
                            placeholderText: "App names or binaries"
                            text: groupCard.modelData.apps
                            isError: !root.validPattern(text)
                            supportingText: isError ? "Not a valid regex" : ""
                            onEditingFinished: root.updateGroup(groupCard.index, "apps", text)
                        }

                        DTextField {
                            width: parent.width
                            placeholderText: "Window app ids"
                            text: groupCard.modelData.appIds
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
                            selectedValues: groupCard.modelData.roles
                            onSelectionToggled: (chip, selected) => {
                                const role = root.roleOptions[chip];
                                const roles = groupCard.modelData.roles.filter(r => r !== role);
                                if (selected)
                                    roles.push(role);
                                root.updateGroup(groupCard.index, "roles", roles);
                            }
                        }

                        DToggle {
                            width: parent.width
                            text: "Steam games"
                            description: "Anything Steam launched, native or Proton"
                            checked: groupCard.modelData.steam
                            onToggled: checked => root.updateGroup(groupCard.index, "steam", checked)
                        }

                        DToggle {
                            width: parent.width
                            text: "gamemode games"
                            description: "Processes registered with gamemoded"
                            checked: groupCard.modelData.gamemode
                            onToggled: checked => root.updateGroup(groupCard.index, "gamemode", checked)
                        }
                    }
                }
            }

            DButton {
                visible: root.maxGroups > 2
                enabled: root.groups.length < root.maxGroups
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
                text: "• Scroll on the widget to change volume (input / output)\n• Click the widget to open the audio panel\n• Pick devices and set their volumes under Input/Output\n• Set per-app volumes under Applications\n• Middle-click an app's volume slider to reset it to 100%\n• Drag the mixer's dot to balance its groups; scroll to nudge it, middle-click to recentre\n• Right-click a group in the mixer, or its badge on an app, to mute the whole group"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                width: parent.width
                lineHeight: 1.4
            }
        }
    }
}
