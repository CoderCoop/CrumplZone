// Checks that the exported build is actually installable as an app, and that
// the game notices and offers it.
//
//   node verify-pwa.js <url> <screenshot>
//
// Two things make this harder than it looks, and both were found the hard way:
//
//   * Chrome refuses to offer an install in incognito, and a default Playwright
//     context is incognito. `Page.getInstallabilityErrors` reported exactly
//     that — `in-incognito` — while the build itself was fine. So this runs in
//     a persistent profile.
//   * The install event fires a moment after load, after the game's help
//     screen has already been built. Asking once at startup answered "no"
//     every time, so the button never appeared on a build that was perfectly
//     installable. The game now re-checks, and publishes whether the button is
//     on screen — which is the only way to see inside a game drawn on a canvas.
const { chromium } = require('playwright');
const fs = require('fs');
const os = require('os');
const path = require('path');

const url = process.argv[2];
const shot = process.argv[3];
if (!url) {
  console.error('usage: verify-pwa.js <url> [screenshot]');
  process.exit(2);
}

const args = ['--no-sandbox', '--use-gl=swiftshader', '--enable-unsafe-swiftshader'];
const opts = { args, viewport: { width: 390, height: 844 }, deviceScaleFactor: 2 };
if (process.env.CHROMIUM_PATH) opts.executablePath = process.env.CHROMIUM_PATH;

(async () => {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'cz-pwa-'));
  const ctx = await chromium.launchPersistentContext(profile, opts);
  const page = ctx.pages()[0] || await ctx.newPage();
  const errors = [];
  page.on('pageerror', e => errors.push(String(e)));

  await page.addInitScript(() => {
    window.__saw_prompt = false;
    window.addEventListener('beforeinstallprompt', () => { window.__saw_prompt = true; });
  });
  await page.goto(url, { waitUntil: 'load', timeout: 90000 });
  await page.waitForSelector('canvas', { timeout: 90000 });

  // The game polls for the offer, so give both sides a moment to meet.
  await page.waitForTimeout(14000);

  const cdp = await page.context().newCDPSession(page);
  let installability = [];
  try {
    const result = await cdp.send('Page.getInstallabilityErrors');
    installability = result.installabilityErrors || [];
  } catch (e) {
    installability = [{ errorId: 'check-unavailable: ' + e.message }];
  }
  const manifest = await cdp.send('Page.getAppManifest');
  const state = await page.evaluate(() => ({
    sawPrompt: !!window.__saw_prompt,
    hooks: typeof window.__cz_can_install === 'function',
    canInstall: window.__cz_can_install ? window.__cz_can_install() : false,
    buttonShown: window.__cz_install_button === true,
    serviceWorkers: navigator.serviceWorker ? 1 : 0,
  }));
  if (shot) await page.screenshot({ path: shot });
  await ctx.close();
  fs.rmSync(profile, { recursive: true, force: true });

  const checks = [
    ['no page errors', errors.length === 0, errors.length ? errors.join('; ') : 'none'],
    ['manifest parses', (manifest.errors || []).length === 0,
      JSON.stringify(manifest.errors || [])],
    ['browser finds it installable', installability.length === 0,
      installability.length ? JSON.stringify(installability) : 'no installability errors'],
    ['install event fired', state.sawPrompt, String(state.sawPrompt)],
    ['the build caught it', state.hooks && state.canInstall,
      `hooks=${state.hooks} canInstall=${state.canInstall}`],
    ['the game offers the install', state.buttonShown, String(state.buttonShown)],
  ];

  console.log('--- installable as an app ---');
  for (const [name, ok, detail] of checks) {
    console.log(`${ok ? 'PASS' : 'FAIL'}  ${name.padEnd(28)} ${detail}`);
  }
  const ok = checks.every(c => c[1]);
  console.log(`VERDICT                           : ${ok ? 'PASS' : 'FAIL'}`);
  process.exit(ok ? 0 : 1);
})();
