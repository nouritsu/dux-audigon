// node tests/lib.test.mjs: groups, theme colours and the wheel
import assert from "node:assert/strict";
import {load} from "./load.mjs";

const Groups = load("groups");
const Colors = load("colors");
const Wheel = load("wheel");

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

// theme colour labels read like the keys
{
    assert.equal(Colors.label("primary"), "Primary");
    assert.equal(Colors.label("surfaceContainerHighest"), "Surface Container Highest");
    assert.ok(Colors.keys().includes("surfaceText"));
}

// the wheel: a notch a step, a touchpad's small deltas add up, turning back starts over
{
    const scroll = deltas => {
        let rest = 0;
        const steps = [];
        for (const delta of deltas) {
            const turn = Wheel.notches(rest, delta);
            rest = turn.rest;
            // -0 is no step to the callers too
            steps.push(turn.steps + 0);
        }
        return steps;
    };
    assert.deepEqual(scroll([120, 120, -120]), [1, 1, -1]);
    assert.deepEqual(scroll([240]), [2]);
    assert.deepEqual(scroll([30, 30, 30, 30, 30]), [0, 0, 0, 1, 0]);
    assert.deepEqual(scroll([90, -30, -90]), [0, 0, -1]);
    // a sideways event doesn't count, or lose what had built up
    assert.deepEqual(scroll([90, 0, 30]), [0, 0, 1]);
}

console.log("lib: ok");
