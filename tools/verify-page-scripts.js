// Checks the scripts on the exported page parse, and that the hooks the game
// depends on are actually there.
//
//   node verify-page-scripts.js <build-dir>
//
// This exists because of a bug that cost an afternoon. The install and update
// hooks are injected through export_presets.cfg's head_include, which Godot
// stores as a quoted string — so a raw double quote in that JavaScript ends
// the string early and the exported page gets a script that never closes. The
// build still exports, still deploys, and still serves; it just never starts,
// because the browser is looking at one unterminated script tag.
//
// A browser-based check does catch it, eventually, as a canvas that never
// appears after a ninety second timeout. Parsing the file says the same thing
// in a second, and says which script and where.
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const dir = process.argv[2];
if (!dir) {
  console.error('usage: verify-page-scripts.js <build-dir>');
  process.exit(2);
}

const html = fs.readFileSync(path.join(dir, 'index.html'), 'utf8');
const checks = [];

// An unterminated script tag shows up as a mismatch in the count, before any
// parsing happens.
const opens = (html.match(/<script(\s[^>]*)?>/g) || []).length;
const closes = (html.match(/<\/script>/g) || []).length;
checks.push(['every script tag is closed', opens === closes,
  `${opens} open, ${closes} close`]);

const blocks = [];
const re = /<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g;
let m = re.exec(html);
while (m !== null) {
  if (m[1].trim()) blocks.push(m[1]);
  m = re.exec(html);
}

let bad = '';
for (let i = 0; i < blocks.length; i += 1) {
  try {
    // eslint-disable-next-line no-new
    new vm.Script(blocks[i], { filename: `index.html:script[${i}]` });
  } catch (err) {
    bad = `script[${i}]: ${err.message}`;
    break;
  }
}
checks.push([`${blocks.length} inline scripts parse`, bad === '', bad || 'all parse']);

// The hooks the game calls across the bridge. A page that parses but has lost
// one of these is the same failure with a quieter symptom.
for (const hook of ['__cz_can_install', '__cz_install', '__cz_installed',
  '__cz_update_ready', '__cz_apply_update', 'serviceWorker.register']) {
  checks.push([`the page defines ${hook}`, html.includes(hook),
    html.includes(hook) ? 'present' : 'MISSING']);
}

console.log('--- the exported page is well formed ---');
for (const [name, ok, detail] of checks) {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name.padEnd(34)} ${detail}`);
}
const ok = checks.every((c) => c[1]);
console.log(`VERDICT                                 : ${ok ? 'PASS' : 'FAIL'}`);
process.exit(ok ? 0 : 1);
