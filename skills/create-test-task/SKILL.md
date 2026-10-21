---
name: create-test-task
description: 'Create an Azure DevOps "Test Task" for a main work item: read the main task, generate test cases from its description and acceptance criteria, show them as a table for Approve/Edit/Cancel, then (only after approval) create "Verify Task <id>: <title>" with description "Verify" + the main description, link it to the main task as Related, and post the test cases as a Discussion comment table. Use when the user types /med:create-test-task <id> or asks to "create a test task for <id>".'
argument-hint: '<main work item number>, e.g. 38277'
---

# /med:create-test-task <main-task-id>

The argument is a work item number in `${user_config.ado_org_url}` (project `${user_config.ado_project}`). If none is given, ask for it.
Nothing is created in Azure DevOps until the user explicitly approves the test cases.

## 1. Read the main task

```bash
az boards work-item show --id <id> --org ${user_config.ado_org_url} --expand all -o json > "<scratchpad>/wi<id>.json"
```

- If it fails with "run the login command", run `az login --allow-no-subscriptions -o none` (browser sign-in), then retry. Never ask for tokens.
- Read as plain text (strip HTML, decode entities) with PowerShell `ConvertFrom-Json`: `System.Title`, `System.Description`,
  `Microsoft.VSTS.Common.AcceptanceCriteria`, `Microsoft.VSTS.TCM.ReproSteps` (bugs), `System.WorkItemType`, `System.Tags`.
  If `System.CommentCount` > 0, also read the comments
  (`az devops invoke --area wit --resource comments --route-parameters project=${user_config.ado_project} workItemId=<id> --org ${user_config.ado_org_url} --api-version 7.1-preview -o json`)
  — they often hold clarified requirements.
- Check the main task's `relations` for an existing Related item titled `Verify Task <id>: ...`. If one exists, tell the user and ask
  before creating a duplicate.

## 2. Generate test cases

Derive them from the description, acceptance criteria and clarifying comments — cover every acceptance criterion at least once, plus
the main negative/edge cases (invalid input, missing permission, empty data, regression of the old behavior) the requirement implies.
Do not invent features the work item does not describe. If useful, glance at the code the task names to get UI labels/paths right.

IDs `TC-01`, `TC-02`, … Steps are numbered and concrete (where to click/what to enter). Expected results are observable.

## 3. Review gate (required)

Show the test cases to the user as a Markdown table:

| Test Case ID | Title | Preconditions | Steps | Expected Result |
|---|---|---|---|---|

(use `<br>` inside cells for multi-line steps), plus the exact title that will be used: `Verify Task <id>: <main task title>`.

Then ask with AskUserQuestion: **Approve** (create the test task) / **Edit** (user says what to change) / **Cancel**.
- Edit → apply the changes, show the full updated table again, ask again. Loop until Approve or Cancel.
- Cancel → stop; nothing is created.
- Only an explicit Approve proceeds.

## 4. Create, link and comment

Write the approved cases to `<scratchpad>/testcases_<id>.json` as an array of
`{ "Id", "Title", "Preconditions", "Steps", "Expected" }` (plain text; use `\n` between steps), then run:

```powershell
& "${CLAUDE_PLUGIN_ROOT}\skills\create-test-task\new-test-task.ps1" -Org "${user_config.ado_org_url}" -Project "${user_config.ado_project}" -MainId <id> -TestCasesJson "<scratchpad>\testcases_<id>.json"
```

The script (uses an `az` token + `Invoke-RestMethod`; never pass HTML through `az.cmd`, cmd.exe breaks it):
- creates work item type **Test Task** with Title `Verify Task <id>: <main title>`, Description `Verify` followed by the full main
  description HTML, Area/Iteration copied from the main task (required fields), and a **Related** link to the main task — one atomic call;
- posts the test cases as an HTML table in the Discussion (comments API);
- prints `CREATED <newId>` and the work item URL.

Add `-ValidateOnly` to dry-run the create call (server validation, nothing saved) if anything about the main task looks unusual.
If the create succeeds but the comment fails, do not create again — retry only the comment: add `-CommentOnlyOn <newId>`.

## 5. Report

Give the user the new work item id + link, the title, and confirm the Related link and the comment were added
(re-read the new item with `az boards work-item show --id <newId> --expand relations` to verify the link).

