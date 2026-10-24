// Prints the web version's data tables as JSON, for tools/tables.py.
const fs = require("fs");
const html = fs.readFileSync(process.argv[2], "utf8");
const names = ["Q", "PLEAS", "STATIONS", "ROOMS", "ROOMS4", "BURN", "DELETE", "SPELL", "CHAPTERS", "CREDITS"];
const out = {};
for (const n of names) {
  const i = html.indexOf("const " + n + " = ");
  let j = i + ("const " + n + " = ").length, d = 0, inStr = false;
  for (; j < html.length; j++) {
    const c = html[j];
    if (inStr) { if (c === "\\") j++; else if (c === '"') inStr = false; continue; }
    if (c === '"') inStr = true;
    else if ("[{(".includes(c)) d++;
    else if ("]})".includes(c)) d--;
    else if (c === ";" && d === 0) break;
  }
  out[n] = eval("(" + html.slice(i + ("const " + n + " = ").length, j) + ")");
}
console.log(JSON.stringify(out));
