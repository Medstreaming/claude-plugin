---
name: medstreaming-docs
description: 'Write or update MedStreaming pacs project documents: support runbooks, developer runbooks, implementation plans, feature handovers, and workflow sequence diagrams, as Markdown plus a standalone single-file HTML twin. Covers the repo naming conventions (RUNBOOK_<feature>.md/.html, PLAN_<feature>.md, <Feature>.md + <Feature>.Support.md + .Developer.html/.html pairs), the required sections for the support vs developer perspective, what must always be referenced (Server.xml settings, feature flags and restart, queue/error/processed folders, exe names, env vars, SQL script order from sql/_scripts.txt), embedding images/logos inline, and mermaid sequence charts. Use when asked for a runbook, "document for support team", "document for dev team", "2 documents / 4 files", "update the runbook to latest", or to turn a plan into standalone HTML.'
argument-hint: 'Feature name, audience (support / dev / both), and md, html or both'
---

# Project documents (pacs)

Style and HTML mechanics come from the global **`standalone-html-docs`** skill (inline CSS/JS, no
CDN, light/dark, sticky nav, copy buttons, print styles). This skill covers *what goes in* and
*how files are named* in this repo.

## Files and naming

| Kind | Name | Lives in | Twin |
|---|---|---|---|
| Support runbook | `RUNBOOK_<Feature>.md` | repo root, or `<area>/SUPPORT_RUNBOOK.md` | `.html` always |
| Developer runbook | `<Feature>.md` | `<Project>/Tests/` next to the verify script | `<Feature>.Developer.html` |
| Support companion of a dev runbook | `<Feature>.Support.md` | same folder | `<Feature>.html` |
| Plan / design | `PLAN_<Feature>.md` | repo root | none |
| Review | `REVIEW_<shortsha>_Task<id>.md` | repo root | none (see `medstreaming-commit-review`) |

"Two documents for two perspectives" = **four files**: dev `.md` + `.html`, support `.md` + `.html`.
Examples: `MedStreaming.JobParser/Tests/HL7Batch.md`, `HL7Batch.Support.md`, `HL7Batch.Developer.html`,
`HL7Batch.html`; `RUNBOOK_Outbound_Inventory_Depletion_ORM_O01.md/.html`; `mfn/SUPPORT_RUNBOOK.md/.html`.

When asked to "update to latest", regenerate the HTML from the Markdown — never edit only one of the pair.

## Support runbook — required sections

1. **Audience** one line, then a **Quick reference** table: exe name(s), switch, queue root and
   subfolders (`pending/ready/Done/quarantine`, `processed/error`), log prefix, feature switch, restart needed?
2. **What it is** — two short paragraphs, the trigger, and the message/file that goes in or out.
3. **Configuration** — exact `Server.xml` element path (e.g. `Hl7Settings/HL7MultiOrderSplit`),
   DB feature flag SQL (`ConfigProperty/ConfigCombination`) with the **restart required** warning,
   config-file resolution order (`C:\medstreaming\config\...` -> `{StartupPath}\config` -> DB),
   environment variables (e.g. `MATCHA_API_KEY`), and a sample snippet for every file the operator may edit.
   State clearly which files are **editable** and which are **generated**.
4. **Deployment checklist** — numbered; SQL scripts in the order registered in `sql/_scripts.txt`
   with one line on what each creates; which binaries to replace; which services to restart.
5. **Processing flow** — mermaid `sequenceDiagram` or `flowchart` from arrival to final outcome, naming
   the folder at each hop.
6. **Common scenarios** — how to re-run a quarantined file, how to disable the feature safely, what
   "turning it off" does to work already queued.
7. **Diagnostics** — read-only SQL (`SELECT ... FROM Hl7* / ConfigProperty`), log lines to grep for
   (`[HL7Batch]`, `[HL7PreProcessor]:`), expected file counts.
8. **Troubleshooting table** — Symptom | Cause | Action.
9. **Safety & limits** — what was not tested (be explicit: "live service not runtime-tested"), data
   that must not be purged (replay ledgers), known gaps.

## Developer runbook — required sections

Workflow sequence (mermaid), component map with file paths (`Project/Folder/File.cs` + class), state
machine / durability rules, settings and defaults with the class that owns them, test command
(`& .\<Project>\Tests\Verify<Feature>.ps1 [-Stress]`) and sample data used, build notes
(see `medstreaming-build`), files touched checklist, open items.

## Plan — required sections

Goal, analysis of the customer sample (field-by-field table: HL7 field -> model/column -> rule),
decisions (additive vs exclusive flag, gate at creation vs consumption), lookup/creation contract,
files to touch, verification plan, "verified results" appended as work lands.

## Conventions

- No marketing header or logo block when the doc is pasted into a larger report (user asked for
  "no header ... to avoid duplicate"); otherwise embed the logo as a base64 `data:` URI so the HTML stays one file.
- Images referenced from Markdown must be embedded in the HTML twin.
- Tables for anything a reader will scan: settings, folders, scripts, symptoms.
- Mark AI-generated summaries/paragraphs clearly when the user asks for that highlighting.
- Keep file links workspace-relative; cite classes with the owning project.
- Remove scaffolding sections the user rejects ("Small workflow", "Review note:") rather than hiding them.
- Don't claim runtime verification that did not happen; write what was tested and how.
