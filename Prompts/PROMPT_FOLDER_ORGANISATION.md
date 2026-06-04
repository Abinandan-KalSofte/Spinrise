# SPINRISE V2 — Project Folder Organisation Prompt
**Generated:** 03 Jun 2026 | **Scope:** D:\SpinriseV2\ (full tree audit)

---

## Context

You are the Dev Architect & Chief of Staff for Spinrise ERP V2.
The working directory is `D:\SpinriseV2\`.
This prompt asks you to clean and reorganise the project folder so that every
file is in a logical, predictable location. No source code is touched.
No git-tracked files under `Development\` are moved or renamed.

---

## Current State — Issues Found

### Issue 1 — Junk files at project root
Three zero-byte (or near-zero) garbage files exist at `D:\SpinriseV2\`:
```
=0.40.0      (0 bytes)
=1.1.0       (3,507 bytes — accidental pip/npm output file)
=3.1.0       (0 bytes)
```
**Action:** Delete all three.

---

### Issue 2 — Two separate Email folders (consolidation needed)
`D:\SpinriseV2\Email\` exists alongside the official store at `D:\SpinriseV2\Docs\Email\`.
Per CLAUDE.md, `Docs\Email\` is the canonical email store.

`D:\SpinriseV2\Email\` contains:
- 34 `.eml` files (May 2026 project emails)
- `Drafts\` subfolder with 7 draft `.eml` files

**Action:**
1. Move all `.eml` files from `D:\SpinriseV2\Email\` → `D:\SpinriseV2\Docs\Email\archive\`
2. Move `D:\SpinriseV2\Email\Drafts\` → `D:\SpinriseV2\Docs\Email\Drafts\`
3. Delete the now-empty `D:\SpinriseV2\Email\` folder

---

### Issue 3 — Loose files dumped at `Docs\` root (should be in subfolders)

| File | Move To |
|------|---------|
| `CEO_Gap_Analysis_Report_M01_PRForeclosure_Cancellation_29May2026.docx` | `Docs\Testing Reports\PR Foreclosure & Cancellation\` |
| `CLAUDE_CODE_GUIDE_PRForeclosure_Cancellation.md` | `Docs\Plans\` |
| `GAPS_M01_PRForeclosure_Cancellation.md` | `Docs\FSD-Compliance\` |
| `MOBILE_RESPONSIVENESS_PLAN.md` | `Docs\Plans\` |
| `PLAN_M01_PRForeclosure_Cancellation.md` | `Docs\Plans\` |
| `PROMPT_M01_PRForeclosure_Cancellation_BugFix.md` | `Prompts\` (root-level Prompts folder) |
| `SpinriseV2_M01_FSD_Compliance_Email.docx` | `Docs\FSD-Compliance\` |
| `fsd-to-md.py` | `Tools\scripts\` |
| `generate_ceo_report.py` | `Tools\scripts\` |
| `generate_email_doc.py` | `Tools\scripts\` |

**Action:** Move each file to the target folder listed above. Create `Tools\scripts\` if it does not exist.

---

### Issue 4 — Duplicate FSD files in `Docs\Approved FSDs\docss\`

`Docs\Approved FSDs\docss\` contains:
- `SPINRISE_FSD_M01_PRForeclosure_Cancellation_v1.1.docx` — duplicate of file already in parent folder
- `SPINRISE_FSD_M01_PRForeclosure_Cancellation_v1.1_converted.md` — intermediate conversion file, no longer needed

**Action:** Delete the entire `Docs\Approved FSDs\docss\` folder (both files are redundant).

---

### Issue 5 — Old deployment export packages bloating `Exports\`

Five packages exist, all created on 03-Jun-2026. Only the latest is the valid deployment:

| Folder | Time | Status |
|--------|------|--------|
| `SpinriseV2_Package_20260603_1203` | 12:03 | Superseded |
| `SpinriseV2_Package_20260603_1224` | 12:24 | Superseded |
| `SpinriseV2_Package_20260603_1233` | 12:33 | Superseded |
| `SpinriseV2_Package_20260603_1310` | 13:10 | Superseded |
| `SpinriseV2_Package_20260603_1501` | 15:01 | **KEEP — Latest** |

Also, `Exports\` contains three `.md` files that are not export artifacts:
- `Blueprint_v1.2.md`
- `FSD_v2.3_Amendment.md`
- `IIS Settings.md`

**Action:**
1. Confirm with user before deleting the 4 superseded packages (destructive — large folders).
2. Move `Blueprint_v1.2.md` → `Docs\Blueprint\`
3. Move `FSD_v2.3_Amendment.md` → `Docs\Approved FSDs\`
4. Move `IIS Settings.md` → `Docs\Plans\`

---

### Issue 6 — Testing Reports files scattered (not in module subfolders)

The following files are loose at `Docs\Testing Reports\` root instead of inside their module subfolder:

| File | Move To |
|------|---------|
| `Copy of SpinRise_M01_PR_IST_Foreclosure_Checklist_v1_0-1.csv` | `Docs\Testing Reports\PR Foreclosure & Cancellation\` |
| `CR_v1.5_Fix_Verification_Checklist.md` | `Docs\Testing Reports\PR Foreclosure & Cancellation\` |
| `M01_PR_FixVerification_Checklist_2026-05-23.md` | `Docs\Testing Reports\PR Foreclosure & Cancellation\` |
| `Muthuvel_SpinRise_M01_PR_IST_Checklist_v1.1 with CR v1.5 traceability matrix.xlsx` | `Docs\Testing Reports\PR Foreclosure & Cancellation\` |
| `SPINRISE M01 PR Amendment IST Findings feedback checklist.csv` | `Docs\Testing Reports\PR Amendment\` |
| `SPINRISE_CR_PRForm_Functional_v1.4.docx` | `Docs\Testing Reports\PR Foreclosure & Cancellation\` |
| `SPINRISE_CR_PRForm_Functional_v1.5.docx` | `Docs\Testing Reports\PR Foreclosure & Cancellation\` |
| `SpinRise_M01_PR_IST_Checklist_v1.1 with CR v1.5 traceability matrix.csv` | `Docs\Testing Reports\PR Foreclosure & Cancellation\` |
| `SpinRise_M01_PR_IST_Checklist_v1.1 with CR v1.5 traceability matrix_Retest.csv` | `Docs\Testing Reports\PR Foreclosure & Cancellation\` |
| `SpinRise_M01_PR_IST_Checklist_v1.1 with CR v1.5 traceability matrix_Retest.xlsx` | `Docs\Testing Reports\PR Foreclosure & Cancellation\` |
| `SpinRise_M01_PR_IST_Checklist_v1.1.xlsx` | `Docs\Testing Reports\PR Foreclosure & Cancellation\` |

**Action:** Move each file to the target subfolder listed above.

---

### Issue 7 — `Daily Action Points\` is a standalone folder outside `Docs\`

Contains only 2 files:
- `ActionPoints_Abinandan_2026-05-30.md`
- `TaskTracker_2026-05-30.md`

**Action:** Move both files to `Docs\ChangeLog\` (daily action points and work logs belong together). Delete the now-empty `Daily Action Points\` folder.

---

### Issue 8 — Python utility scripts mixed with Prompts tasks

`Prompts\Tasks\2026-05-30\` contains task `.md` files mixed with Python utility scripts:
- `_find_files.py`, `_parse_tasks.py`, `_read_defects.py`, `_read_print_defects.py`
- `_file_index.json`, `_task_manifest.json`

**Action:** Move the 4 `.py` files and 2 `.json` files to `Tools\scripts\`.

---

## Target Folder Structure After Organisation

```
D:\SpinriseV2\
├── .claude\                        (unchanged)
├── .github\                        (unchanged)
├── CLAUDE.md                       (unchanged)
├── .gitignore                      (unchanged)
├── export_package.bat              (unchanged)
│
├── Development\                    (NEVER touch — git source)
│   ├── Backend\
│   └── spinrise-web\
│
├── Docs\
│   ├── Approved FSDs\              (clean — no docss\ subfolder)
│   │   ├── Amendment\
│   │   ├── M01 Final Level Approval\
│   │   └── M01_PRFirstLevelApproval_v1.1\
│   ├── Blueprint\                  (+ Blueprint_v1.2.md moved here)
│   │   └── html\
│   ├── ChangeLog\                  (+ Daily Action Points files moved here)
│   ├── Crystal report\
│   ├── DB_Schema\
│   ├── Email\
│   │   ├── archive\                (NEW — old May 2026 emails from Email\ root)
│   │   ├── Drafts\                 (moved from Email\Drafts\)
│   │   └── recent\
│   ├── Extracted\
│   ├── FSD-Compliance\             (+ GAPS and compliance email doc moved here)
│   ├── Plans\                      (+ plan/guide .md files moved here + IIS Settings.md)
│   ├── Testing Reports\
│   │   ├── PR Amendment\           (+ amendment checklist moved here)
│   │   ├── PR First Approval\
│   │   └── PR Foreclosure & Cancellation\  (+ all loose checklists moved here)
│   └── UI_UX Designs\
│
├── Exports\
│   └── SpinriseV2_Package_20260603_1501\   (only latest kept)
│
├── Prompts\
│   ├── Tasks\
│   │   └── 2026-05-30\             (task .md files only — scripts moved to Tools\scripts\)
│   └── *.md                        (prompt files)
│
└── Tools\
    ├── email_agent\
    ├── playwright\
    └── scripts\                    (NEW — Python utility scripts + JSON manifests)
```

---

## Execution Order

Run these steps in order. Stop and ask user before Step 5 (deletes large export packages).

**Step 1** — Delete junk root files (`=0.40.0`, `=1.1.0`, `=3.1.0`)

**Step 2** — Create new folders:
- `Docs\Email\archive\`
- `Docs\Email\Drafts\`
- `Tools\scripts\`

**Step 3** — Consolidate Email folders (Issue 2)

**Step 4** — Move loose `Docs\` root files (Issue 3)

**Step 5** — Delete `Docs\Approved FSDs\docss\` (Issue 4)

**Step 6** — Move `.md` files from `Exports\` root (Issue 5, non-destructive part)

**Step 7** — ⚠️ CONFIRM WITH USER: Delete 4 superseded export packages (Issue 5, destructive)

**Step 8** — Move Testing Reports files to module subfolders (Issue 6)

**Step 9** — Move `Daily Action Points\` files to `Docs\ChangeLog\` (Issue 7)

**Step 10** — Move Python/JSON files from `Prompts\Tasks\2026-05-30\` to `Tools\scripts\` (Issue 8)

**Step 11** — Verify no broken paths in `CLAUDE.md`, `MEMORY.md`, or email agent config

---

## Hard Rules

- Do NOT touch anything under `Development\` — that is the git repo
- Do NOT rename any file — only move to a better location
- Do NOT delete any `.docx`, `.md`, `.sql`, `.cs`, `.tsx` that looks like project content
- Always confirm before deleting folders with more than 5 files or total size > 10 MB
- After moves, update `CLAUDE.md` `Persistent Tools` section if any path changed
- After moves, update `memory\MEMORY.md` if any referenced path changed

---

## Verification Checklist After Completion

```
[ ] No files at D:\SpinriseV2\ root except: CLAUDE.md, .gitignore, export_package.bat
[ ] D:\SpinriseV2\Email\ folder no longer exists
[ ] Docs\Email\archive\ contains the 34 old .eml files
[ ] Docs\Email\Drafts\ contains the 7 draft .eml files
[ ] Docs\ root has no loose .py, .docx, .md files (except MODULE_TRACKER.md)
[ ] Docs\Approved FSDs\docss\ no longer exists
[ ] Exports\ contains only SpinriseV2_Package_20260603_1501\ (and no .md files)
[ ] All Testing Report files are inside a module subfolder
[ ] Tools\scripts\ contains all utility .py and manifest .json files
[ ] Daily Action Points\ folder no longer exists
[ ] email_agent config.json paths still valid
[ ] CLAUDE.md Persistent Tools paths still valid
```
