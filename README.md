# med

Claude Code plugin for the MedStreaming Azure DevOps task workflow. Every skill takes a work item number.

| Command | What it does |
|---|---|
| `/med:plan-epic <id>` | Plan an epic: requirements, task breakdown and UI mockups |
| `/med:plan-task <id>` | Research the repo and save a plan (Markdown + HTML) |
| `/med:implement-task <id>` | Implement the saved plan, build, verify, update docs |
| `/med:code-review-task <id>` | Review every git revision that references the task |
| `/med:create-test-task <id>` | Generate test cases and create the linked Verify task |
| `/med:play-test <id>` | Run the test cases in the real web client with Playwright |
| `/med:medstyle-presentation <topic>` | Build a Medstreaming-branded slide deck (logo, palette, house layouts) |

## Bundled repo skills

The workflow skills refer to three MedStreaming repo skills, so they are bundled and the plugin works on its own:
`medstreaming-docs`, `medstreaming-sql-migrations`, `medstreaming-feature-flag`. They are copies from the pacs repo's
`.github/skills`; if the repo versions change, refresh the copies here.

## Install

```
/plugin marketplace add https://github.com/Medstreaming/claude-plugin
/plugin install med@medstreaming
```

When the plugin is enabled Claude Code asks for the settings below; press Enter to accept each recommended default.
Change them later in `/config`.

| Setting | Default |
|---|---|
| Azure DevOps organization URL | `https://dev.azure.com/medstreaming2` |
| Azure DevOps project | `Medstreaming` |
| Task output folder (under repo root; `<id>` = work item number) | `Task_<id>` |
| Web client URL (play-test) | `http://localhost:4200/WebClient` |
| Browser for play-test | `msedge` |
| Local demo-data folder (plan-epic) | `C:\Medstreaming\demomode` |
| SQL Server instance / database (play-test) | `.` / `MedStreaming` |

## Prerequisites (not checked at install)

- Azure CLI with the DevOps extension, signed in: `az login --allow-no-subscriptions`
- Git; MSBuild and `sqlcmd` for implement-task and play-test
- Microsoft Edge (or Chrome); Node.js for play-test (Playwright is installed on first run)
- Windows PowerShell (helper scripts are `.ps1`)
