# TASK T07 — PR Second Level Approval: Full Build (FSD v1.3)
Priority: POST_PILOT | Type: FULLSTACK | Risk: HIGH | Branch: feature/pr-second-level-v1.3

## Context
FSD v1.3 countersigned by CEO at 10:15 AM today. Development baseline locked.
This is a full SP → Backend → Frontend build. Do NOT start until pilot is confirmed.

## File Index Note
- sp_second_level: 0 files found — Second Level SP does not exist yet (new build)
- be_second_level: 0 files found — Second Level backend does not exist yet (new build)
- fe_second_level: 0 files found — Second Level frontend does not exist yet (new build)
- Reference implementation (First Level): 0 SP files found — search manually:
  D:\SpinriseV2\Development\Backend\Spinrise.DBScripts\Scripts\02-StoredProcedures\

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
   → Follow CLAUDE.md feature module structure exactly:
     src/features/prSecondLevel/api/ store/ components/ pages/ hooks/ types.ts
7. Unit tests: Service layer + Repository layer (target 80%+)

## Token Efficiency Strategy
Use PowerShell to find First Level as reference implementation before writing:
```powershell
Get-ChildItem "D:\SpinriseV2\Development\Backend" -Recurse -Filter "*.cs" | Select-String -Pattern "FirstLevel|FirstApproval" | Select-Object Path | Sort-Object Path -Unique
```
Build Second Level as a parallel pattern to First Level — adapting only where FSD v1.3 differs.

## SP Schema Requirements (read before writing any SP)
- MANDATORY: Read D:\SpinriseV2\Docs\DB_Schema\SpinRiseSaranya_Schema.md
- Use CREATE OR ALTER PROCEDURE — never DROP + CREATE
- SET NOCOUNT ON at top; TRY/CATCH with ROLLBACK in transactional SPs
- No SELECT * — always list columns explicitly
- ksp_PRSecondlevel prefix for all Second Level SPs

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
Format: .eml plain text (X-Mozilla-Status: 0000 header, MIME plain/text)

## Log Entry
Append to: D:\SpinriseV2\Docs\ChangeLog\2026-05-30_session_second-level.md (separate log)
