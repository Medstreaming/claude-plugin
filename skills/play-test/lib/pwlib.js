// Helper for /play-test specs. Requires the `playwright` package (resolved through NODE_PATH).
const path = require('path');
const fs = require('fs');
const { execFileSync } = require('child_process');
const { chromium } = require('playwright');

const OUT = process.env.PLAY_OUT || process.cwd();
const SHOTS = path.join(OUT, 'screenshots');
const PROFILE = path.join(process.env.LOCALAPPDATA || OUT, 'play-test', 'edge-profile');
fs.mkdirSync(SHOTS, { recursive: true });
fs.mkdirSync(PROFILE, { recursive: true });

// Stop leftover Edge processes that hold our profile (a locked profile makes Edge exit immediately).
function releaseProfile() {
  try {
    const ps = `Get-CimInstance Win32_Process | Where-Object { @('msedge.exe','chrome.exe') -contains $_.Name -and $_.CommandLine -like '*play-test*edge-profile*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }`;
    execFileSync('powershell.exe', ['-NoProfile', '-Command', ps], { stdio: 'ignore' });
  } catch (_) { /* nothing to stop */ }
}

// Fill a standard username/password sign-in form when MS_USER / MS_PASS are set. Never logs the values.
async function tryAutoLogin(page, timeoutMs) {
  const user = process.env.MS_USER, pass = process.env.MS_PASS;
  if (!user || !pass) return false;
  try {
    const pw = page.locator('input[type=password]').first();
    await pw.waitFor({ state: 'visible', timeout: timeoutMs });
    const un = page.locator('input[type=text]:visible, input[type=email]:visible, input[name*=user i]:visible').first();
    await un.fill(user);
    await pw.fill(pass);
    await page.keyboard.press('Enter');
    console.log('AUTO_LOGIN_SUBMITTED');
    return true;
  } catch (_) {
    console.log('AUTO_LOGIN_FORM_NOT_FOUND - finish the sign-in manually in the Edge window');
    return false;
  }
}

// opts: { url, readyText (RegExp) | readySelector, loginTimeoutMs, viewport }
async function launch(opts) {
  releaseProfile();
  const ctx = await chromium.launchPersistentContext(PROFILE, {
    channel: opts.channel || process.env.PLAY_BROWSER || 'msedge', headless: false, viewport: opts.viewport || { width: 1600, height: 900 },
  });
  const page = ctx.pages()[0] || await ctx.newPage();
  await page.goto(opts.url);
  const ready = opts.readySelector ? page.locator(opts.readySelector).first() : page.getByText(opts.readyText || /./).first();
  console.log('WAITING_FOR_LOGIN');
  await tryAutoLogin(page, 8000);
  await ready.waitFor({ state: 'visible', timeout: opts.loginTimeoutMs || 480000 });
  await page.waitForTimeout(2500);
  console.log('LOGGED_IN url=' + page.url());
  return { ctx, page };
}

async function shot(page, name) {
  const file = path.join(SHOTS, name.endsWith('.png') ? name : name + '.png');
  await page.screenshot({ path: file });
  return file;
}

// status: 'PASS' | 'FAIL' | 'BLOCKED' | 'NOT RUN' (a boolean is accepted for pass/fail)
function result(id, title, expect, got, status, note) {
  const s = status === true ? 'PASS' : status === false ? 'FAIL' : status;
  const r = { id, title, expect, got, status: s, note: note || '' };
  console.log(`RESULT ${id} ${s} expect=${JSON.stringify(expect)} got=${JSON.stringify(got)} ${r.note}`);
  return r;
}

async function finish(ctx, results) {
  fs.writeFileSync(path.join(OUT, 'results.json'), JSON.stringify(results, null, 2));
  console.log('PLAYTEST_DONE');
  await ctx.close();
}

function fail(e) {
  console.error('ERR ' + (e && e.message ? e.message.split('\n')[0] : e));
  process.exit(1);
}

module.exports = { launch, shot, result, finish, fail, OUT, SHOTS, PROFILE };
