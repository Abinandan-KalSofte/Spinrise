# SPINRISE MASTER PROMPT — 30 MAY 2026
**Purpose:** Parse today's action points → generate focused task prompt files → create task tracker
**Run this prompt once. It produces task files. Execute each task file separately.**

---

## INSTRUCTIONS FOR CLAUDE CODE

You are operating as: **Dev Architect + Chief of Staff** for SPINRISE V2.
Working directory: `D:\SpinriseV2`

### STEP 1 — Parse Action Points with Python

Run this Python script first. It extracts and classifies all tasks into a structured JSON.
This avoids re-reading the markdown manually and saves tokens for actual work.

```python
# save as: D:\SpinriseV2\Prompts\Tasks\2026-05-30\_parse_tasks.py
import json, re
from pathlib import Path

ap_file = Path(r"D:\SpinriseV2\Daily Action Points\ActionPoints_Abinandan_2026-05-30.md")
text = ap_file.read_text(encoding="utf-8")

tasks = [
    {"id": "T01A", "priority": "CRITICAL", "type": "SP",       "title": "PR Form — HF-21a FY Check SP Fix",
     "risk": "HIGH",   "notify": ["mariyaiya.m@kalsofte.com", "muthuvel.m@kalsofte.com"],
     "sp_pattern": "ksp_PR_",   "branch": "fix/pr-form-fy-check"},
    {"id": "T01B", "priority": "CRITICAL", "type": "BACKEND",  "title": "PR Form — Remaining Defects Backend (IL-31, IL-03a, IL-08a, IL-22, FN-03, DL-06, IL-13)",
     "risk": "HIGH",   "notify": ["mariyaiya.m@kalsofte.com", "muthuvel.m@kalsofte.com"],
     "sp_pattern": "ksp_PR_",   "branch": "fix/pr-form-defects-be"},
    {"id": "T01C", "priority": "CRITICAL", "type": "FRONTEND", "title": "PR Form — Print Defects PR-06 PR-12 PR-20",
     "risk": "MEDIUM", "notify": ["palanivel@kalsofte.com"],
     "sp_pattern": None,        "branch": "fix/pr-form-print"},
    {"id": "T02",  "priority": "CRITICAL", "type": "EMAIL",    "title": "IL-17 Root Cause Description Correction",
     "risk": "LOW",   "notify": ["qa@kalsofte.com"],
     "sp_pattern": None,        "branch": None},
    {"id": "T03",  "priority": "HIGH",     "type": "SP",       "title": "PR Foreclosure — FC-EX-09/BR-03 Option A SP Fix",
     "risk": "HIGH",   "notify": ["palanivel@kalsofte.com"],
     "sp_pattern": "ksp_PR_Foreclosure",  "branch": "fix/foreclosure-fc-ex-09"},
    {"id": "T04",  "priority": "HIGH",     "type": "SP",       "title": "PR Cancellation — SP-I1 rowversion + Trans_Name Fix",
     "risk": "HIGH",   "notify": ["palanivel@kalsofte.com"],
     "sp_pattern": "ksp_PR_UndoCancellation", "branch": "fix/cancellation-sp-i1"},
    {"id": "T05",  "priority": "HIGH",     "type": "EMAIL",    "title": "PR First Level — OI-05 DirectApp Confirmation to QA",
     "risk": "LOW",   "notify": ["qa@kalsofte.com"],
     "sp_pattern": None,        "branch": None},
    {"id": "T06",  "priority": "HIGH",     "type": "EMAIL",    "title": "PR Final Level — v1.2 vs v1.4 Baseline Conflict Clarification",
     "risk": "LOW",   "notify": ["qa@kalsofte.com"],
     "sp_pattern": None,        "branch": None},
    {"id": "T07",  "priority": "POST_PILOT","type": "FULLSTACK","title": "PR Second Level Approval — Full Build (FSD v1.3)",
     "risk": "HIGH",   "notify": ["sasikumar.r@kalsofte.com", "qa@kalsofte.com"],
     "sp_pattern": "ksp_PRSecondlevel", "branch": "feature/pr-second-level-v1.3"},
    {"id": "T08",  "priority": "POST_PILOT","type": "BACKEND",  "title": "PR First Level — OI-07 Per-Line Not-Approved Reset",
     "risk": "MEDIUM", "notify": ["qa@kalsofte.com"],
     "sp_pattern": "ksp_PR_FirstLevel",  "branch": "fix/oi-07-per-line-reset"},
]

out = Path(r"D:\SpinriseV2\Prompts\Tasks\2026-05-30\_task_manifest.json")
out.write_text(json.dumps(tasks, indent=2), encoding="utf-8")
print(f"Written {len(tasks)} tasks to {out}")
for t in tasks:
    print(f"  [{t['id']}] {t['priority']:<12} {t['type']:<10} {t['title']}")
```

Run: `python D:\SpinriseV2\Prompts\Tasks\2026-05-30\_parse_tasks.py`

---

### STEP 2 — Find Relevant Files with Python (Token Saver)

Run this to locate SP files, controllers, and frontend components before generating prompts.
This replaces manual Glob/Grep across large directories.

```python
# save as: D:\SpinriseV2\Prompts\Tasks\2026-05-30\_find_files.py
import subprocess, json
from pathlib import Path

base = Path(r"D:\SpinriseV2\Development")
out_file = Path(r"D:\SpinriseV2\Prompts\Tasks\2026-05-30\_file_index.json")

def grep(pattern, path, ext="*"):
    try:
        r = subprocess.run(
            ["grep", "-rl", pattern, str(path), "--include", f"*.{ext}"],
            capture_output=True, text=True, timeout=15
        )
        return [p.strip() for p in r.stdout.strip().splitlines() if p.strip()]
    except Exception as e:
        return [f"ERROR: {e}"]

index = {
    "sp_pr_form":         grep("ksp_PR_GetAll\|ksp_PR_Save\|ksp_PR_",
                                base / "Backend/Spinrise.DBScripts", "sql"),
    "sp_foreclosure":     grep("ksp_PR_Foreclosure\|FC-EX-09\|ForeclosureStatus",
                                base / "Backend/Spinrise.DBScripts", "sql"),
    "sp_cancellation":    grep("ksp_PR_UndoCancellation\|ksp_PR_Cancellation",
                                base / "Backend/Spinrise.DBScripts", "sql"),
    "sp_second_level":    grep("ksp_PRSecondlevel\|SecondLevel",
                                base / "Backend/Spinrise.DBScripts", "sql"),
    "sp_first_level":     grep("ksp_PR_FirstLevel\|FirstLevel",
                                base / "Backend/Spinrise.DBScripts", "sql"),
    "be_pr_controller":   grep("PurchaseRequisition\|PRController",
                                base / "Backend/Spinrise.API", "cs"),
    "be_pr_service":      grep("IPRService\|PRService",
                                base / "Backend/Spinrise.Application", "cs"),
    "be_cancellation":    grep("Cancellation\|UndoCancellation",
                                base / "Backend", "cs"),
    "be_second_level":    grep("SecondLevel\|SecondApproval",
                                base / "Backend", "cs"),
    "fe_pr_form":         grep("PRForm\|PurchaseRequisition",
                                base / "spinrise-web/src", "tsx"),
    "fe_print":           grep("QuestPDF\|PrintPR\|pr-print\|PRPrint",
                                base, "cs"),
    "fe_second_level":    grep("SecondLevel\|secondlevel",
                                base / "spinrise-web/src", "tsx"),
    "merged_sql":         [str(base / "Backend/Spinrise.DBScripts/merged.sql")]
}

out_file.write_text(json.dumps(index, indent=2), encoding="utf-8")
print("File index written:")
for k, v in index.items():
    count = len(v)
    print(f"  {k:<25}: {count} file(s)")
    for f in v[:3]:
        print(f"    → {f}")
    if count > 3:
        print(f"    ... +{count-3} more")
```

Run: `python D:\SpinriseV2\Prompts\Tasks\2026-05-30\_find_files.py`

Read `_file_index.json` before generating each task prompt — reference exact paths.

---

### STEP 3 — Generate All Task Prompt Files

Using the manifest and file index, generate these files under `D:\SpinriseV2\Prompts\Tasks\2026-05-30\`:

**Generate each file exactly as specified below. Do not modify structure.**

---

#### FILE: TASK_01A_HF21a_FY_Check_SP.md

```
# TASK T01A — PR Form: HF-21a FY Check SP Fix
Priority: CRITICAL | Type: SP | Risk: HIGH | Branch: fix/pr-form-fy-check

## Context
PR Date must be validated against the currently open Financial Year in PP_Year table.
Defect HF-21a: no FY boundary check exists. PRs outside current FY are being saved.
FSD v2.5 §4 CR-PR-05: PR Date must fall within currently open FY (PP_Year table).

## What to Do
1. Read file index: D:\SpinriseV2\Prompts\Tasks\2026-05-30\_file_index.json → get sp_pr_form paths
2. Read the PR Save SP (ksp_PR_Save or equivalent) — find the PRDATE validation block
3. Add FY guard using PP_Year table pattern (same pattern as ksp_PRSecondlevel_approval SP-F5):
   - Get current open FY: SELECT TOP 1 FYStart, FYEnd FROM PP_Year WHERE IsOpen = 1 ORDER BY FYStart DESC
   - Validate: @PRDate BETWEEN @FYStart AND @FYEnd — if outside, RAISERROR with HTTP 400
4. Update merged.sql with the change
5. Write the FY check as a reusable inline query (not a separate SP — keep it simple)

## Validation Before Writing
- Read PP_Year table schema from D:\SpinriseV2\Docs\DB_Schema\SpinRiseSaranya_Schema.md
  (column names for IsOpen flag, FYStart, FYEnd — do NOT assume column names)
- If schema file not found: grep "PP_Year" in merged.sql to infer column names

## Output Required
- Modified SP file with FY check added
- merged.sql updated
- Git commit message: "Fix HF-21a: add FY boundary validation to PR Save SP per CR-PR-05"

## Email Draft
Write to: D:\SpinriseV2\Email\Drafts\T01A_HF21a_fix_notify.eml
To: mariyaiya.m@kalsofte.com; muthuvel.m@kalsofte.com
Cc: qa@kalsofte.com
Subject: SPINRISE M01 — PR Form HF-21a FY Check Fix Deployed — Retest Required — [DATE]
Body: [State SP changed, validation added, ask for retest on 172.16.16.40:5001, IST-REF HF-21a]
Format: .eml plain text (X-Mozilla-Status: 0000 header, MIME plain/text)

## Log Entry
Append to: D:\SpinriseV2\Docs\ChangeLog\2026-05-30_session_pilot-fixes.md
Format: | [TIME] | SP-Fix | HF-21a | [sp_file] | FY guard added via PP_Year | FSD CR-PR-05 |
Status line: COMPLETED / PENDING / BLOCKED — with reason
```

---

#### FILE: TASK_01B_PRForm_Backend_Defects.md

```
# TASK T01B — PR Form: Backend Defects (IL-31, IL-03a, IL-08a, IL-22, FN-03, DL-06, IL-13)
Priority: CRITICAL | Type: BACKEND | Risk: HIGH | Branch: fix/pr-form-defects-be

## Context
7 IST defects currently Fail/Blocked in PR Form. These are backend layer issues.
Source of truth: IST finding reference numbers in test sheet + FSD v2.5.

## Pre-Flight: Identify Each Defect Before Writing Code
Use Python to search codebase for each defect pattern:

```python
# Run inline — find defect-related code locations
import subprocess
from pathlib import Path

patterns = {
    "IL-31":  ["IL31", "ItemLimit", "line_limit", "MAXLINES"],
    "IL-03a": ["IL03", "ItemCode", "item_code", "ITEMCODE"],
    "IL-08a": ["IL08", "MachineCode", "macno", "MAC_NO"],
    "IL-22":  ["IL22", "Quantity", "qtyreqd", "qtyind"],
    "FN-03":  ["FN03", "FundCode", "FUNDCODE", "fund_code"],
    "DL-06":  ["DL06", "DeleteLine", "delete_line", "DELLINE"],
    "IL-13":  ["IL13", "ItemDesc", "item_desc", "ITEMDESC"],
}
base = r"D:\SpinriseV2\Development\Backend"
for ref, terms in patterns.items():
    for term in terms:
        r = subprocess.run(["grep", "-rl", term, base], capture_output=True, text=True)
        if r.stdout.strip():
            print(f"{ref} ({term}): {r.stdout.strip()[:120]}")
            break
```

## What to Do
For each defect:
1. Read the IST finding → understand expected vs current behaviour
2. Locate the exact SP/controller/service responsible
3. Apply minimal targeted fix
4. Do NOT refactor surrounding code — touch only what the defect requires

## Hard Rule
If any defect requires an FSD change or new business rule: STOP.
Log as BLOCKED, note the FSD section needed, do NOT write code.
Raise a CR Document entry in the log instead.

## Output Required
- Modified files (SP, controller, service, repository as needed per defect)
- merged.sql updated for any SP changes
- Git commit per defect: "Fix [IST-REF]: [one-line description]"

## Email Draft
Write to: D:\SpinriseV2\Email\Drafts\T01B_backend_defects_notify.eml
To: mariyaiya.m@kalsofte.com; muthuvel.m@kalsofte.com
Subject: SPINRISE M01 — PR Form Backend Defects Fixed — Retest Required [DATE]
Body: List each IST-REF fixed, retest instruction, server 172.16.16.40:3000

## Log Entry
Append to: D:\SpinriseV2\Docs\ChangeLog\2026-05-30_session_pilot-fixes.md
One row per defect fixed. Status: COMPLETED / PENDING / BLOCKED (with CR note if blocked).
```

---

#### FILE: TASK_01C_PRForm_Print_Defects.md

```
# TASK T01C — PR Form: Print Defects PR-06, PR-12, PR-20
Priority: CRITICAL | Type: FRONTEND+PRINT | Risk: MEDIUM | Branch: fix/pr-form-print

## Context
PR Form print (QuestPDF) has 3 blocked defects: PR-06, PR-12, PR-20.
Print stack: QuestPDF only. Report location: Spinrise.Application/Areas/Purchase/Reports/
FSD v2.5 §7: Print layout A4 Landscape, decimals Qty=3dp Rate=4dp Value=2dp.
CR-PR-09: Print date footer alongside Total Value — NOT header.

## Pre-Flight
```python
import subprocess
r = subprocess.run(
    ["grep", "-rn", "PR-06\|PR-12\|PR-20\|PRPrint\|QuestPDF", 
     r"D:\SpinriseV2\Development\Backend\Spinrise.Application\Areas\Purchase"],
    capture_output=True, text=True
)
print(r.stdout[:2000])
```

## What to Do
1. Read the QuestPDF report class for PR print
2. Identify exact failure for each defect reference (PR-06, PR-12, PR-20)
3. Fix only the failing sections — do not restructure the document class
4. Confirm: print date is in FOOTER alongside Total Value (not header) per CR-PR-09

## Output Required
- Modified QuestPDF report class
- Git commit: "Fix PR-06/12/20: correct print defects in PRPrintDocument"

## Email Draft
Write to: D:\SpinriseV2\Email\Drafts\T01C_print_fix_notify.eml
To: palanivel@kalsofte.com
Cc: qa@kalsofte.com
Subject: SPINRISE M01 — PR Form Print Defects PR-06/12/20 Fixed — Retest Required [DATE]
Body: State defects fixed, confirm print date placement per CR-PR-09, retest instruction.

## Log Entry
Append to: D:\SpinriseV2\Docs\ChangeLog\2026-05-30_session_pilot-fixes.md
```

---

#### FILE: TASK_02_IL17_Email.md

```
# TASK T02 — IL-17 Root Cause Description Correction
Priority: CRITICAL | Type: EMAIL | Risk: LOW | Branch: none

## Context
IL-17 in the IST test sheet currently has root cause description = "Claude Code Mistake".
This must be corrected to the actual technical defect description before pilot sign-off.
CEO direction: IL-17 root cause must reflect the real technical cause, not the tool.

## What to Do
1. Read the current IST test sheet/checklist if available in Docs folder:
   grep for "IL-17" or "IL17" in D:\SpinriseV2\Docs
2. If test sheet not found: draft email asking Mariyaiya/Palanivel to confirm the correct
   technical description, then we update. Do NOT invent a root cause.
3. If found: identify the actual technical defect (field mapping error, null reference, etc.)
   and draft the correction.

## Decision Rule (no clarification needed)
- If IL-17 test sheet found AND technical root cause is clear → draft correction email + update doc
- If NOT found → draft email to Mariyaiya asking to confirm actual root cause so we can update
  (do not block on this — email the question, log as PENDING-RESPONSE)

## Email Draft
Write to: D:\SpinriseV2\Email\Drafts\T02_IL17_rootcause_correction.eml
To: mariyaiya.m@kalsofte.com; palanivel@kalsofte.com
Cc: qa@kalsofte.com
Subject: SPINRISE M01 — IL-17 Root Cause Description Correction Required [DATE]
Body: State current description is "Claude Code Mistake" which is not technical.
      Ask Mariyaiya to confirm actual technical root cause so we can update before pilot sign-off.
      (Or: state the corrected root cause if found from test sheet.)

## Log Entry
Append to: D:\SpinriseV2\Docs\ChangeLog\2026-05-30_session_pilot-fixes.md
| [TIME] | Email | IL-17 | N/A | Root cause correction email drafted | CEO direction |
Status: COMPLETED (if doc updated) / PENDING-RESPONSE (if awaiting Mariyaiya confirm)
```

---

#### FILE: TASK_03_Foreclosure_FC_EX_09.md

```
# TASK T03 — PR Foreclosure: FC-EX-09/BR-03 Option A SP Fix
Priority: HIGH | Type: SP | Risk: HIGH | Branch: fix/foreclosure-fc-ex-09

## Context
FC-EX-09/BR-03: Received-status lines must be EXCLUDED from the Foreclosure SP WHERE clause.
CEO-directed Option A: exclude lines with ItemStatus = 'Received' (or equivalent) in SP.
Foreclosure SP: ksp_PR_Foreclosure (or ksp_PR_ForeclosureItems — check file index).

## Pre-Flight
```python
import subprocess
r = subprocess.run(
    ["grep", "-rn", "Foreclosure\|PRSTATUS\|FC-EX\|ItemStatus\|Received",
     r"D:\SpinriseV2\Development\Backend\Spinrise.DBScripts"],
    capture_output=True, text=True
)
print(r.stdout[:3000])
```

## What to Do
1. Read the Foreclosure SP(s)
2. Find the WHERE clause that fetches PR lines for foreclosure
3. Add: AND [ItemStatus/ITMSTATUS column] <> 'Received' (or equivalent — read actual column name)
   CRITICAL: Read DB_Schema.md or grep schema for correct column name before writing
4. Update merged.sql

## Hard Rule
Read actual column name from schema — never guess. 
If column name not found → STOP, log as BLOCKED, note exact query needed.

## Output Required
- Modified Foreclosure SP
- merged.sql updated
- Git commit: "Fix FC-EX-09: exclude Received-status lines from foreclosure SP (Option A)"

## Email Draft
Write to: D:\SpinriseV2\Email\Drafts\T03_foreclosure_fix_notify.eml
To: palanivel@kalsofte.com
Cc: qa@kalsofte.com; sasikumar.r@kalsofte.com
Subject: SPINRISE M01 — PR Foreclosure FC-EX-09 Fix Deployed — Retest Required [DATE]
Body: State Option A applied (Received-status lines excluded), retest all 9+ fixed items.

## Log Entry
Append to: D:\SpinriseV2\Docs\ChangeLog\2026-05-30_session_pilot-fixes.md
```

---

#### FILE: TASK_04_Cancellation_SP_I1.md

```
# TASK T04 — PR Cancellation: SP-I1 rowversion + Trans_Name Fix
Priority: HIGH | Type: SP | Risk: HIGH | Branch: fix/cancellation-sp-i1

## Context
SP-I1: ksp_PR_UndoCancellation is missing rowversion enforcement — concurrency risk.
Fix:
  (a) Add @RowVersion BINARY(8) INPUT parameter
  (b) Add WHERE row_version = @RowVersion to the PO_PRH UPDATE statement
  (c) After UPDATE, check @@ROWCOUNT = 0 → RAISERROR with message 'Concurrent update conflict' + HTTP 409
  (d) Correct Trans_Name value: change to exactly 'Purchase Requisition Undo Cancellation'

## Pre-Flight
```python
import subprocess
r = subprocess.run(
    ["grep", "-n", "UndoCancellation\|Trans_Name\|row_version\|RowVersion",
     r"D:\SpinriseV2\Development\Backend\Spinrise.DBScripts\Scripts\02-StoredProcedures\ksp_PR_UndoCancellation.sql"],
    capture_output=True, text=True
)
print(r.stdout)
# If file not found, grep the DBScripts folder
```

Also check the C# layer:
```python
r2 = subprocess.run(
    ["grep", "-rn", "UndoCancellation\|RowVersion\|rowVersion",
     r"D:\SpinriseV2\Development\Backend"],
    capture_output=True, text=True
)
print(r2.stdout[:2000])
```

## What to Do
1. Read the SP file
2. Add @RowVersion parameter at top of parameter list
3. Modify the PO_PRH UPDATE WHERE clause to include row_version = @RowVersion
4. Add @@ROWCOUNT check with RAISERROR (HTTP 409 semantics via error number > 50000)
5. Find Trans_Name assignment in SP — change to 'Purchase Requisition Undo Cancellation'
6. Check C# DTO/repository — add RowVersion property if not present; pass it in the SP call
7. Update merged.sql

## Output Required
- Modified SP
- Modified C# DTO + Repository (if RowVersion parameter needs adding)
- merged.sql updated
- Git commit: "Fix SP-I1: add rowversion enforcement + correct Trans_Name in UndoCancellation"

## Email Draft
Write to: D:\SpinriseV2\Email\Drafts\T04_cancellation_sp_notify.eml
To: palanivel@kalsofte.com
Cc: qa@kalsofte.com; sasikumar.r@kalsofte.com
Subject: SPINRISE M01 — PR Cancellation SP-I1 rowversion Fix Deployed — Undo IST May Proceed [DATE]
Body: SP-I1 rowversion added, Trans_Name corrected, Undo Cancellation IST is now unblocked.

## Log Entry
Append to: D:\SpinriseV2\Docs\ChangeLog\2026-05-30_session_pilot-fixes.md
```

---

#### FILE: TASK_05_OI05_DirectApp_Email.md

```
# TASK T05 — PR First Level: OI-05 DirectApp Confirmation Email
Priority: HIGH | Type: EMAIL | Risk: LOW | Branch: none

## Context
OI-05: DirectApp='Y' handling — CEO wants to confirm whether SPINRISE auto-detects
sole-approver customers from po_para level count OR requires a separate DirectApp flag.
QA needs Abinandan to state what the CURRENT deployed build does for OI-05.

## What to Do
1. Search deployed code for DirectApp handling:
```python
import subprocess
r = subprocess.run(
    ["grep", "-rn", "DirectApp\|DIRECTAPP\|directApp\|sole_approver",
     r"D:\SpinriseV2\Development"],
    capture_output=True, text=True
)
print(r.stdout[:2000])
```
2. Read what the current build does (reads from po_para? uses a flag? auto-detects?)
3. Draft a factual reply to QA describing exactly what is in the current build
4. Do NOT make a design decision — state what exists, flag that CEO confirmation is pending

## Email Draft
Write to: D:\SpinriseV2\Email\Drafts\T05_OI05_DirectApp_confirm.eml
To: qa@kalsofte.com
Cc: sasikumar.r@kalsofte.com; ceo@kalsofte.com
Subject: Re: SPINRISE M01 PR First Level Approval — OI-05 DirectApp Handling Confirmation [DATE]
Body: State exactly what the deployed build does for DirectApp (quote the code path).
      Confirm countersignature authority basis (FSD v1.2 stage completed per process).
      Note CEO decision on auto-detect approach is still awaited.

## Log Entry
Append to: D:\SpinriseV2\Docs\ChangeLog\2026-05-30_session_pilot-fixes.md
| [TIME] | Email | OI-05 | N/A | DirectApp handling confirmed to QA | OI-05 |
Status: COMPLETED
```

---

#### FILE: TASK_06_FinalLevel_Baseline_Email.md

```
# TASK T06 — PR Final Level: v1.2 vs v1.4 Baseline Conflict Clarification
Priority: HIGH | Type: EMAIL | Risk: LOW | Branch: none

## Context
QA flagged that the Final Level prototype baseline version is unclear (v1.2 vs v1.4).
CEO countersignature is blocked until Abinandan clarifies which version is deployed.
Abinandan must reply to QA thread immediately.

## What to Do
1. Check the deployed build for which FSD version is in use:
```python
import subprocess
# Look for version references in Final Level files
r = subprocess.run(
    ["grep", "-rn", "FinalLevel\|final_level\|FinalApproval\|v1.2\|v1.4",
     r"D:\SpinriseV2\Development"],
    capture_output=True, text=True
)
print(r.stdout[:2000])
```
2. Determine: Is the deployed UI/UX prototype built from FSD v1.2 or v1.4?
   - v1.4 is the current CEO-submitted version (Stage 4, pre-conditions cleared 29 May)
   - v1.2 was the previous countersigned version
   - If prototype was built from v1.4 → state this clearly
   - If it was built from v1.2 → state this and flag that update needed for v1.4 compliance

## Email Draft
Write to: D:\SpinriseV2\Email\Drafts\T06_FinalLevel_baseline_clarify.eml
To: qa@kalsofte.com
Cc: ceo@kalsofte.com; sasikumar.r@kalsofte.com; mohanbabuvn@kalsofte.com
Subject: Re: SPINRISE M01 PR Final Level Approval — UI/UX Prototype Baseline Version Clarification [DATE]
Body: State exactly which FSD version the deployed prototype was built from.
      If v1.4: confirm alignment with all v1.4 changes.
      If v1.2: state the delta and what still needs to be updated for v1.4.
      This unblocks CEO countersignature.

## Log Entry
Append to: D:\SpinriseV2\Docs\ChangeLog\2026-05-30_session_pilot-fixes.md
Status: COMPLETED
```

---

#### FILE: TASK_07_Second_Level_Full_Build.md

```
# TASK T07 — PR Second Level Approval: Full Build (FSD v1.3)
Priority: POST_PILOT | Type: FULLSTACK | Risk: HIGH | Branch: feature/pr-second-level-v1.3

## Context
FSD v1.3 countersigned by CEO at 10:15 AM today. Development baseline locked.
This is a full SP → Backend → Frontend build. Do NOT start until pilot is confirmed.

## Locked Baseline Rules (non-negotiable — from CEO countersignature email)
| Rule | Value |
|---|---|
| Division endpoint | GetDivisions() ONLY — no GetDivisionsForMD |
| Company=ALL mode | imode=1 — GET /api/secondlevel-pr?divcode=0 |
| Bypass checkbox | Hidden by default; render ONLY when JWT claim 'BypassApproval' present |
| SecondApp='Y' write | Conditional: Bypass=1 AND customer IN (JAT, Cheran, SCM) ONLY |
| Responsive Design | OI-06 — Sprint 2 (do NOT implement now) |

## Build Order (strict — do not skip steps)
1. SP layer: Read and build ksp_PRSecondlevel_approval and supporting SPs
   → Read D:\SpinriseV2\Docs\DB_Schema\SpinRiseSaranya_Schema.md FIRST
2. Domain entity: PRSecondLevelApproval
3. Infrastructure: Repository + UnitOfWork registration
4. Application: Service + DTOs + interfaces
5. API: Controller (BaseApiController), routes, Swagger annotations
6. Frontend: Feature module (api/ store/ components/ pages/ types.ts)
   → Follow CLAUDE.md feature module structure exactly
7. Unit tests: Service layer + Repository layer (target 80%+)

## Token Efficiency Strategy
Use Python to read existing similar module (First Level) and diff against what needs changing:
```python
import subprocess
# Find First Level as reference implementation
r = subprocess.run(
    ["grep", "-rl", "FirstLevel\|FirstApproval",
     r"D:\SpinriseV2\Development\Backend"],
    capture_output=True, text=True
)
print("First Level reference files:")
print(r.stdout)
```
Build Second Level as a parallel pattern to First Level — adapting only where FSD v1.3 differs.

## Split Rule
Split this task if the session hits 80% context:
- T07a: SP + Domain + Infrastructure (Session 1)
- T07b: Application + API (Session 2)
- T07c: Frontend (Session 3)
- T07d: Unit Tests (Session 4)
Each session: read CLAUDE.md + FSD v1.3 relevant sections only (not full FSD).

## Email Draft (after each sub-session)
Write to: D:\SpinriseV2\Email\Drafts\T07_second_level_progress_[SESSION].eml
To: sasikumar.r@kalsofte.com; qa@kalsofte.com
Subject: SPINRISE M01 PR Second Level — Build Progress [Session X] [DATE]
Body: State layers completed, what's next, any open items.

## Log Entry
Append to: D:\SpinriseV2\Docs\ChangeLog\2026-05-30_session_second-level.md (separate log)
```

---

#### FILE: TASK_08_OI07_PerLine_Reset.md

```
# TASK T08 — PR First Level: OI-07 Per-Line Not-Approved Reset
Priority: POST_PILOT | Type: BACKEND | Risk: MEDIUM | Branch: fix/oi-07-per-line-reset

## Context
OI-07 (CEO-confirmed): When a First Level approver clicks 'Not Approved' on a PR,
each line item's approval status must be individually reset (not header-level only).
This is a targeted backend + SP fix on the First Level approval logic.

## Pre-Flight
```python
import subprocess
r = subprocess.run(
    ["grep", "-rn", "NotApproved\|NOT_APPROVED\|APP1FLG\|APPFLG\|PerLine",
     r"D:\SpinriseV2\Development"],
    capture_output=True, text=True
)
print(r.stdout[:2000])
```

## What to Do
1. Find the SP for First Level Not-Approved action
2. Locate the line-level status update logic
3. Ensure per-line reset: UPDATE PO_PRL SET [approval_flag] = 'N' WHERE PRNO = @PRNO
   (read exact column from schema first)
4. If the NOT-APPROVED path only updates PO_PRH header: add PO_PRL update in same transaction
5. Update merged.sql

## Email Draft
Write to: D:\SpinriseV2\Email\Drafts\T08_OI07_perline_reset_notify.eml
To: qa@kalsofte.com
Cc: palanivel@kalsofte.com; sasikumar.r@kalsofte.com
Subject: SPINRISE M01 PR First Level OI-07 Per-Line Reset Implemented [DATE]
Body: State what was changed, confirm per-line reset is now in place as CEO-directed.

## Log Entry
Append to: D:\SpinriseV2\Docs\ChangeLog\2026-05-30_session_pilot-fixes.md
```

---

### STEP 4 — Generate Task Tracker

After generating all task prompt files, create this tracker file:

Write to: `D:\SpinriseV2\Daily Action Points\TaskTracker_2026-05-30.md`

```markdown
# SPINRISE Task Tracker — 30 May 2026
**Pilot go/no-go: 12:15 PM**
Generated by: MASTER_PROMPT_2026-05-30.md

| ID    | Priority    | Type       | Title                                          | Prompt File        | Status  | Email Draft | Log Entry |
|-------|-------------|------------|------------------------------------------------|--------------------|---------|-------------|-----------|
| T01A  | CRITICAL    | SP         | HF-21a FY Check SP Fix                        | TASK_01A...md      | PENDING | Drafts/T01A | ChangeLog |
| T01B  | CRITICAL    | BACKEND    | PR Form Backend Defects (7 items)              | TASK_01B...md      | PENDING | Drafts/T01B | ChangeLog |
| T01C  | CRITICAL    | PRINT      | PR Form Print Defects PR-06/12/20              | TASK_01C...md      | PENDING | Drafts/T01C | ChangeLog |
| T02   | CRITICAL    | EMAIL      | IL-17 Root Cause Correction Email              | TASK_02...md       | PENDING | Drafts/T02  | ChangeLog |
| T03   | HIGH        | SP         | Foreclosure FC-EX-09 Option A                  | TASK_03...md       | PENDING | Drafts/T03  | ChangeLog |
| T04   | HIGH        | SP+BE      | Cancellation SP-I1 rowversion + Trans_Name     | TASK_04...md       | PENDING | Drafts/T04  | ChangeLog |
| T05   | HIGH        | EMAIL      | OI-05 DirectApp Confirmation to QA             | TASK_05...md       | PENDING | Drafts/T05  | ChangeLog |
| T06   | HIGH        | EMAIL      | Final Level v1.2/v1.4 Baseline Clarification   | TASK_06...md       | PENDING | Drafts/T06  | ChangeLog |
| T07   | POST_PILOT  | FULLSTACK  | PR Second Level Full Build (FSD v1.3)          | TASK_07...md       | PENDING | Drafts/T07  | ChangeLog |
| T08   | POST_PILOT  | BACKEND    | OI-07 Per-Line Not-Approved Reset              | TASK_08...md       | PENDING | Drafts/T08  | ChangeLog |

## Execution Order (pilot day)
1. T02, T05, T06 — EMAIL tasks first (no deploy risk, unblocks CEO actions)
2. T01A → T01B → T01C — Code fixes in layer order (SP → Backend → Frontend)
3. T03, T04 — Foreclosure + Cancellation SPs
4. [Post pilot] T07, T08

## Status Legend
PENDING | IN_PROGRESS | COMPLETED | BLOCKED:[reason] | PENDING-RESPONSE
```

---

### HOW TO USE THIS MASTER PROMPT

1. **Open a new Claude Code session** in `D:\SpinriseV2`
2. **Paste this entire file** as your first message
3. Claude will run the Python scripts and generate all task prompt files
4. **For each task:**
   - Open a fresh Claude Code session
   - Paste the content of `D:\SpinriseV2\Prompts\Tasks\2026-05-30\TASK_[ID]_*.md`
   - Claude executes the task, writes email draft, writes log entry
   - You open the `.eml` draft in Thunderbird → review → send
   - Update `TaskTracker_2026-05-30.md` status to COMPLETED

**Token efficiency per task session:**
- Email tasks (T02/T05/T06): ~5-10K tokens each
- SP-only fixes (T01A/T03/T04): ~15-25K tokens each
- Backend fixes (T01B/T08): ~20-35K tokens each
- Print fix (T01C): ~10-20K tokens
- Full build T07: Split into 4 sub-sessions × ~40-60K tokens each
