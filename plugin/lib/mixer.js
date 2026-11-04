.pragma library

// The mixer's geometry, in a unit square with y down. Two groups sit at the ends of a horizontal
// line; three or more on a regular polygon pointing down, the first at the bottom, then clockwise.

const EPS = 1e-9;

function vertices(n) {
    if (n < 2)
        return [];
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
