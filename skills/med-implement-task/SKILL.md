---
name: med-implement-task
description: 'Implement an Azure DevOps task from its saved plan: read <repo>\Task_<id>\PLAN_Task_<id>_*.md (written by /med-task-workflow:med-plan-task), re-check the work item, implement step by step following the repo skills, build into the scratchpad, run/extend the Verify*.ps1 tests, self-review, update the feature docs + HTML twins, and append "Verified results" to the plan (then regenerate its HTML). Use when the user types /med-task-workflow:med-implement-task <id> or asks to "implement task <id>" / "build the plan for <id>".'
argument-hint: '<work item number>, e.g. 38651'
---

# /med-task-workflow:med-implement-task <id>

The argument is the Azure DevOps work item number. No number → ask for it.

## 1. Load the plan (stop if it is missing)

- Repo root = the git top level of the current directory (`git rev-parse --show-toplevel`).
- Find `<root>\${user_config.task_folder}\PLAN_Task_<id>_*.md`. If none exists, say so and suggest `/med-task-workflow:med-plan-task <id>`; do not improvise a plan.
  If several match, use the newest and mention the others.
- Read the whole plan: Context, decisions, Approach steps, Files, Verification, Docs, Open items, and any "Verified results"
  (a previous run may have finished some steps — continue from there, do not redo them).
- Re-read the work item (`az boards work-item show --id <id> --org ${user_config.ado_org_url} --expand all`;
  `az login --allow-no-subscriptions` if needed). If acceptance criteria or description changed since the plan, list the
  differences and ask before continuing.
- Check `git status` and the branch. Do not switch branches, stash, or commit unless the user asks.
  Leave unrelated working-tree changes alone and never include them in your edits.

## 2. Resolve open items first

For each item under "Open items", verify it in the code (read-only) and record the answer in the plan. If it changes the design,
or the plan conflicts with what the code really does, stop and ask with AskUserQuestion (recommended option first) instead of guessing.

## 3. Implement, step by step

- Track the plan's Approach steps as a todo list and do them in order; keep each change minimal and in the style of the
  surrounding code (naming, comment density, CRLF line endings for files that use them, project files updated for new `.cs`).
- Follow the repo skills that apply (`.github/skills/*/SKILL.md`: standalone-worker, hl7-inbound/outbound, feature-flag,
  sql-migrations, build, docs …). Reuse the existing helpers the plan names; do not copy code that can be shared.
- Never change behaviour outside the plan's scope; anything extra you notice goes to "Open items" in the plan, not into the code.

## 4. Verify (report real results only)

1. **Tests** — add or extend `<Project>\Tests\Verify<Feature>.ps1` (Add-Type of the real sources, like
   `MedStreaming.JobParser/Tests/VerifyHl7Batch.ps1`) covering each acceptance criterion that can be tested in isolation.
   Run it with Windows PowerShell 5.1: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File <script>`.
2. **Build** each touched project without touching `bin\Release` — compile into the scratchpad:
   `MSBuild <proj> -t:Compile -p:Configuration=Release -p:BuildProjectReferences=false -p:IntermediateOutputPath=<scratchpad>\<name>_obj\`
   (find MSBuild with `vswhere -latest -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe`).
   If a project needs a just-built dependency, copy the needed reference DLLs + the fresh output into a scratchpad `refs` folder and
   build with `-p:OutDir=<refs>\`. Report errors honestly; fix them before continuing.
3. **Self-review** the diff for correctness bugs (races, null/edge cases, encoding, error paths, regressions when the feature is off);
   fix confirmed issues. Offer `/code-review` on the result.
4. State plainly what was **not** verified (e.g. live service, real VNA/DB) — never imply runtime testing that did not happen.

## 5. Docs (medstreaming-docs skill)

Create/update the feature's developer + support runbooks (`.md`) and their standalone HTML twins exactly as the docs skill says.
For new Markdown-only docs you can generate the HTML with
`& "${CLAUDE_PLUGIN_ROOT}\skills\med-plan-task\md-to-html.ps1" -Markdown <md> -Kicker "Task <id>"`; for existing hand-styled HTML twins, update
the stale passages in place so they match the Markdown. Update any repo skill in `.github/skills` that your change makes wrong.

## 6. Close out

- Append to the plan a **Verified results** section: what was implemented (files), test output summary, build result, docs updated,
  what remains unverified, and new open items. Then regenerate the plan HTML:
  `& "${CLAUDE_PLUGIN_ROOT}\skills\med-plan-task\md-to-html.ps1" -Markdown <plan.md> -Kicker "Task <id>"`.
- Give the user a short summary: changed/new files, test and build results, what still needs a live test, and ask whether to commit.
  When committing (only if asked): message `Task <id>: <work item title>`.

