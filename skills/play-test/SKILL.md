---
name: play-test
description: 'Run the test cases of an Azure DevOps task in the real web client with Playwright (Microsoft Edge): read the Verify/test task comments with the az CLI, drive the HTML5 client at http://localhost:4200/WebClient, take a screenshot per test case, and save TEST_RESULTS_Task_<id>.md + standalone HTML twin + results.json + screenshots in <repo>\Task_<id>\test\. Login is either manual (user signs in in the Edge window) or automatic with a username/password. Use when the user types /med:play-test <id> or asks to "play test / run the UI tests for task <id>".'
argument-hint: '<task id> [--user <u> --pass <p> | --manual] [--url <base url>]'
---

# /med:play-test <task-id> [--user <u> --pass <p> | --manual] [--url <base>]

Runs the test cases of work item `<task-id>` (organization `${user_config.ado_org_url}`, project `${user_config.ado_project}`) against the
running web client and records the evidence. Default URL: `${user_config.web_client_url}` (Angular dev server). If the user gives a
different `--url`, use it. If none is given, ask for the task id.

Nothing is written to Azure DevOps (no comments, no state changes) unless the user explicitly asks afterwards.

## 0. Output folder

`<repo root>\${user_config.task_folder}\test\` (create it; repo root = `git rev-parse --show-toplevel`). Everything this skill produces
goes there:

| File | Content |
|---|---|
| `TEST_RESULTS_Task_<id>.md` + `.html` | summary table, per-case result, evidence, defects found, how to re-run |
| `results.json` | machine-readable per-case result (`id, title, expect, got, pass, note`) |
| `screenshots\TC-xx-*.png` | one or more screenshots per test case |
| `play_<id>.js` | the generated Playwright script (so it can be re-run) |
| `data-backup.txt` | only if test data had to be created: original values + the restore statement |

**Never write a username or password into any of these files, into logs or into the script.**

## 1. Login mode (ask once)

Use whatever the arguments say. If neither `--user/--pass` nor `--manual` is given, ask with AskUserQuestion:
**Manual login (Recommended)** — Edge opens, the user signs in; the script waits up to 8 minutes for the app to load, then continues —
or **Username + password** — the script fills the sign-in form itself.

- Credentials are handed to the script **only through the environment variables `MS_USER` / `MS_PASS`** of that one process. Prefer that the
  user sets them with `! $env:MS_USER='...'; $env:MS_PASS='...'` (stays out of the transcript). If they were typed in the arguments, use them
  the same way and do not repeat them in output.
- Automatic login only fills a standard username/password form; if the sign-in page looks different (MFA, SSO), the helper falls back to
  waiting for the user, so tell the user to finish it in the Edge window.
- The Edge profile (session cookies) lives in `%LOCALAPPDATA%\play-test\edge-profile`, outside the repo. A saved session often skips login
  on later runs.

## 2. Get the test cases

```powershell
az boards work-item show --id <id> --org ${user_config.ado_org_url} --expand all -o json
az devops invoke --area wit --resource comments --route-parameters project=${user_config.ado_project} workItemId=<id> --org ${user_config.ado_org_url} --api-version 7.1-preview -o json
```

(use PowerShell `ConvertFrom-Json`; first run `az login --allow-no-subscriptions` if it asks; never ask for tokens.)

- If `<id>` is a **Test Task** (`Verify Task <main>: ...`), its Discussion comment table (`TC-01 | Title | Preconditions | Steps | Expected`)
  is the test-case list.
- If `<id>` is the **main task**, find its Related work item titled `Verify Task <id>: ...` and read that item's comments.
- If no test cases exist, say so and offer `/med:create-test-task <id>` — do not invent cases silently.
- Also read the main task's description/technical notes (UI labels, element ids such as `ddl...`, impacted components) and, if present,
  `${user_config.task_folder}\PLAN_Task_<id>_*.md`, to learn selectors and expected behavior.

## 3. Prepare

1. Confirm the app answers: `Invoke-WebRequest <url>/` (the Angular dev server serves the SPA at the **root** `http://localhost:4200/`; the
   page then routes to `/WebClient`). If it is down, tell the user; do not start servers without asking.
2. Install the runner once (skip if present):
   ```powershell
   $r = "$env:LOCALAPPDATA\play-test\runner"; New-Item -ItemType Directory -Force $r | Out-Null
   if (-not (Test-Path "$r\node_modules\playwright")) { Push-Location $r; npm init -y | Out-Null; npm install playwright@1.49.1; Pop-Location }
   ```
   Uses the installed browser (`channel: '${user_config.browser_channel}'`: `msedge` is Microsoft Edge), so no browser download is needed.
3. **Test data.** If a case needs data that does not exist (check read-only first, e.g. `sqlcmd -S ${user_config.sql_server} -E -d ${user_config.sql_database} -Q "SELECT ..."`),
   tell the user exactly which rows you would change and **ask before any write**. After approval: save the original values to
   `data-backup.txt` first, change only those rows, and at the end ask whether to restore them. Never touch other rows or the schema.
   Writes via `sqlcmd` may need a permission rule in `.claude/settings.local.json`; ask the user rather than working around a denial.

## 4. Write and run the script

Write `${user_config.task_folder}\test\play_<id>.js` using the helper `${CLAUDE_PLUGIN_ROOT}\skills\play-test\lib\pwlib.js`:

```js
const lib = require('${CLAUDE_PLUGIN_ROOT}/skills/play-test/lib/pwlib.js');
(async () => {
  const { ctx, page } = await lib.launch({ url: '${user_config.web_client_url}', readyText: /advanced/i });
  const results = [];
  // ... one block per test case:  drive the UI, lib.shot(page, 'TC-01-name'), results.push(lib.result('TC-01', 'title', expect, got, pass, note))
  await lib.finish(ctx, results);          // writes results.json, closes Edge (never leaves it open)
})().catch(e => lib.fail(e));
```

Run it from PowerShell **in the background** and watch only its own output file:

```powershell
$env:NODE_PATH = "$env:LOCALAPPDATA\play-test\runner\node_modules"; $env:PLAY_BROWSER = "${user_config.browser_channel}"; $env:PLAY_OUT = "<repo>\${user_config.task_folder}\test"; node "<repo>\${user_config.task_folder}\test\play_<id>.js"
```

Use Monitor on **that run's output file only** (a `tail -f <file> | grep -E "^RESULT|^ERR|DONE"`); never glob the tasks folder, stale outputs
from earlier runs will match. While waiting for a manual login, tell the user to sign in in the Edge window.

### Rules learned the hard way (follow them)

- **One browser at a time.** The persistent profile is locked while Edge runs; `lib.launch` stops leftover automation Edge/node processes that
  use the profile. If a launch still dies instantly ("browser has been closed"), a previous run is still open — stop it, rerun.
- **Selectors:** the client reuses ids — e.g. `#AdvancedSearch` matches 3 elements. Scope to the real container
  (`div.ms-dialog-container#AdvancedSearch`) and use roles/labels. Comboboxes are `ms-combobox`; click it, type in the visible
  `Search...` box, then click the item **inside that popup** (`box.locator('xpath=ancestor::*[6]')`); popups from earlier picks stay in the DOM.
  If an element is missing, dump `ms-combobox` ids / take a screenshot **before** changing selectors again — do not guess repeatedly.
- **Verify by data, not by looks:** exam list footer `(N items)` plus patient names of known rows give exact expected results.
- A case that cannot be run through the UI because of a **pre-existing bug** is `BLOCKED`, not `FAIL`: find the cause in the code, cite
  file:line, check with `git log -S` / `git show <commit>^:<file>` whether it predates the task, and report it as a separate defect.
- Don't change app source code in this skill; it only observes.

## 5. Results

Use PASS / FAIL / BLOCKED / NOT RUN with a one-line reason for anything not PASS. Write `TEST_RESULTS_Task_<id>.md`
(title, date, URL, login mode used — never the credentials —, summary table, per-case evidence with screenshot links, defects found
with file:line, data created/restored, how to re-run), then the HTML twin:

```powershell
& "${CLAUDE_PLUGIN_ROOT}\skills\plan-task\md-to-html.ps1" -Markdown "<repo>\${user_config.task_folder}\test\TEST_RESULTS_Task_<id>.md" -Kicker "Task <id> tests"
```

Finish by telling the user the folder, the PASS/FAIL/BLOCKED counts, any defects, and whether test data still needs restoring.
Offer (do not do) to post the results as a comment on the work item.

