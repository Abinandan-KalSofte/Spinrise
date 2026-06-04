# TASK T01A — PR Form: HF-21a FY Check SP Fix
Priority: CRITICAL | Type: SP | Risk: HIGH | Branch: fix/pr-form-fy-check

## Context
PR Date must be validated against the currently open Financial Year in PP_Year table.
Defect HF-21a: no FY boundary check exists. PRs outside current FY are being saved.
FSD v2.5 §4 CR-PR-05: PR Date must fall within currently open FY (PP_Year table).

## File Index (from _file_index.json)
- SP PR Form files (41 total) — key files:
  - D:\SpinriseV2\Development\Backend\Spinrise.DBScripts\Scripts\02-StoredProcedures\ksp_PR_Cancel.sql
  - D:\SpinriseV2\Development\Backend\Spinrise.DBScripts\Scripts\02-StoredProcedures\ksp_PR_CheckPendingOrder.sql
  - (search for ksp_PR_Save in the folder for Save SP)
- merged.sql: D:\SpinriseV2\Development\Backend\Spinrise.DBScripts\merged.sql

## What to Do
1. Read file index: D:\SpinriseV2\Prompts\Tasks\2026-05-30\_file_index.json → get sp_pr_form paths
2. Find ksp_PR_Save.sql (or equivalent Save SP) in:
   D:\SpinriseV2\Development\Backend\Spinrise.DBScripts\Scripts\02-StoredProcedures\
3. Read the SP — find the PRDATE validation block
4. Add FY guard using PP_Year table pattern (same pattern as ksp_PRSecondlevel_approval SP-F5):
   - Get current open FY: SELECT TOP 1 FYStart, FYEnd FROM PP_Year WHERE IsOpen = 1 ORDER BY FYStart DESC
   - Validate: @PRDate BETWEEN @FYStart AND @FYEnd — if outside, RAISERROR with HTTP 400
5. Update merged.sql with the change
6. Write the FY check as a reusable inline query (not a separate SP — keep it simple)

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
