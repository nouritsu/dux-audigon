pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import qs.Common
import qs.Modules.Plugins
import qs.Services
import "lib/groups.js" as Groups
import "lib/mixer.js" as Mixer

// the mixer: sorts playback streams into groups and scales each by its group's factor; an app's own
// level stays its slider, the stream's real volume is that times the factor. The shape only holds
// groups that have something playing and aren't excluded, and reshapes as they come and go
PluginComponent {
    id: root

    readonly property bool mixerEnabled: pluginData.mixerEnabled ?? true
    readonly property var groups: Groups.normalise(pluginData.groups)
    readonly property bool active: mixerEnabled && groups.length >= 2
    readonly property real maxLevel: Math.max(1, (pluginData.maxVolumePercent || 100) / 100)

    // switched off from the popout, kept in plugin state: every app at its own level, mutes included,
    // while the groups and the dot stay as they were
    property bool bypassed: false
    readonly property bool engaged: active && !bypassed

    // names, kept in plugin state. A muted group's factor is 0, so its apps keep their own levels and
    // the stream mute stays the app's; an excluded one leaves the shape and its apps play at their own
    property var mutedGroups: []
    property var excludedGroups: []
    readonly property var muted: groups.map(group => active && mutedGroups.includes(group.name))
    readonly property var excluded: groups.map(group => excludedGroups.includes(group.name))

    // groups with a stream for a moment, so a short ding doesn't reshape the mixer; they leave a few
    // seconds after their last stream
    property var presentNames: []
    property var _since: ({})
    property var _gone: ({})
    readonly property int joinMs: 1500
    readonly property int leaveMs: 5000

    // the shape: present groups that aren't excluded, in config order; set by relayout()
    property var mixNames: []
    readonly property var mixIndices: mixNames.map(name => groups.findIndex(group => group.name === name)).filter(index => index >= 0)
    readonly property var mixGroups: mixIndices.map(index => Object.assign({
            "index": index,
            "style": styles[index]
        }, groups[index]))
    readonly property var vertices: Mixer.vertices(mixIndices.length)
    readonly property var mixMuted: mixIndices.map(index => muted[index])

    // normalised, kept in plugin state; muted groups' sectors are off limits, so the dot in use is
    // held at the nearest open place and goes back once they're unmuted
    property var dot: Mixer.centre()
    readonly property var effectiveDot: Mixer.clampTo(vertices, mixMuted, dot)
    // per vertex: where the dot puts it, then as heard after the fade curve and mutes
    readonly property var mixFactors: engaged ? Mixer.factors(vertices, effectiveDot) : mixIndices.map(() => 1)
    readonly property var mixEffective: mixFactors.map((factor, i) => engaged && mixMuted[i] ? 0 : heard(factor))

    // how deep the fade goes before the cut at a vertex
    readonly property real rangeDb: Math.max(20, Math.min(60, pluginData.mixerRange || 40))

    // group name -> its factor when it last was on the shape, kept in plugin state; a group coming
    // back is fitted to it, as are the ones that stay
    property var lastFactors: ({})
    property bool _relayouting: false

    // per group: the factor its streams get. Off the shape but playing (still joining, or excluded):
    // its last factor, or its own level when excluded
    readonly property var groupFactors: groups.map((group, index) => {
        if (!engaged || excluded[index])
            return 1;
        if (muted[index])
            return 0;
        const at = mixIndices.indexOf(index);
        return heard(at >= 0 ? mixFactors[at] : lastFactors[group.name] ?? 1);
    })

    // per group: {accent, container, content}; theme tones by position unless a colour is set
    readonly property var styles: groups.map((group, index) => styleFor(group.color, index))

    // app key -> its own level, before the factor; kept in plugin state
    property var bases: ({})

    // stream pid -> {steam, chain: [pid, parent, ...]}; null once the lookup failed
    property var procs: ({})
    property var _resolving: ({})
    // pids gamemoded has registered
    property var gamePids: []

    // players with something loaded, playing or paused, and the pids that own them: media apps, and a
    // browser with a video open
    readonly property bool wantsMedia: active && groups.some(group => group.mpris)
    readonly property var mediaPlayers: wantsMedia ? Mpris.players.values.filter(player => player.playbackState !== MprisPlaybackState.Stopped).map(player => player.dbusName) : []
    property var _playerPids: ({})
    readonly property var mediaPids: mediaPlayers.map(name => _playerPids[name] ?? 0).filter(pid => pid > 0)

    // node id -> {value, at}: the volume we last wrote and when
    property var _written: ({})
    // our own writes echo back a moment later; changes inside this window aren't someone else's
    readonly property int settleMs: 500

    readonly property var streams: Pipewire.nodes.values.filter(node => node?.audio && node.isStream && node.isSink)
    readonly property var windows: CompositorService.isNiri ? NiriService.windows : []

    readonly property var matchers: groups.map(group => {
        const roles = group.roles.map(role => role.toLowerCase());
        return {
            "apps": compile(group.apps),
            "appIds": compile(group.appIds),
            "roles": roles,
            "steam": group.steam,
            "gamemode": group.gamemode,
            "mpris": group.mpris,
            "rest": !group.apps && !group.appIds && roles.length === 0 && !group.steam && !group.gamemode && !group.mpris
        };
    })

    // node id -> group index; -1 for none, -2 while its process is still being looked up
    readonly property var groupByNode: {
        const out = {};
        for (const node of streams)
            out[node.id] = active ? groupOf(node) : -1;
        return out;
    }

    // groups with a stream right now, before the join and leave delays
    readonly property var streamingNames: {
        const live = new Set(Object.values(groupByNode).filter(index => index >= 0));
        return groups.filter((group, index) => live.has(index)).map(group => group.name);
    }

    readonly property var volumes: streams.map(node => node.audio?.volume ?? 0)
    readonly property bool wantsGamemode: active && groups.some(group => group.gamemode)

    PwObjectTracker {
        objects: root.streams
    }

    // a factor from the shape, as the streams get it
    function heard(factor) {
        return Mixer.shape(factor, rangeDb);
    }

    function styleFor(color, index) {
        if (!color) {
            return {
                "accent": [Theme.primary, Theme.tertiary, Theme.secondary][index % 3],
                "container": [Theme.primaryContainer, Theme.tertiaryContainer, Theme.secondaryContainer][index % 3],
                "content": [Theme.onPrimaryContainer, Theme.onTertiaryContainer, Theme.onSecondaryContainer][index % 3]
            };
        }
        // a string in, a colour out
        const accent = Qt.lighter(color, 1);
        const container = Theme.blend(Theme.surfaceContainerHighest, accent, 0.35);
        return {
            "accent": accent,
            "container": container,
            "content": Theme.isLightColor(container) ? Qt.darker(accent, 2.2) : Qt.lighter(accent, 1.2)
        };
    }

    // a bad pattern matches nothing rather than breaking the rest
    function compile(pattern) {
        if (!pattern)
            return null;
        try {
            return new RegExp(pattern, "i");
        } catch (e) {
            return null;
        }
    }

    function streamPid(node) {
        return parseInt(node?.properties?.["application.process.id"] ?? "") || 0;
    }

    function appKey(node) {
        const props = node?.properties ?? {};
        return props["application.process.binary"] || props["application.name"] || node?.name || "";
    }

    // first match in config order wins; a rule-less group catches the rest
    function groupOf(node) {
        const props = node.properties ?? {};
        const pid = streamPid(node);
        const proc = pid ? procs[pid] : null;
        if (pid && proc === undefined)
            return -2;
        const chain = proc?.chain ?? (pid ? [pid] : []);
        const names = [props["application.name"], props["application.process.binary"], props["node.name"]].filter(name => !!name);
        const role = String(props["media.role"] ?? "").toLowerCase();
        let appId = "";
        for (const p of chain) {
            const window = windows.find(w => w.pid === p);
            if (window) {
                appId = window.app_id ?? "";
                break;
            }
        }
        const steam = !!proc?.steam;
        const gaming = chain.some(p => gamePids.includes(p));
        const playing = chain.some(p => mediaPids.includes(p));

        let rest = -1;
        for (let i = 0; i < matchers.length; i++) {
            const m = matchers[i];
            if (m.rest) {
                if (rest < 0)
                    rest = i;
                continue;
            }
            if ((m.apps && names.some(name => m.apps.test(name))) || (m.appIds && appId && m.appIds.test(appId)) || (role && m.roles.includes(role)) || (m.steam && steam) || (m.gamemode && gaming) || (m.mpris && playing))
                return i;
        }
        return rest;
    }

    function groupIndex(node) {
        return groupByNode[node?.id] ?? -1;
    }

    function factorOf(node) {
        const group = groupIndex(node);
        return group >= 0 ? groupFactors[group] ?? 1 : 1;
    }

    function toggleGroupMute(index) {
        const name = groups[index]?.name;
        if (name === undefined)
            return;
        mutedGroups = mutedGroups.includes(name) ? mutedGroups.filter(n => n !== name) : mutedGroups.concat([name]);
        saveTimer.restart();
    }

    function setExcluded(index, on) {
        const name = groups[index]?.name;
        if (name === undefined || excludedGroups.includes(name) === on)
            return;
        excludedGroups = on ? excludedGroups.concat([name]) : excludedGroups.filter(n => n !== name);
        saveTimer.restart();
    }

    // the app's own level in percent: its base when grouped, else its real volume
    function levelOf(node) {
        if (!node?.audio)
            return 0;
        const base = groupIndex(node) >= 0 ? bases[appKey(node)] : undefined;
        return Math.round((base ?? node.audio.volume) * 100);
    }

    function setLevel(node, percent) {
        if (!node?.audio)
            return;
        const value = Math.max(0, Math.min(maxLevel, percent / 100));
        if (groupIndex(node) < 0) {
            node.audio.volume = value;
            return;
        }
        const next = Object.assign({}, bases);
        next[appKey(node)] = value;
        bases = next;
        saveTimer.restart();
        scheduleApply();
    }

    function setDot(point) {
        dot = Mixer.clampTo(vertices, mixMuted, point);
        saveTimer.restart();
    }

    function nudgeDot(towardsVertex) {
        setDot(Mixer.nudge(vertices, effectiveDot, towardsVertex, 0.05));
    }

    function toggleBypass() {
        bypassed = !bypassed;
        saveTimer.restart();
    }

    function recentre() {
        setDot(Mixer.centre());
    }

    // the shape's groups changed: fit the dot so every group gets the factor it last had
    function relayout() {
        const names = groups.map(group => group.name).filter(name => presentNames.includes(name) && !excludedGroups.includes(name));
        if (JSON.stringify(names) === JSON.stringify(mixNames))
            return;
        const targets = names.map(name => lastFactors[name] ?? 1);
        const mutes = names.map(name => active && mutedGroups.includes(name));
        const fitted = Mixer.fit(Mixer.vertices(names.length), mutes, targets);
        _relayouting = true;
        mixNames = names;
        dot = fitted;
        _relayouting = false;
        remember();
        saveTimer.restart();
    }

    // the factors in play now; muted groups keep the one from before their mute
    function remember() {
        if (!engaged || _relayouting)
            return;
        const next = Object.assign({}, lastFactors);
        let changed = false;
        mixNames.forEach((name, i) => {
            if (mixMuted[i] || Math.abs((next[name] ?? -1) - mixFactors[i]) < 1e-4)
                return;
            next[name] = mixFactors[i];
            changed = true;
        });
        if (changed) {
            lastFactors = next;
            saveTimer.restart();
        }
    }

    function updatePresent() {
        const now = Date.now();
        const live = new Set(streamingNames);
        let next = presentNames.filter(name => groups.some(group => group.name === name));
        for (const group of groups) {
            const name = group.name;
            if (live.has(name)) {
                delete _gone[name];
                if (_since[name] === undefined)
                    _since[name] = now;
                if (!next.includes(name) && now - _since[name] >= joinMs)
                    next.push(name);
            } else {
                delete _since[name];
                if (!next.includes(name))
                    continue;
                if (_gone[name] === undefined)
                    _gone[name] = now;
                if (now - _gone[name] >= leaveMs) {
                    next = next.filter(n => n !== name);
                    delete _gone[name];
                }
            }
        }
        next = groups.map(group => group.name).filter(name => next.includes(name));
        if (JSON.stringify(next) !== JSON.stringify(presentNames))
            presentNames = next;
    }

    function lookupPlayers() {
        for (const name of mediaPlayers) {
            if (name in _playerPids)
                continue;
            _playerPids[name] = 0;
            Proc.runCommand(null, ["busctl", "--user", "call", "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "GetConnectionUnixProcessID", "s", name], (output, exitCode) => {
                const next = Object.assign({}, root._playerPids);
                next[name] = exitCode === 0 ? parseInt(output.trim().split(" ")[1]) || -1 : -1;
                root._playerPids = next;
            }, 0);
        }
    }

    function apply() {
        const now = Date.now();
        const next = Object.assign({}, bases);
        let rebased = false;
        let wrote = false;
        for (const node of streams) {
            const audio = node.audio;
            if (!audio || !node.ready)
                continue;
            const group = groupByNode[node.id] ?? -1;
            const key = appKey(node);
            const written = _written[node.id];
            const current = audio.volume;

            // no longer grouped: back to the app's own level
            if (group === -1) {
                if (written && next[key] !== undefined)
                    audio.volume = next[key];
                delete _written[node.id];
                continue;
            }
            if (group < 0)
                continue;

            const factor = groupFactors[group] ?? 1;
            let base = next[key];
            if (base === undefined) {
                // first sight: what wireplumber restored is the app's own level
                base = current;
                next[key] = base;
                rebased = true;
            } else if (written && now - written.at > settleMs && Math.abs(current - written.value) > 0.005 && factor > 0.01) {
                // set somewhere else, like pavucontrol: that's the app's new level
                base = Math.min(maxLevel, current / factor);
                next[key] = base;
                rebased = true;
            }

            const target = base * factor;
            if (Math.abs(current - target) > 0.002) {
                audio.volume = target;
                _written[node.id] = {
                    "value": target,
                    "at": now
                };
                wrote = true;
            } else if (!written || Math.abs(current - written.value) > 0.005) {
                // already right, or just adopted as the new level: remember it so it isn't adopted again
                _written[node.id] = {
                    "value": current,
                    "at": 0
                };
            }
        }
        if (rebased) {
            bases = next;
            saveTimer.restart();
        }
        if (wrote)
            settleTimer.restart();
    }

    // every stream we scaled, back to its own level
    function restore() {
        for (const node of streams) {
            const base = bases[appKey(node)];
            if (_written[node.id] && node.audio && base !== undefined)
                node.audio.volume = base;
        }
        _written = {};
    }

    function scheduleApply() {
        if (!applyTimer.running)
            applyTimer.start();
    }

    function resolve() {
        const helper = PluginService.getPluginPath(pluginId) + "/audigon-proc";
        for (const node of streams) {
            const pid = streamPid(node);
            if (!pid || pid in procs || _resolving[pid])
                continue;
            _resolving[pid] = true;
            Proc.runCommand(null, [helper, String(pid)], (output, exitCode) => {
                delete root._resolving[pid];
                const fields = output.trim().split(" ").map(Number);
                const next = Object.assign({}, root.procs);
                next[pid] = exitCode === 0 && fields.length >= 2 ? {
                    "steam": fields[0] > 0,
                    "chain": fields.slice(1)
                } : null;
                root.procs = next;
            }, 0);
        }
    }

    // forget pids, nodes and players that are gone; pids get reused
    function prune() {
        const pids = new Set(streams.map(node => streamPid(node)));
        const ids = new Set(streams.map(node => node.id));
        const stale = Object.keys(procs).filter(pid => !pids.has(Number(pid)));
        if (stale.length > 0) {
            const next = Object.assign({}, procs);
            for (const pid of stale)
                delete next[pid];
            procs = next;
        }
        for (const id in _written) {
            if (!ids.has(Number(id)))
                delete _written[id];
        }
        const gonePlayers = Object.keys(_playerPids).filter(name => !mediaPlayers.includes(name));
        if (gonePlayers.length > 0) {
            const next = Object.assign({}, _playerPids);
            for (const name of gonePlayers)
                delete next[name];
            _playerPids = next;
        }
    }

    function refreshGames() {
        Proc.runCommand("audigon-gamemode", ["busctl", "--user", "--json=short", "call", "com.feralinteractive.GameMode", "/com/feralinteractive/GameMode", "com.feralinteractive.GameMode", "ListGames"], (output, exitCode) => {
            let pids = [];
            if (exitCode === 0) {
                try {
                    pids = (JSON.parse(output).data?.[0] ?? []).map(game => game[0]);
                } catch (e) {
                    pids = [];
                }
            }
            root.gamePids = pids;
        }, 100);
    }

    onStreamsChanged: {
        resolve();
        Qt.callLater(prune);
    }
    onGroupFactorsChanged: scheduleApply()
    onGroupByNodeChanged: scheduleApply()
    onVolumesChanged: scheduleApply()
    onMixFactorsChanged: remember()
    onPresentNamesChanged: relayout()
    onExcludedGroupsChanged: relayout()
    onGroupsChanged: {
        relayout();
        updatePresent();
    }
    onActiveChanged: {
        if (active)
            scheduleApply();
        else
            restore();
    }
    onMediaPlayersChanged: {
        lookupPlayers();
        Qt.callLater(prune);
    }
    onWantsGamemodeChanged: {
        if (!wantsGamemode)
            gamePids = [];
    }

    // at most one pass a frame or so while the dot is dragged
    Timer {
        id: applyTimer

        interval: 33
        onTriggered: root.apply()
    }

    // once our writes settle, look again for changes made elsewhere
    Timer {
        id: settleTimer

        interval: root.settleMs + 50
        onTriggered: root.apply()
    }

    // groups joining and leaving the shape
    Timer {
        interval: 500
        repeat: true
        running: root.active
        onTriggered: root.updatePresent()
    }

    Timer {
        id: saveTimer

        interval: 1000
        onTriggered: {
            PluginService.savePluginState(root.pluginId, "dot", root.dot);
            PluginService.savePluginState(root.pluginId, "bases", root.bases);
            PluginService.savePluginState(root.pluginId, "mutedGroups", root.mutedGroups);
            PluginService.savePluginState(root.pluginId, "excludedGroups", root.excludedGroups);
            PluginService.savePluginState(root.pluginId, "lastFactors", root.lastFactors);
            PluginService.savePluginState(root.pluginId, "bypassed", root.bypassed);
        }
    }

    // gamemoded's registrations, as they happen
    Process {
        running: root.wantsGamemode
        command: ["busctl", "--user", "monitor", "--json=short", "--match", "type='signal',interface='com.feralinteractive.GameMode'"]
        stdout: SplitParser {
            onRead: root.refreshGames()
        }
        onStarted: root.refreshGames()
    }

    Component.onCompleted: {
        bases = PluginService.loadPluginState(pluginId, "bases", {});
        mutedGroups = PluginService.loadPluginState(pluginId, "mutedGroups", []);
        excludedGroups = PluginService.loadPluginState(pluginId, "excludedGroups", []);
        lastFactors = PluginService.loadPluginState(pluginId, "lastFactors", {});
        bypassed = PluginService.loadPluginState(pluginId, "bypassed", false);
        dot = PluginService.loadPluginState(pluginId, "dot", Mixer.centre());
        resolve();
    }

    // never leave apps scaled down once audigon is gone
    Component.onDestruction: restore()
}
