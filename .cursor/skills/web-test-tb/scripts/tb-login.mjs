const PARAMS_PATH = '/tmp/webtest-tb-params.json';

const { readFileSync } = globalThis;
if (typeof readFileSync !== 'function') {
  throw new Error('readFileSync is not available. Run this via web-test runner (node run.mjs exec ...).');
}

const params = JSON.parse(readFileSync(PARAMS_PATH, 'utf-8'));
const user = params.user;
const pass = params.pass;
if (!user || !pass) throw new Error('Missing user/pass in ' + PARAMS_PATH);

const page = await getPage();

// Robust input: retry + verify (password verified by length).
async function typeExact(selector, value, tries = 5, delay = 35, verify = 'exact') {
  for (let i = 0; i < tries; i++) {
    await page.click(selector);
    await page.keyboard.press('Control+A').catch(() => {});
    await page.keyboard.press('Meta+A').catch(() => {});
    await page.keyboard.press('Backspace');
    await page.keyboard.type(value, { delay });

    const ok = verify === 'len'
      ? (await page.$eval(selector, el => (el.value ?? '').length)) === value.length
      : (await page.$eval(selector, el => el.value ?? '')) === value;

    if (ok) return true;
    await page.waitForTimeout(80);
  }
  return false;
}

await page.waitForSelector('#authWindow_basic_login', { timeout: 60000 });

const okLogin = await typeExact('#authWindow_basic_login', user, 5, 35, 'exact');
const okPass = await typeExact('#authWindow_basic_password', pass, 5, 35, 'len');

if (!okLogin || !okPass) throw new Error('Login input failed (user/pass not stable)');

await page.click('#authWindow_basic_okButton');
await page.waitForSelector('#themesCell_theme_0', { timeout: 20000 });

console.log('OK: logged in');

