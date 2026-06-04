import sys, openpyxl
sys.stdout.reconfigure(encoding='utf-8')
refs = ['IL-31','IL-03','IL-08','IL-22','FN-03','DL-06','IL-13']
wb = openpyxl.load_workbook(
    r'D:\SpinriseV2\Docs\Testing Reports\SpinRise_M01_PR_IST_Checklist_v1.1 with CR v1.5 traceability matrix_Retest.xlsx',
    read_only=True, data_only=True)
ws = wb['1. PR Form']
for row in ws.iter_rows(values_only=True):
    if not row or row[0] is None:
        continue
    tc = str(row[0])
    for r in refs:
        if r.upper() in tc.upper():
            cols = [str(c) if c is not None else '' for c in row]
            print(f'=== {tc} ===')
            print(f'  Field  : {cols[1][:100] if len(cols)>1 else ""}')
            print(f'  Steps  : {cols[2][:150] if len(cols)>2 else ""}')
            print(f'  Expect : {cols[5][:150] if len(cols)>5 else ""}')
            print(f'  Status : {cols[6] if len(cols)>6 else ""}')
            print(f'  Actual : {cols[7][:150] if len(cols)>7 else ""}')
            print()
            break
