---
name: med-plan-epic
description: Plan an Azure DevOps Epic (or large work item) end to end, from just its number to UI mockups. Read the epic, its children and every reference (other repos/branches/commits, SharePoint docs, local installs/logs); research read-only; ask only the decisions the code cannot settle; then write a STANDALONE plan (own requirements R1..Rn, no POC/other-task references), a small task breakdown (one task per deliverable), and UI mockups built with the target app's real CSS, with a tabbed index viewer. All are saved in <repo>\Task_<id>\ with HTML versions. Use when the user types /med-task-workflow:med-plan-epic <id> or asks to "plan epic <id> with mockups" / "plan to mock".
---

# /med-task-workflow:med-plan-epic <id> [extra references]

Work item numbers live in `${user_config.ado_org_url}` (project `${user_config.ado_project}`). If no number is given, ask for it.
**No product code is written.** The outputs are a reviewed plan, a task breakdown and mockups. Everything goes in `<repo root>\${user_config.task_folder}\`.

Outputs:
| File | What |
|---|---|
| `PLAN_Task_<id>_<Short_Title>.md` + `.html` | Standalone design plan with embedded mockup screenshots |
| `TASKS_Epic_<id>_<Short_Title>.md` + `.html` | Small task breakdown (one task per deliverable) |
| `mockups\index.html` | Tabbed viewer for all mockups |
| `mockups\0N-<name>.html` + `.png` | One page per screen, styled with the real app CSS |
| `mockups\mock-config.js`, `mock-shell.js`, `mock.css` | Shared shell, copied from `assets\` and configured |

## 1. Read the work item and everything it points to
1. **Read the work item:**
   ```bash
   az boards work-item show --id <id> --org ${user_config.ado_org_url} --expand all -o json > "<scratchpad>/wi<id>.json"
   ```
   - If it fails with "run the login command", run `az login --allow-no-subscriptions -o none`, then retry. Do not ask for tokens.
   - Print the fields as plain text (strip HTML, decode entities; drop `WARNING` lines). Read Title, Description, AcceptanceCriteria, ReproSteps, History, Tags, State, and **relations**.
   - **Comments:** run `az devops invoke --org ${user_config.ado_org_url} --area wit --resource comments --route-parameters project=${user_config.ado_project} workItemId=<id> --api-version 7.1-preview -o json`. Always pass `--org`.
2. **Read children and related items the same way, including their comments.** Review comments often carry real requirements, such as "default filter", "add column" or "show rate".
3. **Read the references the user gives:**
   - **Other repos, branches and commits:** `git -C <path> show --stat <sha>`. Look for a local clone under `E:\Git\build\` first.
   - **SharePoint / OneDrive docs:** load `mcp__claude_ai_Microsoft_365__sharepoint_search` + `read_resource` with ToolSearch. If a doc can't be found, list it as an open item and ask for its text.
   - **Local installs, logs and sample data** (e.g. `${user_config.demo_data_folder}`): extract **masked patterns only**, never raw PHI or secrets.
4. **Summarize the item back** in a few bullets: trigger, flow, constraints, named components. Note when the epic text was generated from a *different* codebase. Epics tagged `CreatedByAI` often name classes that don't exist in the target repo.

## 2. Research (read-only)
- **Read the repo's guidance:** `.github/instructions/*` and any repo skills.
- **Launch up to 3 Explore agents in parallel**, each with a narrow focus, a word limit, and a request for file:line evidence plus "what the work item assumes that does not exist". Typical focuses:
  - (a) the reference / POC implementation and its weaknesses;
  - (b) the target app: UI tech, page/card/table patterns, API, data layer, migrations, roles, feature flags, alerting, docs/tests conventions;
  - (c) the observed / integration system: real processes, folders, logs, config flags, supervisors.
- **Verify the 2–3 most important findings yourself** with targeted greps before relying on them.
- **When logs or data formats matter, profile real samples.** Normalize digits, paths and quotes, then count line patterns. Confirm markers, noise, file naming and rollover from the code that writes them.

## 3. Ask only what the code cannot settle
Use AskUserQuestion: at most 4 questions, recommended option first with "(Recommended)". Typical questions:
- where the work runs (an existing agent or service vs. a new one);
- what the source of truth is;
- PHI / storage policy;
- scope boundaries (control actions, outbound, etc.).

If the user says "do your recommendation", adopt the defaults and record them as decisions.

## 4. Write the standalone plan
**Rule: the plan stands alone.**
- Gather data from POCs, other tasks, commits and docs, but **restate it as this plan's own requirements and design**.
- Never cite the POC, its branch or commits, other work-item IDs, or source documents.
- Citing real code in the target repo or the observed system (file:line) is fine.
- Before finishing, grep the plan for `POC|commit|SharePoint|Task \d|Bug \d` and other IDs to catch leftovers.

Sections:
1. **Context**
   - Problem.
   - **Requirements R1..Rn** (table) and out-of-scope.
   - Design decisions confirmed with the user (dated).
   - What exists in the target repo: a reuse table of concern → existing code with file:line.
   - How the observed system works (diagram in a code block, evidence, and what real samples show).
2. **Approach**
   - Target architecture (ASCII diagram) and design principles.
   - Status / data model.
   - Phased implementation: numbered steps, each with file, behaviour and reused code.
   - Threshold / config defaults table and role matrix when relevant.
   - **2.x UI mockups**: one subsection per mockup with requirements and steps, bullets, and the embedded PNG `![caption](mockups/0N-name.png)`. Tell readers to open `mockups/index.html`.
3. **Files**: new and modified tables, including the mockups folder as reference-only.
4. **Verification**
   - Unit tests.
   - Build order.
   - An end-to-end script `${user_config.task_folder}/Verify-*.ps1` with numbered scenarios, plus replay/perf runs when real samples exist.
   - A requirement and acceptance-criteria → step/test mapping table.
5. **Docs**: following the repo's docs conventions.
6. **Open items**: only what is truly open; resolved items move into Context.

**Never claim runtime verification that hasn't happened.**

## 5. Write the task breakdown
`TASKS_Epic_<id>_<Short_Title>.md`:
- **Few tasks, one per deliverable** (usually 3–5).
- **Each task ends with something a user can see and test**, ships behind the feature flag, and carries its own tests and docs. No separate "foundation", "tests" or "docs" tasks.
- **Overview table:** #, task, deliverable, requirements, plan steps, estimate (SP), depends on. Add an order / sprint sketch.
- **Per task:** deliverable, scope, numbered testable acceptance criteria, verification.
- **Shared sections:** a definition of done that applies to every task, and an open items → affected task table.

Do **not** create work items in Azure DevOps unless the user asks.

## 6. Build the UI mockups
1. **Find the real app shell.** Locate its layout (sidebar, header, user block), main stylesheet, icon font and web font. Note card / table / badge / tab / modal class names and the CSS variables. Mockups must use these, so they look like the product.
2. **Copy the assets** `assets\mock-shell.js`, `assets\mock.css` and `assets\index.html` into `${user_config.task_folder}\mockups\`. Create `mock-config.js` from `assets\mock-config.sample.js`:
   - app name, nav items (mark new ones `isNew`), user and role, context selector;
   - the pages list `{file, name, meta, req, desc}`.
3. **Write one page per key screen,** usually 4–6: the dashboard entry point, the main page, the list/grid, the detail drawer, and an action dialog. Each page:
   - `<head>`: links to the **real** CSS, fonts and icons by relative path (e.g. `../../<WebProject>/wwwroot/css/site.css`), then `mock.css`, then `mock-config.js`.
   - `<meta name="mock-size" content="1600,1300">`: the screenshot window size (width,height). Make the height fit the whole page.
   - `<body data-page="<nav id>" data-title="…" data-crumb="…" data-role="…">` with `<div id="content">…</div>`, then `<script src="mock-shell.js"></script>`.
   - The app's own classes. Add only missing bits to `mock.css`.
   - **Fictional, masked data only.** Identifiers look like `J*** D**` and `****1234`; raw samples use `DOE^JANE` / `TEST-` ids.
   - Purple numbered markers `<span class="mk-note">N</span>` on key elements, and a `<div class="mk-legend"><b>Vision notes</b><ol>…</ol></div>` explaining each one (requirement, data source, role).
   - Show the important **states**: empty / warning / critical / unavailable / not configured / role-restricted.
   - Charts use the inline-SVG helpers `mkSpark`, `mkLines` and `mkRing` from `mock-shell.js`. No chart library is needed.
   - Overlays (drawer, modal) use `static-overlay`, `static-drawer` and `static-modal`. Keep the legend clear of the dialog.
4. **Screenshot all pages:**
   ```powershell
   & "${CLAUDE_PLUGIN_ROOT}\skills\med-plan-epic\assets\shoot-mockups.ps1" -Folder "<repo>\${user_config.task_folder}\mockups"
   ```
   It uses headless Edge and each page's `mock-size`. `-Only 3,6` re-shoots selected pages. **Look at every PNG** with Read and fix overflow, clipping, wrapping, or legends overlapping content. Also check the viewer, which is narrower: `-Index 1,3` shoots `index.html#N`. The viewer frame is about 1485 px wide, so give multi-column layouts a `@media (max-width:1520px)` compact rule and `overflow-x:auto` on wide tables. Fix a page by rewriting a whole block rather than with regex surgery. Re-shoot after fixes.
5. **Embed the PNGs in the plan** (§2.x) and list the mockups folder under §3 Files.

## 7. Generate the HTML versions and check them
```powershell
& "${CLAUDE_PLUGIN_ROOT}\skills\med-plan-task\md-to-html.ps1" -Markdown "<repo>\${user_config.task_folder}\PLAN_Task_<id>_<Title>.md" -Kicker "Epic <id>"
& "${CLAUDE_PLUGIN_ROOT}\skills\med-plan-task\md-to-html.ps1" -Markdown "<repo>\${user_config.task_folder}\TASKS_Epic_<id>_<Title>.md" -Kicker "Epic <id>"
```
- The converter inlines local images as base64, so each HTML is a single file. Never hand-edit the HTML; fix the Markdown and regenerate.
- Check the result renders by screenshotting a cut-down copy of the mockups section. Expect a plan HTML with five mockups to be around 1.5–2 MB.

## 8. Hand over
Give the paths (plan .md/.html, tasks .md/.html, `mockups\index.html`) and a short outline:
- requirements;
- decisions;
- phases / tasks with estimates;
- what each mockup shows;
- open items.

Wait for review. When implementation lands later (`/med-task-workflow:med-implement-task`), append "Verified results" to the plan and regenerate.

