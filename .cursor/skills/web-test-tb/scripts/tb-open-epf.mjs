const PARAMS_PATH = '/tmp/webtest-tb-params.json';

const { readFileSync } = globalThis;
if (typeof readFileSync !== 'function') {
  throw new Error('readFileSync is not available. Run this via web-test runner (node run.mjs exec ...).');
}

const params = JSON.parse(readFileSync(PARAMS_PATH, 'utf-8'));
const epfPath = params.epfPath;
if (!epfPath) throw new Error('Missing epfPath in ' + PARAMS_PATH);

const page = await getPage();

// Clear transient overlays/tooltips that may intercept keystrokes/clicks.
for (let i = 0; i < 3; i++) {
  await page.keyboard.press('Escape').catch(() => {});
  await page.waitForTimeout(150);
}

await page.click('body').catch(() => {});
await page.waitForTimeout(100);

// Open 1C file dialog
await page.keyboard.press('Control+o');
await page.waitForSelector('#fileSelectDialogOk', { timeout: 20000 });

// Attach file to hidden input[type=file]
await page.setInputFiles('#fileSelectButton', epfPath);
await page.waitForTimeout(200);

// Click OK via DOM to bypass overlay intercept (surface intercepts pointer events)
await page.evaluate(() => {
  const ok = document.querySelector('#fileSelectDialogOk');
  if (!ok) throw new Error('fileSelectDialogOk not found');
  ok.click();
});

await page.waitForTimeout(2500);

// Security confirmation if shown
const st = await getFormState();
if (st?.errors?.confirmation) {
  // Common positive buttons: "Да" / "Продолжить"
  await clickElement('Да').catch(() => {});
  await clickElement('Продолжить').catch(() => {});
  await wait(2);
}

console.log('OK: EPF open attempted');

