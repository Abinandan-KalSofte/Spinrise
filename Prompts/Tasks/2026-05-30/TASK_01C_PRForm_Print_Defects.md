# TASK T01C — PR Form: Print Defects PR-06, PR-12, PR-20
Priority: CRITICAL | Type: FRONTEND+PRINT | Risk: MEDIUM | Branch: fix/pr-form-print

## Context
PR Form print (QuestPDF) has 3 blocked defects: PR-06, PR-12, PR-20.
Print stack: QuestPDF only. Report location: Spinrise.Application/Areas/Purchase/Reports/
FSD v2.5 §7: Print layout A4 Landscape, decimals Qty=3dp Rate=4dp Value=2dp.
CR-PR-09: Print date footer alongside Total Value — NOT header.

## File Index (from _file_index.json)
- fe_print (11 files):
  - D:\SpinriseV2\Development\Backend\Spinrise.API\Areas\PurchaseOrder\Controllers\PurchaseRequisitionController.cs
  - D:\SpinriseV2\Development\Backend\Spinrise.API\Areas\PurchaseOrder\Print\PrAmendmentPrintDocument.cs
  - D:\SpinriseV2\Development\Backend\Spinrise.API\Areas\PurchaseOrder\Print\PrFirstApprovalPrintDocument.cs
  - (8 more — read _file_index.json for full list)

## Pre-Flight
Run this PowerShell snippet to find the main PR print document:
```powershell
Get-ChildItem "D:\SpinriseV2\Development\Backend\Spinrise.API\Areas\PurchaseOrder\Print" -Filter "*.cs" | Select-Object Name
```

## What to Do
1. Read the QuestPDF report class for PR print (look for PrPrintDocument.cs or similar)
2. Identify exact failure for each defect reference (PR-06, PR-12, PR-20)
3. Fix only the failing sections — do not restructure the document class
4. Confirm: print date is in FOOTER alongside Total Value (not header) per CR-PR-09
5. Confirm decimals: Qty=3dp, Rate=4dp, Value=2dp throughout

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
