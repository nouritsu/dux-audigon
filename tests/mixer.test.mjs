// node tests/mixer.test.mjs: the mixer geometry, loaded the way QML would
import {readFileSync} from "node:fs";
import assert from "node:assert/strict";

const source = readFileSync(new URL("../plugin/lib/mixer.js", import.meta.url), "utf8").replace(/^\.pragma library$/m, "");
const Mixer = new Function(`${source}; return {vertices, clamp, sector, factors, centre, nudge, inside, clampTo, closestInTriangle, fit, transition};`)();

const near = (actual, expected, what, tolerance = 1e-6) => {
    assert.equal(actual.length, expected.length, what);
    actual.forEach((value, i) => assert.ok(Math.abs(value - expected[i]) < tolerance, `${what}: got ${actual}, want ${expected}`));
};

// two groups: classic chatmix
{
    const v = Mixer.vertices(2);
    near(Mixer.factors(v, {"x": 0.5, "y": 0.5}), [1, 1], "line centre");
    near(Mixer.factors(v, {"x": 0, "y": 0.5}), [1, 0], "line left end");
    near(Mixer.factors(v, {"x": 1, "y": 0.5}), [0, 1], "line right end");
    near(Mixer.factors(v, {"x": 0.25, "y": 0.5}), [1, 0.5], "line quarter");
    near(Mixer.factors(v, {"x": 0.9, "y": 0.5}), [0.2, 1], "line near the right");
    near(Mixer.factors(v, {"x": -3, "y": 9}), [1, 0], "line clamps");
}

for (let n = 3; n <= 8; n++) {
    const v = Mixer.vertices(n);
    // pointing down: the first vertex at the bottom middle
    near([v[0].x, v[0].y], [0.5, 1], `${n}-gon first vertex at the bottom`);
    near(Mixer.factors(v, Mixer.centre()), new Array(n).fill(1), `${n}-gon centre`);
    for (let i = 0; i < n; i++) {
        const solo = new Array(n).fill(0);
        solo[i] = 1;
        near(Mixer.factors(v, v[i]), solo, `${n}-gon vertex ${i}`);

        const j = (i + 1) % n;
        const pair = new Array(n).fill(0);
        pair[i] = 1;
        pair[j] = 1;
        near(Mixer.factors(v, {"x": (v[i].x + v[j].x) / 2, "y": (v[i].y + v[j].y) / 2}), pair, `${n}-gon edge ${i}-${j} midpoint`);

        // halfway to a vertex: it stays full, every other group at half
        const half = new Array(n).fill(0.5);
        half[i] = 1;
        near(Mixer.factors(v, {"x": (0.5 + v[i].x) / 2, "y": (0.5 + v[i].y) / 2}), half, `${n}-gon halfway to ${i}`);
    }

    // far outside lands on the boundary
    const out = Mixer.clamp(v, {"x": 5, "y": -5});
    const f = Mixer.factors(v, out);
    assert.ok(f.every(x => x >= 0 && x <= 1), `${n}-gon clamped factors in range: ${f}`);
    assert.ok(f.some(x => x === 1), `${n}-gon clamped has a leader: ${f}`);

    // nudging walks to the nearest vertex and back
    let p = Mixer.nudge(v, {"x": (0.5 + v[0].x) / 2, "y": (0.5 + v[0].y) / 2}, true, 10);
    near([p.x, p.y], [v[0].x, v[0].y], `${n}-gon nudge to vertex`);
    p = Mixer.nudge(v, p, false, 10);
    near([p.x, p.y], [0.5, 0.5], `${n}-gon nudge to centre`);
}

// continuous across a sector boundary (the ray to a vertex)
{
    const v = Mixer.vertices(5);
    const onRay = {"x": 0.5 + (v[2].x - 0.5) * 0.7, "y": 0.5 + (v[2].y - 0.5) * 0.7};
    const eps = 1e-7;
    const dx = -(v[2].y - 0.5) * eps;
    const dy = (v[2].x - 0.5) * eps;
    near(Mixer.factors(v, {"x": onRay.x + dx, "y": onRay.y + dy}), Mixer.factors(v, {"x": onRay.x - dx, "y": onRay.y - dy}), "5-gon sector seam");
}

// muted groups: the dot keeps out of every sector touching them
{
    const v = Mixer.vertices(3);
    const c = Mixer.centre();
    near(Object.values(Mixer.clampTo(v, [false, false, false], v[2])), [v[2].x, v[2].y], "nothing muted: free");

    // one muted: only the sector between the other two
    const open = [c, v[0], v[1]];
    const pulled = Mixer.clampTo(v, [false, false, true], v[2]);
    near(Object.values(Mixer.closestInTriangle(pulled, open)), [pulled.x, pulled.y], "one muted: pulled into the open sector");
    const mid = {"x": (c.x + v[0].x + v[1].x) / 3, "y": (c.y + v[0].y + v[1].y) / 3};
    near(Object.values(Mixer.clampTo(v, [false, false, true], mid)), [mid.x, mid.y], "one muted: free inside the open sector");

    // two muted: only the spoke to the last
    const onSpoke = Mixer.clampTo(v, [false, true, true], {"x": 0.9, "y": 0.2});
    const cross = (v[0].x - c.x) * (onSpoke.y - c.y) - (v[0].y - c.y) * (onSpoke.x - c.x);
    assert.ok(Math.abs(cross) < 1e-9, `two muted: on the spoke, got ${JSON.stringify(onSpoke)}`);

    // all muted: the centre
    near(Object.values(Mixer.clampTo(v, [true, true, true], v[0])), [0.5, 0.5], "all muted: centre");

    // a square (left vertex muted): its two sectors are blocked, so the left half reaches only the spokes
    const s = Mixer.vertices(4);
    const leftOut = [false, true, false, false];
    near(Object.values(Mixer.clampTo(s, leftOut, s[1])), [0.5, 0.5], "square: muted vertex pulls to the centre");
    near(Object.values(Mixer.clampTo(s, leftOut, {"x": 0.25, "y": 0.75})), [0.5, 0.75], "square: blocked sector lands on the spoke");
    near(Object.values(Mixer.clampTo(s, leftOut, {"x": 0.75, "y": 0.6})), [0.75, 0.6], "square: open sector free");
}

// a line with one end muted: only the other half
{
    const v = Mixer.vertices(2);
    near(Object.values(Mixer.clampTo(v, [false, true], {"x": 0.9, "y": 0.5})), [0.5, 0.5], "line: muted half blocked");
    near(Object.values(Mixer.clampTo(v, [false, true], {"x": 0.2, "y": 0.5})), [0.2, 0.5], "line: open half free");
}

// keeping the volumes when the shape changes
{
    const tri = Mixer.vertices(3);
    const line = Mixer.vertices(2);
    const none = [false, false, false];
    // the dot finds the factors it's asked for, where the shape can give them
    const half = Mixer.fit(tri, none, [1, 0.5, 0.5]);
    near(Mixer.factors(tri, half), [1, 0.5, 0.5], "fit: halfway to the first vertex", 1e-3);
    const edge = Mixer.fit(tri, none, [1, 1, 0]);
    near(Mixer.factors(tri, edge), [1, 1, 0], "fit: an edge's middle", 1e-3);
    // a triangle losing a vertex keeps the other two
    const lost = Mixer.fit(line, [false, false], [1, 0.2]);
    near(Mixer.factors(line, lost), [1, 0.2], "fit: line keeps the two", 1e-3);
    // muted ones and don't-cares are left out
    const free = Mixer.fit(tri, [false, false, true], [1, 0.4, 1]);
    near(Mixer.factors(tri, free).slice(0, 2), [1, 0.4], "fit: muted target ignored", 1e-3);
    const loose = Mixer.fit(tri, none, [0.3, 1, null]);
    near(Mixer.factors(tri, loose).slice(0, 2), [0.3, 1], "fit: null target ignored", 1e-3);
    // a single group or none: the middle
    near(Object.values(Mixer.fit(Mixer.vertices(1), [false], [1])), [0.5, 0.5], "fit: one vertex");
    assert.equal(Mixer.vertices(1).length, 1, "one vertex: in the middle");
    assert.equal(Mixer.vertices(0).length, 0, "no vertices");
}

// reshaping: staying vertices move, new ones grow from between their neighbours, old ones shrink into theirs
{
    const tri = Mixer.vertices(3);
    const line = Mixer.vertices(2);
    const before = {"a": line[0], "c": line[1]};
    const after = {"a": tri[0], "b": tri[1], "c": tri[2]};
    const grow = Mixer.transition(["a", "b", "c"], before, after);
    near([grow.a.from.x, grow.a.from.y, grow.a.to.x, grow.a.to.y], [line[0].x, line[0].y, tri[0].x, tri[0].y], "transition: a moves");
    near([grow.b.from.x, grow.b.from.y, grow.b.from.s, grow.b.to.s], [0.5, 0.5, 0, 1], "transition: b grows from the line's middle");
    const shrink = Mixer.transition(["a", "b", "c"], after, before);
    near([shrink.b.to.x, shrink.b.to.y, shrink.b.to.s], [0.5, 0.5, 0], "transition: b shrinks into the line's middle");
    // a square losing one: it folds onto the edge between its neighbours
    const sq = Mixer.vertices(4);
    const fold = Mixer.transition(["a", "b", "c", "d"], {"a": sq[0], "b": sq[1], "c": sq[2], "d": sq[3]}, {"a": tri[0], "b": tri[1], "c": tri[2]});
    near([fold.d.to.x, fold.d.to.y], [(tri[2].x + tri[0].x) / 2, (tri[2].y + tri[0].y) / 2], "transition: d folds between c and a");
    // the last one leaving shrinks in place
    const last = Mixer.transition(["a"], {"a": {"x": 0.5, "y": 0.5}}, {});
    near([last.a.to.x, last.a.to.y, last.a.to.s], [0.5, 0.5, 0], "transition: last one shrinks in the middle");
}

console.log("mixer: ok");
