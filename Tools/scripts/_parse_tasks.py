import json, re
from pathlib import Path

ap_file = Path(r"D:\SpinriseV2\Daily Action Points\ActionPoints_Abinandan_2026-05-30.md")
text = ap_file.read_text(encoding="utf-8") if ap_file.exists() else "(file not found)"

tasks = [
    {"id": "T01A", "priority": "CRITICAL", "type": "SP",       "title": "PR Form — HF-21a FY Check SP Fix",
     "risk": "HIGH",   "notify": ["mariyaiya.m@kalsofte.com", "muthuvel.m@kalsofte.com"],
     "sp_pattern": "ksp_PR_",   "branch": "fix/pr-form-fy-check"},
    {"id": "T01B", "priority": "CRITICAL", "type": "BACKEND",  "title": "PR Form — Remaining Defects Backend (IL-31, IL-03a, IL-08a, IL-22, FN-03, DL-06, IL-13)",
     "risk": "HIGH",   "notify": ["mariyaiya.m@kalsofte.com", "muthuvel.m@kalsofte.com"],
     "sp_pattern": "ksp_PR_",   "branch": "fix/pr-form-defects-be"},
    {"id": "T01C", "priority": "CRITICAL", "type": "FRONTEND", "title": "PR Form — Print Defects PR-06 PR-12 PR-20",
     "risk": "MEDIUM", "notify": ["palanivel@kalsofte.com"],
     "sp_pattern": None,        "branch": "fix/pr-form-print"},
    {"id": "T02",  "priority": "CRITICAL", "type": "EMAIL",    "title": "IL-17 Root Cause Description Correction",
     "risk": "LOW",   "notify": ["qa@kalsofte.com"],
     "sp_pattern": None,        "branch": None},
    {"id": "T03",  "priority": "HIGH",     "type": "SP",       "title": "PR Foreclosure — FC-EX-09/BR-03 Option A SP Fix",
     "risk": "HIGH",   "notify": ["palanivel@kalsofte.com"],
     "sp_pattern": "ksp_PR_Foreclosure",  "branch": "fix/foreclosure-fc-ex-09"},
    {"id": "T04",  "priority": "HIGH",     "type": "SP",       "title": "PR Cancellation — SP-I1 rowversion + Trans_Name Fix",
     "risk": "HIGH",   "notify": ["palanivel@kalsofte.com"],
     "sp_pattern": "ksp_PR_UndoCancellation", "branch": "fix/cancellation-sp-i1"},
    {"id": "T05",  "priority": "HIGH",     "type": "EMAIL",    "title": "PR First Level — OI-05 DirectApp Confirmation to QA",
     "risk": "LOW",   "notify": ["qa@kalsofte.com"],
     "sp_pattern": None,        "branch": None},
    {"id": "T06",  "priority": "HIGH",     "type": "EMAIL",    "title": "PR Final Level — v1.2 vs v1.4 Baseline Conflict Clarification",
     "risk": "LOW",   "notify": ["qa@kalsofte.com"],
     "sp_pattern": None,        "branch": None},
    {"id": "T07",  "priority": "POST_PILOT","type": "FULLSTACK","title": "PR Second Level Approval — Full Build (FSD v1.3)",
     "risk": "HIGH",   "notify": ["sasikumar.r@kalsofte.com", "qa@kalsofte.com"],
     "sp_pattern": "ksp_PRSecondlevel", "branch": "feature/pr-second-level-v1.3"},
    {"id": "T08",  "priority": "POST_PILOT","type": "BACKEND",  "title": "PR First Level — OI-07 Per-Line Not-Approved Reset",
     "risk": "MEDIUM", "notify": ["qa@kalsofte.com"],
     "sp_pattern": "ksp_PR_FirstLevel",  "branch": "fix/oi-07-per-line-reset"},
]

out = Path(r"D:\SpinriseV2\Prompts\Tasks\2026-05-30\_task_manifest.json")
out.write_text(json.dumps(tasks, indent=2), encoding="utf-8")
print(f"Written {len(tasks)} tasks to {out}")
for t in tasks:
    print(f"  [{t['id']}] {t['priority']:<12} {t['type']:<10} {t['title']}")
