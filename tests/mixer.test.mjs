// node tests/mixer.test.mjs: the mixer geometry, loaded the way QML would
import {readFileSync} from "node:fs";
import assert from "node:assert/strict";

const source = readFileSync(new URL("../plugin/lib/mixer.js", import.meta.url), "utf8").replace(/^\.pragma library$/m, "");
const Mixer = new Function(`${source}; return {vertices, clamp, sector, factors, centre, nudge, inside, clampTo, closestInTriangle};`)();

const near = (actual, expected, what) => {
    assert.equal(actual.length, expected.length, what);
    actual.forEach((value, i) => assert.ok(Math.abs(value - expected[i]) < 1e-6, `${what}: got ${actual}, want ${expected}`));
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

console.log("mixer: ok");
