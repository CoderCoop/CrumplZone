// Makes the service worker able to replace itself without the page's help.
//
//   node patch-service-worker.js <build-dir>
//
// Godot generates the worker at export time, so this cannot be a file kept in
// the repo — it is applied to the generated one on the way out.
//
// Why it exists. Godot's worker is cache-first over the whole app and calls
// skipWaiting() only when a page sends it an "update" message. That is enough
// when the cached page is recent enough to know how to send one, and useless
// when it is not — and the cached page is precisely the thing that goes stale.
// An install from before that code existed keeps its old page for ever: the
// browser fetches the new worker, the new worker installs, and then it waits
// behind a client that has no idea it should be asked to stand aside. Reported
// from a real phone still running 0.7.0 with 0.9.0 long since deployed.
//
// So the worker takes over on its own:
//
//   * skipWaiting() in install   — do not queue behind whatever is open
//   * clients.claim() in activate — control the page that is already there
//
// The page-side code stays: it makes the switch happen in the current visit
// rather than the next one. This is what makes it happen at all.
const fs = require('fs');
const path = require('path');

const dir = process.argv[2];
if (!dir) {
  console.error('usage: patch-service-worker.js <build-dir>');
  process.exit(2);
}

const file = path.join(dir, 'index.service.worker.js');
let source = fs.readFileSync(file, 'utf8');

const edits = [
  {
    what: 'skipWaiting on install',
    already: 'self.skipWaiting(); // take over',
    from: "self.addEventListener('install', (event) => {\n\tevent.waitUntil(",
    to: "self.addEventListener('install', (event) => {\n\tself.skipWaiting(); // take over rather than queue behind an open client\n\tevent.waitUntil(",
  },
  {
    what: 'clients.claim on activate',
    already: 'self.clients.claim(); // control the page',
    from: "\t).then(function () {\n\t\t// Enable navigation preload if available.",
    to: "\t).then(function () {\n\t\treturn self.clients.claim(); // control the page that is already open\n\t}).then(function () {\n\t\t// Enable navigation preload if available.",
  },
];

for (const edit of edits) {
  if (source.includes(edit.already)) {
    console.log(`already patched: ${edit.what}`);
    continue;
  }
  if (!source.includes(edit.from)) {
    console.error(`FAILED to patch: ${edit.what}`);
    console.error('The generated worker no longer contains the expected code —');
    console.error('probably a new Godot release. Read it and update this script');
    console.error('rather than letting the patch silently stop applying.');
    process.exit(1);
  }
  source = source.replace(edit.from, edit.to);
}

fs.writeFileSync(file, source);
console.log('service worker patched — it can now replace itself without the page');
