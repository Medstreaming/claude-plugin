---
name: code-review-task
description: 'Code-review every git revision of an Azure DevOps task from just its number: find all commits whose message references the task (Task/Bug/TASK <id>, incl. merged PRs and copies on other branches), group duplicate ports by patch-id, run /code-review on each distinct change, verify the findings, and save a prioritized CODE_REVIEW_Task_<id>_<Title>.md plus a standalone HTML twin in <repo>\Task_<id>\. Use when the user types /med:code-review-task <id> or asks to "review task <id>" / "code review all revisions of <id>".'
argument-hint: '<work item number>, e.g. 38277  [low|medium|high|xhigh|max]'
---

# /med:code-review-task <id> [level]

The first argument is the Azure DevOps work item number (no number → ask for it). An optional second argument is the
`/code-review` effort level; pass it through unchanged (omit it → `/code-review` reuses its last level).
This is a **read-only review**: never edit source code, switch branches, stash, or commit. The only files you write are the
two review documents in `${user_config.task_folder}\`.

## 1. Work item context

- Repo root = `git rev-parse --show-toplevel`.
- Read the work item: `az boards work-item show --id <id> --org ${user_config.ado_org_url} --expand all`
  (`az login --allow-no-subscriptions` if needed). Keep the title, description, and acceptance criteria. Reviewers check the
  code against these, so a missing acceptance criterion counts as a finding.
- If az is unavailable, take the title from the commit subject and say that the work item was not read.
- If `<root>\${user_config.task_folder}\PLAN_Task_<id>_*.md` exists (from /med:plan-task), read it too. Deviations from the plan's decisions are findings.

## 2. Find every revision of the task

- `git fetch --all --prune` only if the user agrees or remotes are clearly stale. Otherwise use what is local.
- `git log --all --format="%H|%h|%ad|%an|%s" --date=short -i -E --grep="(task|bug)[ _#:-]*<id>\b"`
  and also `--grep="PR [0-9]+: *(Task|Bug) <id>\b"`. Drop false positives such as SVN messages like `*r<id>` that only
  share the digits.
- For each commit, list the branches that contain it (`git branch -a --contains <sha> | head`).
- **Group duplicates.** For each commit, compute per-file `git diff <sha>^ <sha> -- <file> | git patch-id` over the files it
  touches. Commits whose patch-ids match (cherry-picks or ports to `Integ_Staging` and similar) form one *change*. Record which files
  differ, for example a copy that is missing a `.csproj` edit. Merge commits: review against the first parent (`<sha>^1`).
- If two or more distinct changes are on the same branch (follow-up fixes), also note the combined range for context.
- If nothing is found, report that and stop. Do not review the working tree instead.

## 3. Review each distinct change

- For each distinct change, invoke the `code-review` skill on one representative commit (args: `revision <sha> [level]`).
  If several are independent, start them together and wait for every result. Never invent a pending result.
- **Verify every finding yourself** before writing it down. Open the cited file and line at that revision
  (`git show <sha>:<path>`), and confirm that the failure scenario is real. Drop any finding you cannot confirm. Mark a finding
  "plausible" when it depends on runtime or database data you cannot see.
- Apply each finding to every copy of the change. A finding that exists only in one copy (for example a file the other copy lacks)
  says which revision it applies to.
- Also check against step 1: acceptance criteria that are not implemented, SQL script rules (`medstreaming-sql-migrations`:
  re-runnable, registered in `sql/_scripts.txt`), feature-flag rules (`medstreaming-feature-flag`), and the CLAUDE.md
  gotchas (no `bin\`, local `.csproj` or `build*.bat` tweaks).

## 4. Write the review document

File: `<root>\${user_config.task_folder}\CODE_REVIEW_Task_<id>_<Title_with_underscores>.md`, where the title comes from the work item and unsafe path
characters are removed. If a review file already exists, read it first: keep its status notes for findings that are still present,
mark findings that are gone as **Fixed in <sha>**, and add new ones.

Layout (match `Task_38277\CODE_REVIEW_Task_38277_*.md`):

1. `# Code review — Task <id>: <Title>` and a one-line summary (number of findings, ordered by priority, fixed or not).
2. `## Revisions reviewed`: a table with Revision | Author / date | Branch | Notes, including the duplicate/port groups from step 2.
3. `## Summary`: a table with # | Priority | Area | Finding.
4. `## High priority`, `## Medium priority`, `## Low priority`. Each finding is a `### n. <title>` with **File** (`path:line`),
   **Problem**, **Impact** (the concrete failure scenario), and **Fix**.
   - High: data loss or corruption, wrong clinical data, crashes, or availability problems, config reset on upgrade, security.
   - Medium: wrong results in edge cases, concurrency, silent failures, API/contract issues.
   - Low: scope or hygiene, dead code, duplication, style.
5. `## Next steps`: what to fix before merging to `200912_integ`, which other branches also need the fix, and what was **not**
   verified (no build, no live DB or service run unless you actually did one).

Then generate the HTML twin:
`& "${CLAUDE_PLUGIN_ROOT}\skills\plan-task\md-to-html.ps1" -Markdown <review.md> -Kicker "Task <id>" -Badge "Code review"`.

## 5. Report

- Call `ReportFindings` once with the verified findings, most severe first.
- Then give the user a few lines: the revisions reviewed (and duplicates), counts by priority, the top issues, and the paths to the .md and .html files.
- Offer to fix the High findings. Do not start fixing unless the user asks.

