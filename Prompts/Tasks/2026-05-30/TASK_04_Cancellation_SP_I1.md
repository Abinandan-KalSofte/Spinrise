# TASK T04 — PR Cancellation: SP-I1 rowversion + Trans_Name Fix
Priority: HIGH | Type: SP | Risk: HIGH | Branch: fix/cancellation-sp-i1

## Context
SP-I1: ksp_PR_UndoCancellation is missing rowversion enforcement — concurrency risk.
Fix:
  (a) Add @RowVersion BINARY(8) INPUT parameter
  (b) Add WHERE row_version = @RowVersion to the PO_PRH UPDATE statement
  (c) After UPDATE, check @@ROWCOUNT = 0 → RAISERROR with message 'Concurrent update conflict' + HTTP 409
  (d) Correct Trans_Name value: change to exactly 'Purchase Requisition Undo Cancellation'

## File Index (from _file_index.json)
- sp_cancellation (2 files):
  - D:\SpinriseV2\Development\Backend\Spinrise.DBScripts\merged.sql
  - D:\SpinriseV2\Development\Backend\Spinrise.DBScripts\Scripts\02-StoredProcedures\ksp_PR_UndoCancellation.sql
- be_cancellation (6 files):
  - D:\SpinriseV2\Development\Backend\Spinrise.API\Areas\PurchaseOrder\Controllers\PrCancellationController.cs
  - D:\SpinriseV2\Development\Backend\Spinrise.Application\Areas\PurchaseOrder\PurchaseRequisition\Interfaces\IPrCancellationRepository.cs
  - D:\SpinriseV2\Development\Backend\Spinrise.Application\Areas\PurchaseOrder\PurchaseRequisition\Interfaces\IPrCancellationService.cs
  - (3 more — read _file_index.json for full list)

## Pre-Flight
Inspect current SP:
```powershell
Select-String -Path "D:\SpinriseV2\Development\Backend\Spinrise.DBScripts\Scripts\02-StoredProcedures\ksp_PR_UndoCancellation.sql" -Pattern "Trans_Name|row_version|RowVersion|ROWCOUNT|RAISERROR" | Select-Object LineNumber, Line
```

Check C# layer for RowVersion:
```powershell
Get-ChildItem "D:\SpinriseV2\Development\Backend" -Recurse -Filter "*.cs" | Select-String -Pattern "UndoCancellation|RowVersion|rowVersion" | Select-Object Path, LineNumber, Line | Select-Object -First 20
```

## What to Do
1. Read ksp_PR_UndoCancellation.sql
2. Add @RowVersion BINARY(8) parameter at top of parameter list
3. Modify the PO_PRH UPDATE WHERE clause to include: AND row_version = @RowVersion
4. After UPDATE: IF @@ROWCOUNT = 0 RAISERROR('Concurrent update conflict — record has changed. Please refresh and retry.', 16, 1)
   (Error severity 16 = user-correctable; use error number > 50000 for custom messages)
5. Find Trans_Name assignment in SP — change to exactly: 'Purchase Requisition Undo Cancellation'
6. Read C# DTO/Repository — add RowVersion property if not present; pass it in the SP call
7. Update merged.sql

## Schema Note
- Read D:\SpinriseV2\Docs\DB_Schema\SpinRiseSaranya_Schema.md for PO_PRH column names
- Confirm the exact row_version column name in PO_PRH before writing

## Output Required
- Modified ksp_PR_UndoCancellation.sql
- Modified C# DTO + Repository (if RowVersion parameter needs adding)
- merged.sql updated
- Git commit: "Fix SP-I1: add rowversion enforcement + correct Trans_Name in UndoCancellation"

## Email Draft
Write to: D:\SpinriseV2\Email\Drafts\T04_cancellation_sp_notify.eml
To: palanivel@kalsofte.com
Cc: qa@kalsofte.com; sasikumar.r@kalsofte.com
Subject: SPINRISE M01 — PR Cancellation SP-I1 rowversion Fix Deployed — Undo IST May Proceed [DATE]
Body: SP-I1 rowversion added, Trans_Name corrected, Undo Cancellation IST is now unblocked.
Format: .eml plain text (X-Mozilla-Status: 0000 header, MIME plain/text)

## Log Entry
Append to: D:\SpinriseV2\Docs\ChangeLog\2026-05-30_session_pilot-fixes.md
