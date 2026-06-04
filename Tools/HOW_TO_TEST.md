# How to Test — Spinrise ERP V2
**Why this exists:** Every bug fix was communicated verbally, which made partial fixes invisible and caused debugging loops. These two tools generate a written, reproducible record of what passed and what failed — so every session starts from facts, not memory.

---

## Tool 1 — PowerShell API Test Runner (5 minutes to start)

Tests every backend endpoint. Logs full request + response + PASS/FAIL to a markdown file.

### One-time setup
None. PowerShell is already installed.

### Fill credentials
Open `Tools/Test-SpinriseAPI.ps1` and fill:
```powershell
[string]$BaseUrl  = "http://localhost:5000/api/v1"   # or 5001 for IIS
[string]$DivCode  = "KAL"                             # your division code
[string]$User     = "your_username"
[string]$Pass     = "your_password"
[string]$YfDate   = "2026-04-01"
[string]$YlDate   = "2027-03-31"
```

### Run
```powershell
cd D:\SpinriseV2\Tools
.\Test-SpinriseAPI.ps1
```

### Output
A file like `TestResults_2026-05-28_14-30-00.md` opens automatically showing:

```
## Summary
| Total | Pass | Fail |
|   10  |   8  |   2  |

### ❌  FC-01  Open lines — returns records
GET http://localhost:5000/api/v1/pr-foreclosure/open-lines
HTTP Status: 200
Assertions:
- ✅ status:200 — HTTP 200
- ❌ data.length>0 — data.length = 0 (expected > 0)
Response: {"success":true,"data":[],...}
```

### Share this file when reporting a bug
Instead of describing what happened → attach the `TestResults_*.md` file. It has the exact API response so Claude Code can diagnose without guessing.

---

## Tool 2 — Playwright UI Test Runner (15 minutes to start)

Automates browser actions. Takes screenshots. Records video on failure. Confirms checkbox behavior, button styles, modal auto-open, status labels.

### One-time setup
```powershell
cd D:\SpinriseV2\Tools\playwright
npm install
npx playwright install chromium
```

### How login works (important)
The tests do NOT use the login UI (Ant Design Select cannot be reliably automated).  
Instead: the test calls the API directly → gets a JWT token → injects it into  
`localStorage` under key `spinrise-auth-v2` before the React app boots.

Credentials are already filled (DIV_CODE=01, USERNAME=kalsofte, PASSWORD=kalsofte).  
Change them in `foreclosure.spec.ts` lines 22-24 if needed.

### Run (frontend + backend must both be running)
```powershell
# Terminal 1 — backend
cd D:\SpinriseV2\Development\Backend\Spinrise.API
dotnet run

# Terminal 2 — frontend
cd D:\SpinriseV2\Development\spinrise-web
npm run dev

# Terminal 3 — run the tests
cd D:\SpinriseV2\Tools\playwright
npx playwright test --headed          # browser visible
npx playwright test                   # headless (faster)
npx playwright show-report report     # open HTML report
```

### What it tests
| Test | What it checks |
|---|---|
| FC-01 | Banner has no technical SP details |
| FC-02 | Checkbox selects only its own row (not all same-PR rows) |
| FC-03 | Clicking row body does NOT select the row |
| FC-04 | PR Date column is non-empty |
| FC-05 | Status shows "Requested" / "Enquired" etc., not raw C / F chars |
| FC-07 | Confirm Foreclosure button has background color (not plain browser button) |
| FC-08 | Select All and Clear work correctly |
| CN-01 | Cancel modal auto-opens on page load |
| CN-02 | Cancellable PR list shows records |
| CN-03 | Selecting a PR loads its header + items |
| CN-04 | Cancel without reason shows validation error |

---

## The Testing Workflow

```
1. Fix a bug in SP / C# / .tsx
2. Deploy SP: run merged.sql in SSMS
3. Restart API (stop app pool → dotnet publish → start app pool)
4. Run: .\Test-SpinriseAPI.ps1
5. Check the markdown output — ALL ✅? Done. Any ❌? Share the file.
6. If UI fix: run npm run test:headed in playwright folder
7. Attach TestResults_*.md and playwright/report to the bug report
```

---

## Why you cannot describe bugs verbally and expect correct fixes

When a bug is described as *"checkbox not working as expected"*, Claude Code must guess:
- Which checkbox? Header or row?
- Not working how? Selects wrong row? Doesn't respond at all? Double-triggers?
- What's the actual API response when it happens?

When you share `TestResults_2026-05-28.md`, the diagnosis is immediate:
- FC-02 ❌: *data.length = 0* → the SP still has the wrong cancelflag filter
- FC-02 ❌: *data[0].pRDate = ''* → prdate is NULL in the database
- FC-05 ❌: *status text = 'C'* → CASE statement in SP not deployed

**One markdown file = exact state of the system = correct fix on first attempt.**

---

## Adding new tests

To add a new API test, add this block to `Test-SpinriseAPI.ps1`:
```powershell
Invoke-Test -Category "MyModule" -Name "My test description" `
    -Method GET -Endpoint "my-endpoint?param=value" `
    -Expect @("status:200", "success:true", "data.length>0")
```

Available assertions:
- `status:200` — HTTP status code
- `success:true` / `success:false` — response envelope
- `data.length>0` — array has items
- `data.length=0` — array is empty
- `data[0].fieldName!=` — first item's field is non-empty
- `data.header!=` — header object is present
- `data.lines.length>0` — lines array has items
