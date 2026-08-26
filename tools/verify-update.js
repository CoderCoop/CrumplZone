// Proves a published change actually reaches someone who already has the game.
//
//   node verify-update.js <serve-dir> <url> <screenshot>
//
// This is the check that matters most for a game being changed daily, and it
// is the one a manual test gets wrong: a fresh browser always sees the new
// build, so "I loaded it and it was fine" proves nothing about the player who
// installed it last week.
//
// So this plays that player. It loads a build, waits for the service worker to
// take control, swaps the files on the server for a newer build, and then asks
// whether the page ends up running the new one — without clearing anything,
// without a hard refresh, and without closing the tab.
//
// Godot's worker is cache-first over the whole app and never calls
// skipWaiting(), so before the page learned to send it an "update" message
// this test ended on the old build every time. That is the regression it
// exists to catch.
const { chromium } = require('playwright');
const fs = require('fs');
const os = require('os');
const path = require('path');

const serveDir = process.argv[2];
const url = process.argv[3];
const shot = process.argv[4];
if (!serveDir || !url) {
  console.error('usage: verify-update.js <serve-dir> <url> [screenshot]');
  process.exit(2);
}

const MARK = path.join(serveDir, 'version.txt');

const opts = {
  args: ['--no-sandbox', '--use-gl=swiftshader', '--enable-unsafe-swiftshader'],
  viewport: { width: 390, height: 844 },
  deviceScaleFactor: 2,
};
if (process.env.CHROMIUM_PATH) {
  opts.executablePath = process.env.CHROMIUM_PATH;
} else {
  opts.channel = 'chromium';
}

// Reading the served build back through the page, not off disk: what the
// player is running is whatever the service worker hands the page, which is
// exactly the thing in question.
const served = (page) => page.evaluate(async () => {
  const r = await fetch('version.txt', { cache: 'no-store' });
  return (await r.text()).trim();
});

// A stall here used to look exactly like a slow test, and the shell timeout
// killed only the wrapper while node carried on. This says where it got to and
// gives up on its own.
let stage = 'starting';
const at = (name) => { stage = name; if (process.env.VERBOSE) console.log(`... ${name}`); };
const WATCHDOG = Number(process.env.UPDATE_TIMEOUT_MS || 180000);
setTimeout(() => {
  console.log(`FAIL  timed out after ${WATCHDOG / 1000}s while: ${stage}`);
  console.log('VERDICT                               : FAIL');
  process.exit(1);
}, WATCHDOG).unref();

(async () => {
  const checks = [];
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'cz-upd-'));
  const ctx = await chromium.launchPersistentContext(profile, opts);
  const page = ctx.pages()[0] || await ctx.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));

  at('loading the first build');
  fs.writeFileSync(MARK, 'BUILD-ONE');
  await page.goto(url, { waitUntil: 'load', timeout: 90000 });
  await page.waitForSelector('canvas', { timeout: 90000 });

  // The worker has to be controlling the page before any of this means
  // anything — an uncontrolled page just fetches from the network and would
  // pass this test while offering the player nothing.
  at('waiting for the worker to take control');
  const controlled = await page.evaluate(async () => {
    await navigator.serviceWorker.ready;
    for (let i = 0; i < 60 && !navigator.serviceWorker.controller; i += 1) {
      await new Promise((r) => setTimeout(r, 500));
    }
    return !!navigator.serviceWorker.controller;
  });
  checks.push(['the worker controls the page', controlled, String(controlled)]);

  at('reading the build the page is on');
  const before = await served(page);
  checks.push(['the player is on the old build', before === 'BUILD-ONE', before]);

  // Publish. Only the marker changes, but the worker's own script has to
  // change too or the browser has no reason to install anything — which is
  // what a real release does, since the cache version is stamped at export.
  at('publishing the second build');
  fs.writeFileSync(MARK, 'BUILD-TWO');
  const swFile = path.join(serveDir, 'index.service.worker.js');
  const sw = fs.readFileSync(swFile, 'utf8');
  fs.writeFileSync(swFile, sw.replace(/const CACHE_VERSION = '[^']*'/,
    "const CACHE_VERSION = 'verify-update-two'"));

  // Now behave like a player: bring the app back to the foreground and wait.
  // No cache clearing, no hard refresh, no closing the tab.
  await page.evaluate(() => document.dispatchEvent(new Event('visibilitychange')));
  at('waiting for the page to notice');
  const noticed = await page.evaluate(async () => {
    const reg = await navigator.serviceWorker.getRegistration();
    for (let i = 0; i < 40; i += 1) {
      await reg.update().catch(() => {});
      if (window.__cz_update_ready && window.__cz_update_ready()) { return true; }
      await new Promise((r) => setTimeout(r, 500));
    }
    return false;
  });
  checks.push(['the page notices the new build', noticed, String(noticed)]);

  let after = before;
  if (noticed) {
    at('applying the update and reloading');
    // The game applies this itself at its next safe moment; drive it directly
    // so the test measures the delivery and not the game's own timing.
    // The worker navigates every client, so wait for that navigation rather
    // than for the call, which returns long before the page changes.
    await Promise.all([
      page.waitForNavigation({ timeout: 60000 }).catch(() => {}),
      page.evaluate(() => window.__cz_apply_update()).catch(() => {}),
    ]);
    await page.waitForLoadState('load', { timeout: 60000 }).catch(() => {});
    for (let i = 0; i < 40; i += 1) {
      after = await served(page).catch(() => after);
      if (after === 'BUILD-TWO') { break; }
      await page.waitForTimeout(500);
    }
  }
  checks.push(['the player ends up on the new build', after === 'BUILD-TWO', after]);

  // And the case that matters most, which the first two versions of this test
  // both got wrong. A client whose *cached* page predates the update code
  // cannot ask the worker to stand aside, because it does not know it should.
  // If the worker only skips waiting when asked, that client is pinned to its
  // install for ever. Reported from a real phone: 0.7.0, with 0.9.0 deployed.
  //
  // The first attempt stripped the hooks from the file on disk and reloaded.
  // That proves nothing: the client is served the page the worker cached, not
  // the file on disk, so it still had the hooks and still asked. The client's
  // cache has to be built from the old build in the first place, which means
  // a fresh profile that installs a hookless build before anything else.
  at('installing a build that predates the update code');
  const pageHtml = path.join(serveDir, 'index.html');
  const current = fs.readFileSync(pageHtml, 'utf8');
  fs.writeFileSync(pageHtml, current
    .replace(/window\.__cz_update_ready\s*=/, 'window.__cz_gone_update_ready =')
    .replace(/window\.__cz_apply_update\s*=/, 'window.__cz_gone_apply_update ='));
  fs.writeFileSync(MARK, 'BUILD-OLD');
  fs.writeFileSync(swFile, fs.readFileSync(swFile, 'utf8')
    .replace(/const CACHE_VERSION = '[^']*'/, "const CACHE_VERSION = 'verify-update-old'"));

  const oldProfile = fs.mkdtempSync(path.join(os.tmpdir(), 'cz-old-'));
  const oldCtx = await chromium.launchPersistentContext(oldProfile, opts);
  const stuck = oldCtx.pages()[0] || await oldCtx.newPage();
  stuck.on('pageerror', (e) => errors.push(String(e)));
  await stuck.goto(url, { waitUntil: 'load', timeout: 90000 });
  await stuck.waitForSelector('canvas', { timeout: 90000 });
  await stuck.evaluate(async () => {
    await navigator.serviceWorker.ready;
    for (let i = 0; i < 60 && !navigator.serviceWorker.controller; i += 1) {
      await new Promise((r) => setTimeout(r, 500));
    }
  });
  const helpless = await stuck.evaluate(() => ({
    controlled: !!navigator.serviceWorker.controller,
    canAsk: typeof window.__cz_update_ready === 'function',
  }));
  checks.push(['the old client is controlled by a worker', helpless.controlled,
    String(helpless.controlled)]);
  checks.push(['and its page cannot ask for an update', !helpless.canAsk,
    helpless.canAsk ? 'it still has the hooks — the test is not testing this'
      : 'no update hooks, as an old install']);

  // Now publish a current build over the top — and do NOT reload. This is the
  // distinction the previous version of this check missed and passed anyway: a
  // reload releases the old client, which lets even an unpatched worker
  // activate, so the test healed for a reason that had nothing to do with the
  // fix. Reopening an installed app on a phone usually *resumes* the existing
  // client rather than navigating, so the worker never gets that opportunity —
  // which is exactly why a real install stayed on 0.7.0 while this test went
  // green.
  //
  // So the assertion is on the mechanism: with the client still open, does the
  // newly installed worker take over, or is it left sitting in "waiting"?
  at('publishing under a client that stays open');
  fs.writeFileSync(pageHtml, current);
  fs.writeFileSync(MARK, 'BUILD-NEW');
  fs.writeFileSync(swFile, fs.readFileSync(swFile, 'utf8')
    .replace(/const CACHE_VERSION = '[^']*'/, "const CACHE_VERSION = 'verify-update-new'"));

  const took_over = await stuck.evaluate(async () => {
    const reg = await navigator.serviceWorker.getRegistration();
    let sawChange = false;
    navigator.serviceWorker.addEventListener('controllerchange', () => { sawChange = true; });
    for (let i = 0; i < 40; i += 1) {
      await reg.update().catch(() => {});
      await new Promise((r) => setTimeout(r, 500));
      if (!reg.waiting && (reg.active || sawChange)) {
        // Nothing queued behind us: either it never needed to wait, or it
        // stepped over the open client the way an installed app needs it to.
        if (sawChange) { return { stuck: false, why: 'the worker took over' }; }
      }
      if (reg.waiting) {
        // Keep going: it may still skip. Record that it got as far as waiting.
        continue;
      }
    }
    const reg2 = await navigator.serviceWorker.getRegistration();
    return {
      stuck: !!reg2.waiting,
      why: reg2.waiting
        ? 'a new worker is installed but left waiting behind the open client'
        : 'no worker left waiting',
    };
  });
  checks.push(['the new worker does not queue behind an open client',
    !took_over.stuck, took_over.why]);
  await oldCtx.close();
  fs.rmSync(oldProfile, { recursive: true, force: true });

  checks.push(['no page errors', errors.length === 0,
    errors.length ? errors.join('; ') : 'none']);

  if (shot) await page.screenshot({ path: shot }).catch(() => {});
  await ctx.close();
  fs.rmSync(profile, { recursive: true, force: true });

  console.log('--- an update reaches a player who already has it ---');
  for (const [name, ok, detail] of checks) {
    console.log(`${ok ? 'PASS' : 'FAIL'}  ${name.padEnd(32)} ${detail}`);
  }
  const ok = checks.every((c) => c[1]);
  console.log(`VERDICT                               : ${ok ? 'PASS' : 'FAIL'}`);
  process.exit(ok ? 0 : 1);
})().catch((err) => {
  // Without this a rejection ends the process with nothing on stdout, which
  // reads exactly like a test that hung.
  console.log(`FAIL  threw while: ${stage}`);
  console.log(String((err && err.stack) || err).split('\n').slice(0, 4).join('\n'));
  console.log('VERDICT                               : FAIL');
  process.exit(1);
});
