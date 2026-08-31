// Checks that an exported web build actually runs when served from a host
// that sets no cross-origin isolation headers — the GitHub Pages situation.
//
// A Godot web build with threads enabled needs COOP/COEP headers, which Pages
// cannot send. Threads are off in export_presets.cfg for exactly that reason,
// and this is what stops that setting from silently regressing: a threaded
// build would load and then fail here rather than in someone's browser.
//
//   node verify-web-export.js <url> <screenshot-prefix>
//
// Set CHROMIUM_PATH to use a specific browser binary.
const { chromium } = require('playwright');
const fs = require('fs');

const url = process.argv[2];
const out = process.argv[3];
if (!url || !out) {
  console.error('usage: verify-web-export.js <url> <screenshot-prefix>');
  process.exit(2);
}

const launch = { args: ['--no-sandbox', '--use-gl=swiftshader', '--enable-unsafe-swiftshader'] };
if (process.env.CHROMIUM_PATH) launch.executablePath = process.env.CHROMIUM_PATH;

(async () => {
  const browser = await chromium.launch(launch);
  const page = await browser.newPage({ viewport: { width: 900, height: 700 } });

  const errors = [];
  const logs = [];
  page.on('console', m => logs.push(`${m.type()}: ${m.text()}`));
  page.on('pageerror', e => errors.push(String(e)));

  await page.goto(url, { waitUntil: 'load', timeout: 90000 });
  await page.waitForSelector('canvas', { timeout: 90000 });
  await page.waitForFunction(
    () => { const c = document.querySelector('canvas'); return c && c.width > 0 && c.height > 0; },
    { timeout: 90000 });
  // Godot boots asynchronously; give the engine time to reach first frame.
  await page.waitForTimeout(8000);

  const env = await page.evaluate(() => ({
    crossOriginIsolated: self.crossOriginIsolated,
    sharedArrayBuffer: typeof SharedArrayBuffer !== 'undefined',
  }));

  const canvas = page.locator('canvas');
  const box = await canvas.boundingBox();
  const click = async (fx, fy, settle) => {
    await page.mouse.click(box.x + box.width * fx, box.y + box.height * fy);
    await page.waitForTimeout(settle);
  };

  // Dismiss the intro screen before measuring anything. It covers the level
  // and swallows clicks, so without this the input check sees no change and
  // reports a working build as broken — which is exactly what it did the first
  // time the intro shipped.
  //
  // Play is pinned a margin up from the bottom of the screen and is full
  // width, so its position follows from the layout rather than from a
  // screenshot: intro.gd puts its centre PLAY_HEIGHT/2 + MARGIN above the
  // bottom edge, in CSS pixels, which is what boundingBox reports.
  const PLAY_CENTRE_FROM_BOTTOM = 52 / 2 + 16;
  await click(0.5, 1 - PLAY_CENTRE_FROM_BOTTOM / box.height, 2500);
  await canvas.screenshot({ path: `${out}-before.png` });

  // A build that loaded but never drew shows one flat colour. Sampling
  // distinct colours separates "rendered" from merely "did not throw".
  const colours = await page.evaluate(() => {
    const c = document.querySelector('canvas');
    const tmp = document.createElement('canvas');
    tmp.width = c.width; tmp.height = c.height;
    const ctx = tmp.getContext('2d');
    ctx.drawImage(c, 0, 0);
    const d = ctx.getImageData(0, 0, c.width, c.height).data;
    const seen = new Set();
    for (let i = 0; i < d.length; i += 4 * 97) seen.add((d[i] << 16) | (d[i + 1] << 8) | d[i + 2]);
    return seen.size;
  });

  // Use the tool on the building, then confirm the pixels moved: proof that
  // input, physics and rendering are all live, not just that a page loaded.
  //
  // The camera centres the level horizontally, so the middle column always
  // sits at x = 0.5. Its height on screen depends on the shape of the window,
  // so this walks down the middle instead of guessing one point — a jackhammer
  // that hits nothing costs no move and changes no pixels, which would fail
  // the check for the wrong reason.
  for (const fy of [0.45, 0.52, 0.59, 0.66, 0.73]) {
    await click(0.5, fy, 700);
  }
  await page.waitForTimeout(5000);
  await canvas.screenshot({ path: `${out}-after.png` });
  const changed = !fs.readFileSync(`${out}-before.png`).equals(fs.readFileSync(`${out}-after.png`));

  await browser.close();

  const checks = [
    ['no page errors', errors.length === 0, errors.length ? errors.join('; ') : 'none'],
    ['canvas rendered', colours > 3, `${colours} distinct colours (>3 expected)`],
    ['responds to input', changed, changed ? 'pixels changed after a click' : 'no change after a click'],
  ];

  console.log('--- web export served with no COOP/COEP headers ---');
  console.log(`crossOriginIsolated : ${env.crossOriginIsolated}  (false expected: threads are off)`);
  console.log(`SharedArrayBuffer   : ${env.sharedArrayBuffer}`);
  for (const [name, ok, detail] of checks) {
    console.log(`${ok ? 'PASS' : 'FAIL'}  ${name.padEnd(18)} ${detail}`);
  }
  const noisy = logs.filter(l => /^error/i.test(l));
  if (noisy.length) console.log('console errors      :', noisy.slice(0, 8));
  // On a failure, print what the browser actually said rather than only the
  // lines typed "error". This check went red for five releases saying nothing
  // but "no change after a click", and the cause — the game's first level
  // collapsing on its own before the click landed — prints as an ordinary log
  // line, not an error. A verdict with no evidence behind it costs hours.
  if (!checks.every(c => c[1])) {
    console.log('--- last console lines from the page ---');
    for (const line of logs.slice(-25)) console.log('  ' + line);
    console.log(`--- screenshots: ${out}-before.png, ${out}-after.png ---`);
  }

  const ok = checks.every(c => c[1]);
  console.log(`VERDICT             : ${ok ? 'PASS' : 'FAIL'}`);
  process.exit(ok ? 0 : 1);
})();
