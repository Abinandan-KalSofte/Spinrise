# TASK T08 — PR First Level: OI-07 Per-Line Not-Approved Reset
Priority: POST_PILOT | Type: BACKEND | Risk: MEDIUM | Branch: fix/oi-07-per-line-reset

## Context
OI-07 (CEO-confirmed): When a First Level approver clicks 'Not Approved' on a PR,
each line item's approval status must be individually reset (not header-level only).
This is a targeted backend + SP fix on the First Level approval logic.

## File Index Note
- sp_first_level: 0 files found — search manually:
  D:\SpinriseV2\Development\Backend\Spinrise.DBScripts\Scripts\02-StoredProcedures\
  (Look for ksp_PR_FirstLevel*.sql or ksp_PR_FirstApproval*.sql)

## Pre-Flight
```powershell
# Find First Level SP files
Get-ChildItem "D:\SpinriseV2\Development\Backend\Spinrise.DBScripts\Scripts\02-StoredProcedures" -Filter "*.sql" | Where-Object { $_.Name -match "FirstLevel|FirstApproval|First" } | Select-Object Name

# Find Not-Approved logic in all SPs
Get-ChildItem "D:\SpinriseV2\Development\Backend\Spinrise.DBScripts" -Recurse -Filter "*.sql" | Select-String -Pattern "NotApproved|NOT_APPROVED|APP1FLG|APPFLG|PerLine" | Select-Object Path, LineNumber, Line
```

## What to Do
1. Find the SP for First Level Not-Approved action (read schema first for column names)
2. Locate the line-level status update logic
3. Ensure per-line reset: UPDATE PO_PRL SET [approval_flag] = 'N' WHERE PRNO = @PRNO
   CRITICAL: Read D:\SpinriseV2\Docs\DB_Schema\SpinRiseSaranya_Schema.md for exact column name
4. If the NOT-APPROVED path only updates PO_PRH header: add PO_PRL update in same transaction
5. Also check if C# service/repository layer needs updating (pass-through of flag values)
6. Update merged.sql

## Schema Note (from CLAUDE.md)
- PO_PRH has NO PRSTATUS column — do NOT write PO_PRH.PRSTATUS
- PO_PRL machine column is macno (no underscore)
- PO_PRH.APP1TIME is datetime — use GETDATE()
- Read schema for actual approval flag column name in PO_PRL

## Output Required
- Modified First Level Not-Approved SP
- Modified C# service/repository if required
- merged.sql updated
- Git commit: "Fix OI-07: add per-line approval reset on First Level Not-Approved (CEO-directed)"

## Email Draft
Write to: D:\SpinriseV2\Email\Drafts\T08_OI07_perline_reset_notify.eml
To: qa@kalsofte.com
Cc: palanivel@kalsofte.com; sasikumar.r@kalsofte.com
Subject: SPINRISE M01 PR First Level OI-07 Per-Line Reset Implemented [DATE]
Body: State what was changed, confirm per-line reset is now in place as CEO-directed.
Format: .eml plain text (X-Mozilla-Status: 0000 header, MIME plain/text)

## Log Entry
Append to: D:\SpinriseV2\Docs\ChangeLog\2026-05-30_session_pilot-fixes.md
