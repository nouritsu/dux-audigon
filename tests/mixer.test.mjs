// node tests/mixer.test.mjs: the mixer geometry, loaded the way QML would
import {readFileSync} from "node:fs";
import assert from "node:assert/strict";

const source = readFileSync(new URL("../plugin/lib/mixer.js", import.meta.url), "utf8").replace(/^\.pragma library$/m, "");
const Mixer = new Function(`${source}; return {vertices, clamp, sector, factors, centre, nudge};`)();

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

console.log("mixer: ok");
