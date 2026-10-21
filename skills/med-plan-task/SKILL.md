---
name: med-plan-task
description: 'Plan an Azure DevOps work item end to end from just its number: read every detail of the work item (description, acceptance criteria, comments, links, attachments) with the az CLI, research the repo read-only, ask only the decisions the code cannot settle, then save PLAN_Task_<id>_<Title>.md plus a standalone HTML twin in <repo>\Task_<id>\. Use when the user types /med-task-workflow:med-plan-task <id> or asks to "plan task <id>" / "make a plan for work item <id>".'
argument-hint: '<work item number>, e.g. 38651'
---

# /med-task-workflow:med-plan-task <id>

The argument is an Azure DevOps work item number in `${user_config.ado_org_url}` (project `${user_config.ado_project}`).
If no number is given, ask for it. Do not write any product code in this command — the output is a reviewed plan.

## 1. Read the whole work item first

```bash
az boards work-item show --id <id> --org ${user_config.ado_org_url} --expand all -o json > "<scratchpad>/wi<id>.json"
```

- If it fails with "run the login command", run `az login --allow-no-subscriptions -o none` (a browser opens; the user signs in),
  then retry. Do not ask for tokens.
- Print the fields as plain text (strip HTML, decode entities) with PowerShell `ConvertFrom-Json`; drop `WARNING` lines first.
  Read **all** of: `System.Title`, `System.Description`, `Microsoft.VSTS.Common.AcceptanceCriteria`, `System.History`,
  `Microsoft.VSTS.TCM.ReproSteps`, `System.Tags`, state/priority/effort, and `relations` (parent/child/related items, attachments,
  linked commits/PRs). If `System.CommentCount` > 1 also run
  `az devops invoke --area wit --resource comments --route-parameters project=${user_config.ado_project} workItemId=<id> --api-version 7.1-preview -o json`.
  Read linked work items the same way when they carry requirements.
- Summarize the item back to the user in a few bullets (trigger, flow, constraints, named components) before researching.

## 2. Research the repo (read-only)

- Read the repo skills that apply (`.github/skills/*/SKILL.md`, e.g. hl7-inbound/outbound, standalone-worker, feature-flag,
  sql-migrations, docs, build) and follow their conventions.
- Launch up to 3 **Explore** agents in parallel, each with a narrow focus and a word limit, typically:
  existing implementation to reuse (with the work item's named classes), the trigger/integration point, and the config/worker/data pattern.
  Ask them for file:line evidence and for anything the work item assumes that does not exist.
- Verify the 2–3 most important findings yourself with a targeted read before relying on them.

## 3. Ask only what the code cannot settle

Use AskUserQuestion (max 4 questions, recommended option first with "(Recommended)"). Typical: ambiguous mapping of a requirement to
a protocol/DB field, reuse-vs-new for an existing path, where background work runs. Do not ask about things you can verify.

## 4. Write the plan

Folder: `<repo root>\${user_config.task_folder}\` (create it). File: `PLAN_Task_<id>_<Short_Title_With_Underscores>.md`.
If plan mode is active, write the plan to the plan-mode file first and copy it into the task folder as soon as editing is allowed.

Sections (concise, scannable):
1. **Context** — problem, what the work item asks, decisions confirmed with the user, key facts from research (with file:line).
2. **Approach** — numbered steps; for each: file to add/change, what it does, existing code reused (path + method).
3. **Files** — new / modified lists (describe repeated patterns once).
4. **Verification** — runnable tests (repo `Tests/Verify*.ps1` style), build order, integration and regression checks mapped to the acceptance criteria.
5. **Docs** — what the medstreaming-docs skill requires for this feature.
6. **Open items** — anything to confirm during the build.
Never claim runtime verification that has not happened.

## 5. Generate the standalone HTML twin

```powershell
& "${CLAUDE_PLUGIN_ROOT}\skills\med-plan-task\md-to-html.ps1" -Markdown "<repo>\${user_config.task_folder}\PLAN_Task_<id>_<Title>.md" -Kicker "Task <id>"
```

It writes the `.html` next to the `.md` (single file, inline CSS/JS from `assets/`, light/dark, sticky contents, copy buttons, print).
Regenerate it every time the Markdown changes; never hand-edit the HTML. Check it renders (e.g. headless Edge screenshot:
`msedge --headless=new --screenshot=<png> file:///<html>`) and fix the Markdown, not the HTML, if something looks wrong.

## 6. Hand over

Give the user both paths and a short outline of the plan, then wait for their review/approval before implementing.
When implementation lands later, append "Verified results" to the Markdown and regenerate the HTML.

