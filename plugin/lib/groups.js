.pragma library

// The mixer's groups as saved in settings, read the same way by the daemon and the settings page.

const MAX_GROUPS = 8;
const CHAT_APPS = "vesktop|discord|webcord|legcord|teams|zoom|skype|mumble|teamspeak|signal|element";
const MEDIA_APPS = "spotify|ncspot|spotube|mpv|celluloid|haruna|vlc|totem|showtime|clapper|jellyfin|feishin|supersonic|sonixd|elisa|amberol|rhythmbox|lollypop|strawberry|clementine|audacious|deadbeef|cmus|quodlibet|tauon|youtube-music|tidal-hifi|plex|kodi|stremio|freetube";

function maxGroups() {
    return MAX_GROUPS;
}

// a group with no rules takes whatever nothing else matched
function defaults() {
    return [
        {"name": "Game", "icon": "sports_esports", "roles": ["Game"], "steam": true, "gamemode": true},
        {"name": "Voice Chat", "icon": "headset_mic", "apps": CHAT_APPS, "appIds": CHAT_APPS, "roles": ["Communication"]},
        {"name": "Media", "icon": "music_note", "apps": MEDIA_APPS, "appIds": MEDIA_APPS, "roles": ["Music", "Movie"], "mpris": true},
        {"name": "Etc", "icon": "graphic_eq"}
    ];
}

// every field filled in, and the names unique, since mutes, exclusions and the shape go by name
function normalise(list) {
    const source = Array.isArray(list) && list.length >= 2 ? list : defaults();
    const taken = new Set();
    return source.slice(0, MAX_GROUPS).map((group, i) => ({
                "name": unique(String(group?.name ?? "").trim() || `Group ${i + 1}`, taken),
                "icon": String(group?.icon || "graphic_eq"),
                "color": /^#[0-9a-f]{6}([0-9a-f]{2})?$/i.test(group?.color ?? "") ? group.color : "",
                "apps": String(group?.apps ?? ""),
                "appIds": String(group?.appIds ?? ""),
                "roles": Array.isArray(group?.roles) ? group.roles.map(String) : [],
                "steam": !!group?.steam,
                "gamemode": !!group?.gamemode,
                "mpris": !!group?.mpris
            }));
}

function unique(name, taken) {
    let out = name;
    for (let n = 2; taken.has(out); n++)
        out = `${name} ${n}`;
    taken.add(out);
    return out;
}
