.pragma library

// whole notches in a wheel event plus what was left from the last: a mouse sends 120 a notch, a
// touchpad a little at a time. Turning back drops what had built up the other way
function notches(rest, delta) {
    if (delta === 0)
        return {"steps": 0, "rest": rest};
    const total = rest * delta > 0 ? rest + delta : delta;
    const steps = Math.trunc(total / 120);
    return {"steps": steps, "rest": total - steps * 120};
}
