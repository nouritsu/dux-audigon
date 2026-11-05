// a plugin/lib script loaded the way QML would, with its top-level functions by name
import {readFileSync} from "node:fs";

export function load(name) {
    const source = readFileSync(new URL(`../plugin/lib/${name}.js`, import.meta.url), "utf8").replace(/^\.pragma library$/m, "");
    const names = [...source.matchAll(/^function (\w+)/gm)].map(match => match[1]);
    return new Function(`${source}; return {${names.join(", ")}};`)();
}
