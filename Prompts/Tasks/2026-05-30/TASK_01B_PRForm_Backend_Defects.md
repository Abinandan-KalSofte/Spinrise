# TASK T01B — PR Form: Backend Defects (IL-31, IL-03a, IL-08a, IL-22, FN-03, DL-06, IL-13)
Priority: CRITICAL | Type: BACKEND | Risk: HIGH | Branch: fix/pr-form-defects-be

## Context
7 IST defects currently Fail/Blocked in PR Form. These are backend layer issues.
Source of truth: IST finding reference numbers in test sheet + FSD v2.5.

## File Index (from _file_index.json)
- Controller: D:\SpinriseV2\Development\Backend\Spinrise.API\Areas\PurchaseOrder\Controllers\PurchaseRequisitionController.cs
- Service: D:\SpinriseV2\Development\Backend\Spinrise.Application\Areas\PurchaseOrder\PurchaseRequisition\Services\PrService.cs
- Interface: D:\SpinriseV2\Development\Backend\Spinrise.Application\Areas\PurchaseOrder\PurchaseRequisition\Interfaces\IPrService.cs
- SP files: 41 files in D:\SpinriseV2\Development\Backend\Spinrise.DBScripts\Scripts\02-StoredProcedures\

## Pre-Flight: Identify Each Defect Before Writing Code
Run this Python snippet to find defect-related code locations:

```python
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
        cmd = f'Get-ChildItem -Path "{base}" -Recurse | Select-String -Pattern "{term}" | Select-Object -ExpandProperty Path | Sort-Object -Unique'
        r = subprocess.run(["powershell", "-NoProfile", "-Command", cmd],
                           capture_output=True, text=True)
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
