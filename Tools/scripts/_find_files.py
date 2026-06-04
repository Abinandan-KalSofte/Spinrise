import subprocess, json
from pathlib import Path

base = Path(r"D:\SpinriseV2\Development")
out_file = Path(r"D:\SpinriseV2\Prompts\Tasks\2026-05-30\_file_index.json")

def sls(pattern, path, ext):
    """Use PowerShell Select-String for Windows compatibility."""
    if not Path(str(path)).exists():
        return [f"PATH-NOT-FOUND: {path}"]
    try:
        cmd = (
            f'Get-ChildItem -Path "{path}" -Recurse -Filter "*.{ext}" | '
            f'Select-String -Pattern "{pattern}" | '
            f'Select-Object -ExpandProperty Path | Sort-Object -Unique'
        )
        r = subprocess.run(
            ["powershell", "-NoProfile", "-Command", cmd],
            capture_output=True, text=True, timeout=30
        )
        lines = [p.strip() for p in r.stdout.strip().splitlines() if p.strip()]
        return lines if lines else []
    except Exception as e:
        return [f"ERROR: {e}"]

index = {
    "sp_pr_form":       sls("ksp_PR_",              base / "Backend/Spinrise.DBScripts", "sql"),
    "sp_foreclosure":   sls("Foreclosure",           base / "Backend/Spinrise.DBScripts", "sql"),
    "sp_cancellation":  sls("UndoCancellation",      base / "Backend/Spinrise.DBScripts", "sql"),
    "sp_second_level":  sls("SecondLevel",           base / "Backend/Spinrise.DBScripts", "sql"),
    "sp_first_level":   sls("FirstLevel",            base / "Backend/Spinrise.DBScripts", "sql"),
    "be_pr_controller": sls("PurchaseRequisition",   base / "Backend/Spinrise.API",       "cs"),
    "be_pr_service":    sls("PRService",             base / "Backend/Spinrise.Application","cs"),
    "be_cancellation":  sls("UndoCancellation",      base / "Backend",                    "cs"),
    "be_second_level":  sls("SecondLevel",           base / "Backend",                    "cs"),
    "fe_pr_form":       sls("PurchaseRequisition",   base / "spinrise-web/src",           "tsx"),
    "fe_print":         sls("QuestPDF|PRPrint",      base / "Backend",                    "cs"),
    "fe_second_level":  sls("SecondLevel",           base / "spinrise-web/src",           "tsx"),
    "merged_sql":       [str(base / "Backend/Spinrise.DBScripts/merged.sql")],
}

out_file.write_text(json.dumps(index, indent=2), encoding="utf-8")
print("File index written:")
for k, v in index.items():
    count = len(v)
    print(f"  {k:<25}: {count} file(s)")
    for f in v[:3]:
        print(f"    -> {f}")
    if count > 3:
        print(f"    ... +{count-3} more")
