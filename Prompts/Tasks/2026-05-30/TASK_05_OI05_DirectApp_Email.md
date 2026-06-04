# TASK T05 — PR First Level: OI-05 DirectApp Confirmation Email
Priority: HIGH | Type: EMAIL | Risk: LOW | Branch: none

## Context
OI-05: DirectApp='Y' handling — CEO wants to confirm whether SPINRISE auto-detects
sole-approver customers from po_para level count OR requires a separate DirectApp flag.
QA needs Abinandan to state what the CURRENT deployed build does for OI-05.

## What to Do
1. Search deployed code for DirectApp handling:
   ```powershell
   Get-ChildItem "D:\SpinriseV2\Development" -Recurse | Select-String -Pattern "DirectApp|DIRECTAPP|directApp|sole_approver" | Select-Object Path, LineNumber, Line | Select-Object -First 20
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
Format: .eml plain text (X-Mozilla-Status: 0000 header, MIME plain/text)

## Log Entry
Append to: D:\SpinriseV2\Docs\ChangeLog\2026-05-30_session_pilot-fixes.md
| [TIME] | Email | OI-05 | N/A | DirectApp handling confirmed to QA | OI-05 |
Status: COMPLETED
