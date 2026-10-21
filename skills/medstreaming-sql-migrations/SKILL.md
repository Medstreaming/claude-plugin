---
name: medstreaming-sql-migrations
description: 'Write, name, register and validate SQL migration scripts in the MedStreaming pacs repo. Covers the sql/ folder and sql/_scripts.txt execution manifest, Task_<id>_ naming, re-runnable IF NOT EXISTS patterns for tables, columns, constraints, indexes and views, multi-script ordering and dependencies, and a reserved-keyword audit that catches names like LineNo (LINENO) before they reach a server. Use when adding a table, column, view, stored procedure, index or seed data, or when a migration fails with "Incorrect syntax near".'
argument-hint: 'What the migration creates or changes, and the task/bug number'
---

# SQL migrations (pacs)

## Conventions

| Rule | Detail |
|---|---|
| Location | `sql/` at repo root. Version folders (`sql/v5.4/`) exist but new work goes in `sql/`. |
| Naming | `Task_<id>_<Subject>.sql` or `Bug<id>_<Subject>.sql`. Multi-script features add a two-digit order: `Task_38396_01_…`, `Task_38396_02_…` |
| Registration | **Append to `sql/_scripts.txt`.** This is the execution manifest — an unregistered script never runs. Order in the file is the order of execution. |
| Header | First line a comment naming the task and what the script does |
| Batches | `USE [medstreaming]` then `GO`; `GO` after each `IF` block |
| Re-runnable | Every script must be safe to run twice. Nothing may fail on a second pass. |

Dependencies matter: a script creating a view over a table added by an earlier script must be
registered *after* it, and should say so in its header.

## Idempotent patterns

```sql
-- table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[X]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[X] ( ... )
END
GO

-- column
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[X]') AND name = 'NewCol')
    ALTER TABLE [dbo].[X] ADD [NewCol] int NULL
GO

-- default constraint
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_X_IsDeleted]') AND type = 'D')
    ALTER TABLE [dbo].[X] ADD CONSTRAINT [DF_X_IsDeleted] DEFAULT ((0)) FOR [IsDeleted]
GO

-- index
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_X_Y' AND object_id = OBJECT_ID(N'[dbo].[X]'))
    CREATE NONCLUSTERED INDEX [IX_X_Y] ON [dbo].[X] ([Y]) INCLUDE ([Z])
GO

-- view / proc: drop and recreate is the re-runnable form
IF OBJECT_ID(N'[dbo].[vwX]', N'V') IS NOT NULL DROP VIEW [dbo].[vwX]
GO
CREATE VIEW [dbo].[vwX] AS SELECT ...
GO

-- seed data: the INSERT must sit directly inside an IF NOT EXISTS (see checker Rule 2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[X] WHERE [A] = 'a')
BEGIN
    INSERT INTO [dbo].[X] ([A], [B]) VALUES ('a', 'b')
END
GO
```

Table conventions used across the schema: `id int IDENTITY(1,1)` PK, plus
`IsDeleted bit` (default 0), `CreationDate datetime` (default `getdate()`), `LastEditDate`,
`InsertUserId`, `UpdateUserId`, `DeleteUserId` where the row is user-maintained.

## The deployment checker rejects some valid T-SQL

A pre-deployment checker parses every script in `sql/` and reports `[SUCCESS]`, `[PARSE]` or
`[WARNING] FILE NOT FOUND` per file. It is stricter than SQL Server: scripts that execute
perfectly can still be rejected. Two rules matter.

### Rule 1 — guard `CREATE` with `IF NOT EXISTS (SELECT ... FROM sys.objects ...)`

`IF OBJECT_ID(...) IS NULL` is **not** accepted as an existence guard around a `CREATE`:

```
[Task_38248_Hl7InventoryCategory.sql] [PARSE] Invalid Condition.
```

```sql
-- REJECTED - "Invalid Condition"
IF OBJECT_ID('dbo.X', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.X ( ... );
END;

-- ACCEPTED
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[X]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[X] ( ... )
END
```

`IF OBJECT_ID(...) IS NOT NULL DROP VIEW ...` (no `BEGIN`/`END`, body is a `DROP`) is fine —
the checker only validates the condition form when it guards a `CREATE`.

### Rule 2 — an `INSERT` must sit directly inside `IF NOT EXISTS`

```
[Task_38248_Hl7InventoryItemStatus.sql] [PARSE] INVALID INSERT STATEMENT: PARENT IS SHOULD BE NotBooleanExpression.
```

"PARENT IS SHOULD BE NotBooleanExpression" means the `IF` wrapping the `INSERT` must be a
**NOT** expression. A `WHERE NOT EXISTS` inside the `INSERT` does not count — the checker does
not look into the `WHERE` clause.

```sql
-- REJECTED - parent IF is a positive EXISTS
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[X]') AND type in (N'U'))
BEGIN
    INSERT INTO [dbo].[X] (...)
    SELECT ... WHERE NOT EXISTS (SELECT 1 FROM [dbo].[X] m WHERE ...)
END

-- ACCEPTED
IF NOT EXISTS (SELECT * FROM [dbo].[X] WHERE [Key] = 'value')
BEGIN
    INSERT INTO [dbo].[X] ([Key], [Val]) VALUES ('value', 'x')
END
```

For multi-row seeds, either emit one guarded `INSERT` per row, or keep the set-based `INSERT`
but wrap it in `IF NOT EXISTS (SELECT 1 FROM [dbo].[X])`.

### `[WARNING] FILE NOT FOUND`

The checker holds its own record of expected scripts. A warning means a file it knows about is
no longer on disk — usually because a script was **renamed** (the old name is still recorded)
or deleted. It does not block deployment, and it is not caused by `_scripts.txt`.

## Reserved keywords — check before you ship

`LINENO` is reserved (the legacy `SET LINENO`). A column aliased `AS LineNo` fails with:

```
Msg 156 ... Incorrect syntax near the keyword 'LineNo'.
Msg 156 ... Incorrect syntax near the keyword 'ORDER'.
```

The second error is the parser cascading after it desyncs — there is only one real fault.
Chasing the second error wastes time.

Other easily-hit reserved words: `KEY`, `FILE`, `PLAN`, `PERCENT`, `PUBLIC`, `RULE`, `USER`,
`VIEW`, `NATIONAL`, `LEFT`, `RIGHT`, `CURRENT`, `SESSION_USER`, `STATISTICS`, `TOP`,
`PRECISION`, `ESCAPE`, `IDENTITY`.

**Prefer renaming over bracketing.** `[LineNo]` works, but every future query against the
object needs the brackets and someone will forget. `LineNumber` needs nothing.

Run the audit before handing a script over:

```powershell
powershell -File .\.github\skills\medstreaming-sql-migrations\scripts\Check-SqlReservedWords.ps1 -Path 'sql\Task_38396_*.sql'
```

[Check-SqlReservedWords.ps1](./scripts/Check-SqlReservedWords.ps1) extracts bracketed
identifiers, `AS <alias>` aliases and unbracketed column declarations, and reports any that
collide. `FAIL` means it will not parse; `INFO` means it is bracketed and therefore legal, but
still worth renaming.

Exits `1` when there is anything to fix, so it can gate a build — but only when invoked with
`powershell -File`. Calling it with the `&` operator inside `-Command` does not propagate the
script's exit code to `$LASTEXITCODE`.

## Feature-flag migrations

Flags are DB rows, not config files. Use the `medstreaming-feature-flag` skill.

## Checklist

1. Named `Task_<id>_…`, ordered prefix if part of a set
2. Header comment: task, purpose, and any dependency on an earlier script
3. `USE [medstreaming]` + `GO` batching
4. Every object creation guarded so a re-run is a no-op
5. Checker Rule 1: `CREATE` guarded by `IF NOT EXISTS (SELECT ... sys.objects ...)`, **not** `IF OBJECT_ID(...) IS NULL`
6. Checker Rule 2: every `INSERT` sits directly inside an `IF NOT EXISTS`
7. Reserved-word audit clean
8. **Registered in `sql/_scripts.txt`**, after anything it depends on
9. Executed against a scratch DB twice — second run must be silent
10. Checker reports `[SUCCESS]` for the script
