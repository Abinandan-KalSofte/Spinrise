# TASK T02 — IL-17 Root Cause Description Correction
Priority: CRITICAL | Type: EMAIL | Risk: LOW | Branch: none

## Context
IL-17 in the IST test sheet currently has root cause description = "Claude Code Mistake".
This must be corrected to the actual technical defect description before pilot sign-off.
CEO direction: IL-17 root cause must reflect the real technical cause, not the tool.

## What to Do
1. Search for IL-17 in Docs folder:
   ```powershell
   Get-ChildItem "D:\SpinriseV2\Docs" -Recurse | Select-String -Pattern "IL-17|IL17" | Select-Object Path, LineNumber, Line
   ```
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
Format: .eml plain text (X-Mozilla-Status: 0000 header, MIME plain/text)

## Log Entry
Append to: D:\SpinriseV2\Docs\ChangeLog\2026-05-30_session_pilot-fixes.md
| [TIME] | Email | IL-17 | N/A | Root cause correction email drafted | CEO direction |
Status: COMPLETED (if doc updated) / PENDING-RESPONSE (if awaiting Mariyaiya confirm)
