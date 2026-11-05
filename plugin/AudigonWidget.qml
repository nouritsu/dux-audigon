pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.DCommon.Widgets
import "components"

PluginComponent {
    id: root

    layerNamespacePlugin: "audigon"

    // settings, keyed like SimpleAudioControl's
    readonly property bool showSpeaker: pluginData.showSpeaker ?? true
    readonly property bool showSpeakerValue: pluginData.showSpeakerValue ?? true
    readonly property bool showMic: pluginData.showMic ?? false
    readonly property bool showMicValue: pluginData.showMicValue ?? false
    readonly property int volumeScrollStep: pluginData.volumeScrollStep || 2
    readonly property int micVolumeScrollStep: pluginData.micVolumeScrollStep || 2
    readonly property int maxVolumePercent: pluginData.maxVolumePercent || 100
    readonly property string speakerIconColorKey: pluginData.speakerIconColorKey || "primary"
    readonly property string speakerTextColorKey: pluginData.speakerTextColorKey || "surfaceText"
    readonly property string micIconColorKey: pluginData.micIconColorKey || "primary"
    readonly property string micTextColorKey: pluginData.micTextColorKey || "surfaceText"

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property int sinkVolume: sink?.audio ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool sinkMuted: sink?.audio ? sink.audio.muted : false
    readonly property int sourceVolume: source?.audio ? Math.round(source.audio.volume * 100) : 0
    readonly property bool sourceMuted: source?.audio ? source.audio.muted : false
    readonly property int sinkMaxVolume: Math.min(maxVolumePercent, AudioService.getMaxVolumePercent(sink))

    // devices as dux lists them, minus those hidden in its audio settings; the default always stays.
    // read off pipewire: AudioService.typedSinks only refreshes while something holds a ref on it,
    // so right after dux starts it can still be empty
    readonly property var sinks: {
        const hidden = SessionData.hiddenOutputDeviceNames ?? [];
        return Pipewire.nodes.values.filter(node => node.audio && node.isSink && (SettingsData.audioShowStreamDevices || !node.isStream) && (node === sink || !hidden.includes(node.name)));
    }
    readonly property var sources: {
        const hidden = SessionData.hiddenInputDeviceNames ?? [];
        return Pipewire.nodes.values.filter(node => node.audio && !node.isSink && (SettingsData.audioShowStreamDevices || !node.isStream) && (node === source || !hidden.includes(node.name)));
    }

    readonly property var streams: Pipewire.nodes.values.filter(node => node.audio && node.isStream && node.isSink)

    // meters only run with the full popout open
    readonly property bool metering: interactionActive && !micPopupMode

    // the mixer's groups, levels and dot live in the daemon, shared by every bar
    readonly property var daemon: PluginService.pluginDaemonInstances[pluginId] ?? null
    readonly property bool mixerShown: daemon?.active ?? false

    PwObjectTracker {
        objects: Pipewire.nodes.values.filter(node => node.audio)
    }

    function adjustSinkVolume(delta) {
        if (!sink?.audio)
            return;
        if (sink.audio.muted)
            sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(sinkMaxVolume, sinkVolume + delta)) / 100;
    }

    function adjustSourceVolume(delta) {
        if (!source?.audio)
            return;
        if (source.audio.muted)
            source.audio.muted = false;
        source.audio.volume = Math.max(0, Math.min(100, sourceVolume + delta)) / 100;
    }

    // an app's own level; with the mixer on, its real volume is this times its group's factor
    function streamLevel(node) {
        if (daemon)
            return daemon.levelOf(node);
        return node?.audio ? Math.round(node.audio.volume * 100) : 0;
    }

    function setStreamLevel(node, value) {
        const clamped = Math.max(0, Math.min(maxVolumePercent, value));
        if (daemon)
            daemon.setLevel(node, clamped);
        else if (node?.audio)
            node.audio.volume = clamped / 100;
    }

    // {tone, icon, name, factor, muted} for the app row's badge; null when ungrouped
    function streamGroup(node) {
        const index = daemon?.groupIndex(node) ?? -1;
        if (index < 0)
            return null;
        const group = daemon.groups[index];
        return {
            "index": index,
            "icon": group.icon,
            "name": group.name,
            "factor": daemon.groupFactors[index] ?? 1,
            "muted": daemon.muted[index] ?? false,
            "excluded": daemon.excluded[index] ?? false,
            "style": daemon.styles[index] ?? ({})
        };
    }

    // back to 100%
    function resetStreamVolume(node) {
        if (!node?.audio)
            return;
        if (node.audio.muted)
            node.audio.muted = false;
        setStreamLevel(node, 100);
    }

    function iconCandidates(node) {
        if (!node)
            return [];
        const props = node.properties || {};
        const raw = [props["application.icon-name"], props["application.icon_name"], props["application.id"], props["application.name"], props["application.process.binary"], props["binary"], props["media.name"], node.name];
        const candidates = [];
        const seen = {};
        for (const value of raw) {
            if (!value)
                continue;
            const trimmed = String(value).trim();
            if (!trimmed)
                continue;
            const base = trimmed.split("/").pop();
            const variants = [trimmed, trimmed.replace(/\.desktop$/i, ""), trimmed.replace(/\.bin$/i, ""), trimmed.replace(/-bin$/i, ""), trimmed.replace(/\.[^/.]+$/, ""), base];
            for (const variant of variants) {
                for (const candidate of [variant, variant?.toLowerCase()]) {
                    if (!candidate || seen[candidate])
                        continue;
                    seen[candidate] = true;
                    candidates.push(candidate);
                }
            }
        }
        return candidates;
    }

    function streamIconSource(node) {
        for (const candidate of iconCandidates(node)) {
            const resolved = Paths.resolveIconPath(candidate);
            if (resolved)
                return resolved;
        }
        return "";
    }

    function streamFallbackIcon(node) {
        const name = (node?.properties?.["application.name"] || node?.name || "").toLowerCase();
        if (["firefox", "chrome", "vivaldi"].some(browser => name.includes(browser)))
            return "public";
        if (name.includes("spotify"))
            return "music_note";
        if (name.includes("mpv") || name.includes("vlc"))
            return "movie";
        if (name.includes("discord") || name.includes("telegram"))
            return "chat";
        if (name.includes("steam"))
            return "sports_esports";
        if (name.includes("obs"))
            return "videocam";
        return "graphic_eq";
    }

    function streamName(node) {
        return node?.properties?.["application.name"] || AudioService.displayName(node);
    }

    function themeColorFromKey(key, fallback) {
        switch (key) {
        case "primary":
            return Theme.primary;
        case "primaryText":
            return Theme.primaryText;
        case "primaryContainer":
            return Theme.primaryContainer;
        case "secondary":
            return Theme.secondary;
        case "surface":
            return Theme.surface;
        case "surfaceText":
            return Theme.surfaceText;
        case "surfaceVariant":
            return Theme.surfaceVariant;
        case "surfaceVariantText":
            return Theme.surfaceVariantText;
        case "surfaceTint":
            return Theme.surfaceTint;
        case "background":
            return Theme.background;
        case "backgroundText":
            return Theme.backgroundText;
        case "outline":
            return Theme.outline;
        case "surfaceContainer":
            return Theme.surfaceContainer;
        case "surfaceContainerHigh":
            return Theme.surfaceContainerHigh;
        case "surfaceContainerHighest":
            return Theme.surfaceContainerHighest;
        case "error":
            return Theme.error;
        case "warning":
            return Theme.warning;
        case "info":
            return Theme.info;
        default:
            return fallback;
        }
    }

    // scrolling over the pill's mic opens a small mic level popout for a moment
    property bool micPopupMode: false
    property bool _micOpening: false

    // the unfolded device list, "output", "input" or none; one at a time
    property string openPicker: ""

    function togglePicker(which) {
        openPicker = openPicker === which ? "" : which;
    }

    // pinned from the header: clicks elsewhere don't close it and other windows keep the keyboard
    property bool pinned: false

    // a click opens the full popout; the mic popout keeps its size while it closes.
    // dux keeps the content loaded, so the device lists fold and the pin drops here rather than on destruction
    onInteractionActiveChanged: {
        if (interactionActive && !_micOpening)
            micPopupMode = false;
        if (!interactionActive) {
            openPicker = "";
            pinned = false;
        }
        _micOpening = false;
    }

    Timer {
        id: micPopoutTimer

        interval: 1500
        onTriggered: root.closePopout()
    }

    function triggerMicPopout() {
        if (interactionActive && !micPopupMode)
            return;
        micPopupMode = true;
        micPopoutTimer.restart();
        if (!interactionActive) {
            _micOpening = true;
            triggerPopout();
        }
    }

    function wheelOver(onMicSide, up) {
        if (onMicSide) {
            adjustSourceVolume(up ? micVolumeScrollStep : -micVolumeScrollStep);
            triggerMicPopout();
        } else if (showSpeaker) {
            adjustSinkVolume(up ? volumeScrollStep : -volumeScrollStep);
        }
    }

    horizontalBarPill: Component {
        Pill {
            widget: root
        }
    }

    verticalBarPill: Component {
        Pill {
            widget: root
            vertical: true
        }
    }

    popoutWidth: micPopupMode ? 160 : 420

    popoutContent: Component {
        PopoutComponent {
            id: popout

            headerText: root.micPopupMode ? "" : "Audio"
            headerActions: Component {
                DActionButton {
                    buttonSize: Theme.buttonHeightXS
                    iconName: "push_pin"
                    iconSize: Theme.iconSizeMedium
                    iconFilled: root.pinned
                    iconColor: root.pinned ? Theme.primary : Theme.surfaceVariantText
                    tooltipText: root.pinned ? "Unpin" : "Keep open"
                    onClicked: root.pinned = !root.pinned
                }
            }

            // pinned: the popout ignores clicks outside it and only takes the keyboard when clicked
            Binding {
                target: popout.parentPopout
                property: "backgroundInteractive"
                value: !root.pinned
                when: popout.parentPopout !== null
            }

            Binding {
                target: popout.parentPopout
                property: "customKeyboardFocus"
                value: root.pinned ? WlrKeyboardFocus.OnDemand : null
                when: popout.parentPopout !== null
            }

            Binding {
                target: popout.parentPopout
                property: "hoverDismissSuspended"
                value: root.pinned
                when: popout.parentPopout !== null
            }

            // the group and shape menus; a popup in this window, not one of its own
            ContextMenu {
                id: popoutMenu
            }

            Item {
                width: parent.width
                height: micCol.implicitHeight + Theme.spacingL * 2
                visible: root.micPopupMode

                StyledRect {
                    anchors.centerIn: parent
                    width: Math.max(140, micCol.implicitWidth + Theme.spacingL * 2)
                    height: parent.height
                    radius: Theme.cornerRadiusM
                    color: Theme.surfaceContainerHigh

                    Column {
                        id: micCol

                        anchors.centerIn: parent
                        spacing: Theme.spacingS

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Microphone"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.sourceVolume + "%"
                            font.pixelSize: 24
                            font.weight: Font.Bold
                            color: Theme.primary
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.groupedListGap
                visible: !root.micPopupMode

                SectionLabel {
                    text: "Input/Output"
                }

                DeviceRow {
                    node: root.sink
                    devices: root.sinks
                    maxVolume: root.sinkMaxVolume
                    metering: root.metering
                    expanded: root.openPicker === "output"
                    firstInGroup: true
                    lastInGroup: false
                    onToggled: root.togglePicker("output")
                    onPicked: device => {
                        AudioService.setSink(device);
                        root.openPicker = "";
                    }
                }

                DeviceRow {
                    node: root.source
                    devices: root.sources
                    isInput: true
                    metering: root.metering
                    expanded: root.openPicker === "input"
                    firstInGroup: false
                    lastInGroup: true
                    onToggled: root.togglePicker("input")
                    onPicked: device => {
                        AudioService.setSource(device);
                        root.openPicker = "";
                    }
                }

                MixerSection {
                    id: mixerSection

                    width: parent.width
                    visible: root.mixerShown
                    daemon: root.daemon
                    menu: popoutMenu
                    live: root.interactionActive
                }

                SectionLabel {
                    text: "Applications"
                }

                DFlickable {
                    id: appScroll

                    width: parent.width
                    height: Math.min(appList.implicitHeight, 300)
                    contentHeight: appList.implicitHeight
                    interactive: contentHeight > height
                    clip: true
                    visible: root.streams.length > 0

                    Column {
                        id: appList

                        width: appScroll.width
                        spacing: Theme.groupedListGap

                        // diffed, so rows and their meters survive node churn, like the meters' own capture streams
                        Repeater {
                            model: ScriptModel {
                                values: root.streams
                            }

                            AppRow {
                                required property var modelData
                                required property int index

                                width: appList.width
                                firstInGroup: index === 0
                                lastInGroup: index === root.streams.length - 1
                                node: modelData
                                name: root.streamName(modelData)
                                iconSource: root.streamIconSource(modelData)
                                fallbackIcon: root.streamFallbackIcon(modelData)
                                level: root.streamLevel(modelData)
                                maxVolume: root.maxVolumePercent
                                metering: root.metering
                                group: root.streamGroup(modelData)
                                onLevelSet: value => root.setStreamLevel(modelData, value)
                                onGroupMenuRequested: (item, x, y) => popoutMenu.openAt(item, x, y, mixerSection.groupMenu(root.daemon.groupIndex(modelData)))
                                onResetRequested: root.resetStreamVolume(modelData)
                                onMuteToggled: modelData.audio.muted = !modelData.audio.muted
                            }
                        }
                    }
                }

                StyledText {
                    width: parent.width
                    topPadding: Theme.spacingS
                    text: "No applications are playing audio"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    horizontalAlignment: Text.AlignHCenter
                    visible: root.streams.length === 0
                }
            }
        }
    }
}
