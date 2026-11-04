pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Common
import qs.Modules.Plugins
import qs.Services
import "lib/mixer.js" as Mixer

// the mixer: sorts playback streams into groups and scales each by its group's factor; an app's own
// level stays its slider, the stream's real volume is that times the factor
PluginComponent {
    id: root

    // a group with no rules takes whatever nothing else matched
    readonly property var defaultGroups: [
        {
            "name": "Game",
            "icon": "sports_esports",
            "apps": "",
            "appIds": "",
            "roles": ["Game"],
            "steam": true,
            "gamemode": true
        },
        {
            "name": "Voice Chat",
            "icon": "headset_mic",
            "apps": root.chatApps,
            "appIds": root.chatApps,
            "roles": ["Communication"],
            "steam": false,
            "gamemode": false
        }
    ]
    readonly property string chatApps: "vesktop|discord|webcord|legcord|teams|zoom|skype|mumble|teamspeak|signal|element"
    readonly property int maxGroups: 8

    readonly property bool mixerEnabled: pluginData.mixerEnabled ?? true
    readonly property var groups: normalise(pluginData.groups)
    readonly property bool active: mixerEnabled && groups.length >= 2
    readonly property var vertices: Mixer.vertices(groups.length)
    readonly property real maxLevel: Math.max(1, (pluginData.maxVolumePercent || 100) / 100)

    // normalised, kept in plugin state
    property var dot: Mixer.centre()
    readonly property var factors: active ? Mixer.factors(vertices, dot) : groups.map(() => 1)

    // app key -> its own level, before the factor; kept in plugin state
    property var bases: ({})

    // stream pid -> {steam, chain: [pid, parent, ...]}; null once the lookup failed
    property var procs: ({})
    property var _resolving: ({})
    // pids gamemoded has registered
    property var gamePids: []

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
            "rest": !group.apps && !group.appIds && roles.length === 0 && !group.steam && !group.gamemode
        };
    })

    // node id -> group index; -1 for none, -2 while its process is still being looked up
    readonly property var groupByNode: {
        const out = {};
        for (const node of streams)
            out[node.id] = active ? groupOf(node) : -1;
        return out;
    }

    readonly property var volumes: streams.map(node => node.audio?.volume ?? 0)
    readonly property bool wantsGamemode: active && groups.some(group => group.gamemode)

    PwObjectTracker {
        objects: root.streams
    }

    function normalise(list) {
        const source = Array.isArray(list) && list.length >= 2 ? list : defaultGroups;
        return source.slice(0, maxGroups).map(group => ({
                    "name": String(group?.name ?? ""),
                    "icon": String(group?.icon || "graphic_eq"),
                    "apps": String(group?.apps ?? ""),
                    "appIds": String(group?.appIds ?? ""),
                    "roles": Array.isArray(group?.roles) ? group.roles.map(String) : [],
                    "steam": !!group?.steam,
                    "gamemode": !!group?.gamemode
                }));
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

    // first match in vertex order wins; a rule-less group catches the rest
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

        let rest = -1;
        for (let i = 0; i < matchers.length; i++) {
            const m = matchers[i];
            if (m.rest) {
                if (rest < 0)
                    rest = i;
                continue;
            }
            if ((m.apps && names.some(name => m.apps.test(name))) || (m.appIds && appId && m.appIds.test(appId)) || (role && m.roles.includes(role)) || (m.steam && steam) || (m.gamemode && gaming))
                return i;
        }
        return rest;
    }

    function groupIndex(node) {
        return groupByNode[node?.id] ?? -1;
    }

    function factorOf(node) {
        const group = groupIndex(node);
        return group >= 0 ? factors[group] ?? 1 : 1;
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
        dot = Mixer.clamp(vertices, point);
        saveTimer.restart();
    }

    function nudgeDot(towardsVertex) {
        setDot(Mixer.nudge(vertices, dot, towardsVertex, 0.05));
    }

    function recentre() {
        setDot(Mixer.centre());
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

            const factor = factors[group] ?? 1;
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
            } else if (!written) {
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

    // forget pids and nodes that are gone; pids get reused
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
    onFactorsChanged: scheduleApply()
    onGroupByNodeChanged: scheduleApply()
    onVolumesChanged: scheduleApply()
    onActiveChanged: {
        if (active)
            scheduleApply();
        else
            restore();
    }
    onVerticesChanged: dot = Mixer.clamp(vertices, dot)
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

    Timer {
        id: saveTimer

        interval: 1000
        onTriggered: {
            PluginService.savePluginState(root.pluginId, "dot", root.dot);
            PluginService.savePluginState(root.pluginId, "bases", root.bases);
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
        dot = Mixer.clamp(vertices, PluginService.loadPluginState(pluginId, "dot", Mixer.centre()));
        bases = PluginService.loadPluginState(pluginId, "bases", {});
        resolve();
    }

    // never leave apps scaled down once audigon is gone
    Component.onDestruction: restore()
}
