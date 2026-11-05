.pragma library

// The mixer's geometry, in a unit square with y down. One group sits in the middle, two at the ends
// of a horizontal line; three or more on a regular polygon pointing down, the first at the bottom,
// then clockwise.

const EPS = 1e-9;

function vertices(n) {
    if (n < 1)
        return [];
    if (n === 1)
        return [centre()];
    if (n === 2)
        return [{"x": 0, "y": 0.5}, {"x": 1, "y": 0.5}];
    const out = [];
    for (let i = 0; i < n; i++) {
        const a = Math.PI / 2 + 2 * Math.PI * i / n;
        out.push({"x": 0.5 + 0.5 * Math.cos(a), "y": 0.5 + 0.5 * Math.sin(a)});
    }
    return out;
}

// twice the signed area of abc; positive for clockwise on screen
function area(a, b, c) {
    return (b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y);
}

function closestOnSegment(p, a, b) {
    const dx = b.x - a.x;
    const dy = b.y - a.y;
    const len = dx * dx + dy * dy;
    const t = len < EPS ? 0 : Math.max(0, Math.min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / len));
    return {"x": a.x + t * dx, "y": a.y + t * dy, "t": t};
}

// inside the polygon, edges included
function inside(verts, p) {
    const n = verts.length;
    if (n < 3)
        return false;
    for (let i = 0; i < n; i++) {
        if (area(verts[i], verts[(i + 1) % n], p) < 0)
            return false;
    }
    return true;
}

// p moved onto the line, or into the polygon, whichever is nearest
function clamp(verts, p) {
    const n = verts.length;
    if (n === 2)
        return {"x": Math.max(0, Math.min(1, p.x)), "y": 0.5};
    if (n < 2)
        return {"x": 0.5, "y": 0.5};
    if (inside(verts, p))
        return {"x": p.x, "y": p.y};
    let best = null;
    let bestDist = Infinity;
    for (let i = 0; i < n; i++) {
        const q = closestOnSegment(p, verts[i], verts[(i + 1) % n]);
        const d = (q.x - p.x) * (q.x - p.x) + (q.y - p.y) * (q.y - p.y);
        if (d < bestDist) {
            bestDist = d;
            best = q;
        }
    }
    return {"x": best.x, "y": best.y};
}

function closestInTriangle(p, tri) {
    const [a, b, c] = tri;
    const s = [area(a, b, p), area(b, c, p), area(c, a, p)];
    if (!(s.some(v => v < -EPS) && s.some(v => v > EPS)))
        return {"x": p.x, "y": p.y};
    let best = null;
    let bestDist = Infinity;
    for (const [u, v] of [[a, b], [b, c], [c, a]]) {
        const q = closestOnSegment(p, u, v);
        const d = (q.x - p.x) * (q.x - p.x) + (q.y - p.y) * (q.y - p.y);
        if (d < bestDist) {
            bestDist = d;
            best = q;
        }
    }
    return best;
}

// where the dot may go with some groups muted: each sector between two unmuted vertices and
// the centre, and the spoke to every unmuted vertex; a line's halves are its spokes
function pieces(verts, muted) {
    const n = verts.length;
    const c = centre();
    const out = [];
    if (n >= 3) {
        for (let i = 0; i < n; i++) {
            const j = (i + 1) % n;
            if (!muted[i] && !muted[j])
                out.push([c, verts[i], verts[j]]);
        }
    }
    for (let i = 0; i < n; i++) {
        if (!muted[i])
            out.push([c, verts[i]]);
    }
    return out;
}

// p moved to the nearest place the dot may go; with everything muted, the centre
function clampTo(verts, muted, p) {
    if (!(muted ?? []).some(m => m))
        return clamp(verts, p);
    const parts = pieces(verts, muted);
    if (parts.length === 0)
        return centre();
    let best = null;
    let bestDist = Infinity;
    for (const part of parts) {
        const q = part.length === 3 ? closestInTriangle(p, part) : closestOnSegment(p, part[0], part[1]);
        const d = (q.x - p.x) * (q.x - p.x) + (q.y - p.y) * (q.y - p.y);
        if (d < bestDist) {
            bestDist = d;
            best = q;
        }
    }
    return {"x": best.x, "y": best.y};
}

// where p sits between the centre and its two nearest vertices: [i, j, lc, li, lj], weights summing to 1
function sector(verts, p) {
    const n = verts.length;
    if (n === 2) {
        const t = Math.max(0, Math.min(1, p.x));
        return t <= 0.5 ? [0, 1, 2 * t, 1 - 2 * t, 0] : [0, 1, 2 * (1 - t), 0, 2 * t - 1];
    }
    const q = clamp(verts, p);
    const c = centre();
    let best = null;
    let bestMin = -Infinity;
    for (let i = 0; i < n; i++) {
        const j = (i + 1) % n;
        const denom = area(c, verts[i], verts[j]);
        const lc = area(q, verts[i], verts[j]) / denom;
        const li = area(c, q, verts[j]) / denom;
        const lj = area(c, verts[i], q) / denom;
        // the sector holding q has no negative weight; rounding can leave none exactly so
        const least = Math.min(lc, li, lj);
        if (least > bestMin) {
            bestMin = least;
            best = [i, j, Math.max(0, lc), Math.max(0, li), Math.max(0, lj)];
        }
    }
    const sum = best[2] + best[3] + best[4];
    return [best[0], best[1], best[2] / sum, best[3] / sum, best[4] / sum];
}

// each group's volume factor: all full at the centre, solo at a vertex, both full at an edge's
// middle; others fall with the distance from the centre, so halfway to a vertex they're at half
function factors(verts, p) {
    const n = verts.length;
    if (n < 2)
        return new Array(n).fill(1);
    const [i, j, lc, li, lj] = sector(verts, p);
    const out = new Array(n).fill(lc);
    out[i] = Math.min(1, lc + 2 * li);
    out[j] = Math.min(1, lc + 2 * lj);
    return out;
}

// the line's middle and every polygon's centre
function centre() {
    return {"x": 0.5, "y": 0.5};
}

// a wheel step: towards the nearest vertex, or back towards the centre
function nudge(verts, p, towardsVertex, amount) {
    const n = verts.length;
    if (n < 2)
        return p;
    if (n === 2) {
        // up moves right, like the slider it replaces
        return clamp(verts, {"x": p.x + (towardsVertex ? amount : -amount), "y": 0.5});
    }
    let target = centre();
    if (towardsVertex) {
        let bestDist = Infinity;
        for (const v of verts) {
            const d = Math.hypot(v.x - p.x, v.y - p.y);
            if (d < bestDist) {
                bestDist = d;
                target = v;
            }
        }
    }
    const dx = target.x - p.x;
    const dy = target.y - p.y;
    const dist = Math.hypot(dx, dy);
    if (dist <= amount)
        return clamp(verts, target);
    return clamp(verts, {"x": p.x + dx / dist * amount, "y": p.y + dy / dist * amount});
}

// a dot for these vertices whose factors come closest to targets (null for don't care; muted ones
// never count): a grid over the open area, then a finer search around the best
function fit(verts, muted, targets) {
    const n = verts.length;
    if (n < 2)
        return centre();
    const cost = p => {
        const f = factors(verts, p);
        let sum = 0;
        for (let i = 0; i < n; i++) {
            if (targets[i] !== null && targets[i] !== undefined && !muted[i])
                sum += (f[i] - targets[i]) * (f[i] - targets[i]);
        }
        return sum;
    };
    let best = clampTo(verts, muted, centre());
    let bestCost = cost(best);
    const steps = 24;
    for (let i = 0; i <= steps; i++) {
        for (let j = 0; j <= (n === 2 ? 0 : steps); j++) {
            const p = clampTo(verts, muted, {"x": i / steps, "y": n === 2 ? 0.5 : j / steps});
            const c = cost(p);
            if (c < bestCost - 1e-12) {
                bestCost = c;
                best = p;
            }
        }
    }
    for (let step = 1 / steps; step > 1e-4;) {
        let moved = false;
        for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, -1], [1, -1], [-1, 1]]) {
            const p = clampTo(verts, muted, {"x": best.x + dx * step, "y": best.y + dy * step});
            const c = cost(p);
            if (c < bestCost - 1e-12) {
                bestCost = c;
                best = p;
                moved = true;
            }
        }
        if (!moved)
            step /= 2;
    }
    return {"x": best.x, "y": best.y};
}

// a reshape from one layout to another: keys in their cyclic order, old and new positions by key.
// A vertex that stays moves; one that joins grows out of the middle of its old neighbours, one
// that leaves shrinks into the middle of its new ones. Gives {key: {from, to}}, each {x, y, s}.
function transition(keys, before, after) {
    const neighbourMid = (key, layout) => {
        const present = keys.filter(k => layout[k] !== undefined);
        if (present.length === 0)
            return centre();
        const at = keys.indexOf(key);
        let prev = null;
        let next = null;
        for (let i = 1; i <= keys.length && (prev === null || next === null); i++) {
            const p = keys[(at - i + keys.length) % keys.length];
            const q = keys[(at + i) % keys.length];
            if (prev === null && layout[p] !== undefined && p !== key)
                prev = layout[p];
            if (next === null && layout[q] !== undefined && q !== key)
                next = layout[q];
        }
        prev = prev ?? next;
        next = next ?? prev;
        return {"x": (prev.x + next.x) / 2, "y": (prev.y + next.y) / 2};
    };
    const out = {};
    for (const key of keys) {
        const was = before[key];
        const will = after[key];
        if (was && will)
            out[key] = {"from": {"x": was.x, "y": was.y, "s": 1}, "to": {"x": will.x, "y": will.y, "s": 1}};
        else if (will) {
            const mid = neighbourMid(key, before);
            out[key] = {"from": {"x": mid.x, "y": mid.y, "s": 0}, "to": {"x": will.x, "y": will.y, "s": 1}};
        } else if (was) {
            const mid = neighbourMid(key, after);
            out[key] = {"from": {"x": was.x, "y": was.y, "s": 1}, "to": {"x": mid.x, "y": mid.y, "s": 0}};
        }
    }
    return out;
}
