# TASK T03 — PR Foreclosure: FC-EX-09/BR-03 Option A SP Fix
Priority: HIGH | Type: SP | Risk: HIGH | Branch: fix/foreclosure-fc-ex-09

## Context
FC-EX-09/BR-03: Received-status lines must be EXCLUDED from the Foreclosure SP WHERE clause.
CEO-directed Option A: exclude lines with ItemStatus = 'Received' (or equivalent) in SP.
Foreclosure SP: ksp_PR_Foreclosure (or ksp_PR_ForeclosureItems — check file index).

## File Index (from _file_index.json)
- sp_foreclosure (3 files):
  - D:\SpinriseV2\Development\Backend\Spinrise.DBScripts\merged.sql
  - D:\SpinriseV2\Development\Backend\Spinrise.DBScripts\Scripts\02-StoredProcedures\ksp_PR_GetOpenForForeclosure.sql
  - D:\SpinriseV2\Development\Backend\Spinrise.DBScripts\Scripts\02-StoredProcedures\ksp_PR_SaveForeclosureLine.sql

## Pre-Flight
Run to inspect current WHERE clause:
```powershell
Select-String -Path "D:\SpinriseV2\Development\Backend\Spinrise.DBScripts\Scripts\02-StoredProcedures\ksp_PR_GetOpenForForeclosure.sql" -Pattern "WHERE|ItemStatus|ITMSTATUS|Received|PRSTATUS" | Select-Object LineNumber, Line
```

## What to Do
1. Read ksp_PR_GetOpenForForeclosure.sql
2. Find the WHERE clause that fetches PR lines for foreclosure
3. Add: AND [ItemStatus/ITMSTATUS column] <> 'Received' (or equivalent — read actual column name)
   CRITICAL: Read DB_Schema.md or grep schema for correct column name before writing
4. Also check ksp_PR_SaveForeclosureLine.sql — same exclusion rule may apply
5. Update merged.sql

## Hard Rule
Read actual column name from D:\SpinriseV2\Docs\DB_Schema\SpinRiseSaranya_Schema.md — never guess.
If column name not found → STOP, log as BLOCKED, note exact query needed.

## Schema Hint (from CLAUDE.md)
- PO_PRH has NO PRSTATUS column — never write PO_PRH.PRSTATUS
- PO_PRL machine column is macno (no underscore)
- Read schema file for actual ItemStatus/line status column name in PO_PRL

## Output Required
- Modified ksp_PR_GetOpenForForeclosure.sql (and SaveForeclosureLine if applicable)
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
