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

  // Click where the tower stands, then confirm the pixels moved: proof that
  // input, physics and rendering are all live, not just that a page loaded.
  const box = await canvas.boundingBox();
  await page.mouse.click(box.x + box.width * 0.36, box.y + box.height * 0.72);
  await page.waitForTimeout(6000);
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

  const ok = checks.every(c => c[1]);
  console.log(`VERDICT             : ${ok ? 'PASS' : 'FAIL'}`);
  process.exit(ok ? 0 : 1);
})();
