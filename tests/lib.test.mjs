// node tests/lib.test.mjs: the groups as saved
import assert from "node:assert/strict";
import {load} from "./load.mjs";

const Groups = load("groups");

const names = list => Groups.normalise(list).map(group => group.name);

// nothing saved, or too little to mix: the defaults
{
    assert.deepEqual(names(null), ["Game", "Voice Chat", "Media", "Etc"]);
    assert.deepEqual(names([{"name": "Solo"}]), ["Game", "Voice Chat", "Media", "Etc"]);
    const filled = Groups.normalise([{"name": "A"}, {}])[1];
    assert.deepEqual(filled, {"name": "Group 2", "icon": "graphic_eq", "color": "", "apps": "", "appIds": "", "roles": [], "steam": false, "gamemode": false, "mpris": false});
}

// names are trimmed, filled in when blank and never repeat
{
    assert.deepEqual(names([{"name": " A "}, {"name": "A"}, {"name": ""}, {"name": "A"}]), ["A", "A 2", "Group 3", "A 3"]);
    assert.deepEqual(names([{"name": "Group 2"}, {"name": ""}]), ["Group 2", "Group 2 2"]);
    // a group added after another was removed doesn't take a name in use
    const added = Groups.normalise([{"name": "Group 1"}, {"name": "Group 3"}, {}]);
    assert.deepEqual(added.map(group => group.name), ["Group 1", "Group 3", "Group 3 2"]);
}

// at most maxGroups, colours only as hex
{
    assert.equal(Groups.normalise(new Array(12).fill({})).length, Groups.maxGroups());
    const colours = Groups.normalise([{"color": "#ff0000"}, {"color": "#80ff000a"}, {"color": "red"}, {"color": "#fff"}]).map(group => group.color);
    assert.deepEqual(colours, ["#ff0000", "#80ff000a", "", ""]);
}

// a rename is one name changed in place; moves, adds, removes and swaps aren't
{
    assert.deepEqual(Groups.renamed(["a", "b", "c"], ["a", "x", "c"]), {"from": "b", "to": "x"});
    assert.equal(Groups.renamed(["a", "b", "c"], ["b", "a", "c"]), null);
    assert.equal(Groups.renamed(["a", "b"], ["a", "b", "c"]), null);
    assert.equal(Groups.renamed(["a", "b", "c"], ["a", "c"]), null);
    assert.equal(Groups.renamed(["a", "b", "c"], ["a", "c", "c 2"]), null);
    assert.equal(Groups.renamed(["a", "b"], ["a", "b"]), null);
}

console.log("lib: ok");
