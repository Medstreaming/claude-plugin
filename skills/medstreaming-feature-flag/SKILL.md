---
name: medstreaming-feature-flag
description: 'Add, read, enable, disable, or troubleshoot a feature toggle in the MedStreaming pacs repo. Feature flags are DB rows (ConfigType / ConfigProperty / ConfigCombination) surfaced through a RepositoryLookup helper — not appSettings or Server.xml. Use when asked to make a feature configurable, add an on/off switch, gate new behaviour behind a flag, or work out why a flag set in SQL appears to have no effect (it is cached at startup and needs a restart).'
argument-hint: 'What the flag controls and its default'
---

# Feature flags (pacs)

Flags live in **three DB tables**, not in config files. Reference implementation:
`EnableMDMOutbound` in `sql/v4.12/Bug19147_Make_MDM_compatible_with_SQL_based_messaging.sql`.

| Table | Holds |
|---|---|
| `ConfigType` | The owning component, matched on `TargetComponent` (e.g. `HL7Messaging`, `ExamWorkflow`, `ReportGeneration`, `CommonDesign`, `PlatformIntegration`) |
| `ConfigProperty` | The flag itself: `ShortString` (the name), `TypeString` (`bool`), `Description`, `ConfigTypeId` |
| `ConfigCombination` | The value, per `ConfigId` (1 = default) |

## Procedure

### 1. Migration

Copy [assets/feature_flag.sql](./assets/feature_flag.sql), set the name, description and
`TargetComponent`. **Default new flags to `'False'`** so existing sites are unaffected.
Register the script in `sql/_scripts.txt` — see the `medstreaming-sql-migrations` skill.

### 2. Accessor

Add to `MedStreaming.Common.Repository/RepositoryLookup.cs`, next to the related flags:

```csharp
public static bool IsYourFeatureEnabled()
{
    return RepositoryLookup.ReadConfigProperty<bool>(
        "HL7Messaging", "EnableYourFeature", false, RepositoryConstants.Config_Default, true);
}
```

- Third argument is the fallback when the row is absent — match the seeded default.
- `isFirstRecord: true` (the last argument) is the common pattern for global flags.
- Non-bool flags work too: `ReadConfigProperty<string>` / `<int>`, or
  `ReadConfigPropertyAsModel<T>` for XML-valued properties.
- Do **not** cache the result in a `static` field unless you want it pinned for the process
  lifetime. Some existing helpers do this with `ref _backingField` — that is a deliberate
  choice, not the default.

### 3. Decide where to enforce it

For work that gets persisted to a queue, there is a real choice to make:

| Gate | Effect |
|---|---|
| Where the work is **created** | Nothing new is queued while the flag is off |
| Where the work is **consumed** | Items **already queued** are also rejected when the flag is turned off |

Gating both means turning the flag off drains a backlog immediately. Gating creation only
means queued work still completes.

**Gate creation only when the work can legitimately be created out of band** — a scheduled
task, a batch file, or an operator dropping a job file into the queue folder. A consumer-side
flag check would silently discard that work, which is almost never what anyone wants. The
Task 38396 depletion message is gated at creation only for exactly this reason.

**Gate both when the queue is fed solely by in-process code** and an operator needs a genuine
emergency stop.

Whichever you choose, say so in the runbook: "turning this off does / does not stop work
already queued" is the first thing support will ask.

### 4. Decide whether it is additive or exclusive

- **Exclusive** — the flag picks between two ways of doing the same thing, so it belongs in an
  `if/else`. Example: `EnableMDMOutbound` chooses MDM *or* ORU for delivering the report.
- **Additive** — the flag enables extra behaviour alongside whatever already happens, so it
  gets its **own** `if` and must not be folded into an existing `else`. Example: the inventory
  depletion message, which goes out *in addition to* the result message.

Getting this wrong silently disables an unrelated feature. Decide explicitly.

## The trap: a restart is required

`ReadConfigProperty` → `GeneralManager.GetCombinedConfigs` → `LookupInstance.CombinedConfigs`,
an **in-memory cache loaded at application startup**.

- Updating `ConfigCombination` has **no effect on a running client or service**.
- If the migration inserts the `ConfigProperty` row while the app is running, the lookup finds
  nothing and returns the code default until restart.

Always state "restart required" in handover notes and runbooks. It is the single most common
support question about flags.

## Checking and flipping a flag

```sql
-- current state
SELECT cp.ShortString, cc.ConfigId, cc.ConfigPropertyValue, ct.TargetComponent
FROM   ConfigProperty cp
JOIN   ConfigCombination cc ON cc.ConfigPropertyId = cp.Id
JOIN   ConfigType ct        ON ct.ID = cp.ConfigTypeId
WHERE  cp.ShortString = 'EnableYourFeature';

-- flip  (then RESTART)
UPDATE cc SET cc.ConfigPropertyValue = 'True'
FROM   ConfigCombination cc
JOIN   ConfigProperty cp ON cp.Id = cc.ConfigPropertyId
WHERE  cp.ShortString = 'EnableYourFeature';
```

## Troubleshooting

| Symptom | Cause |
|---|---|
| SQL says `True`, code behaves as `False` | Lookup cache — restart |
| Flag never takes effect on a fresh install | Migration ran while the app was up; restart |
| Flag works in the desktop client but not on web | A second call site was missed. Several handlers have duplicate static implementations — e.g. `ExamListHandlerForWeb.AfterFinalizeOperations` does not call into `ExamManager` |
| Turning it off leaves work still flowing | Only the creation gate was implemented; add the consumer gate |
| `ReadConfigProperty` returns the default silently | Property/ConfigType name mismatch. It swallows exceptions and logs `error while getting ConfigProperty form db` |
