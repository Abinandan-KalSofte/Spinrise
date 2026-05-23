# M01 PR — Fix Verification Checklist
**Branch:** `feature/m01-pr`  
**Date:** 23 May 2026  
**Prepared for:** Muthuvel M (Tester), Palanivel V (TL-IST)  
**Environment:** UAT → `http://172.16.16.40:3000` / API `http://172.16.16.40:5001` / DB `SpinRiseSaranya`

> **How to use:** Work top-to-bottom. Each section is a defect group. Tick the checkbox when the item passes. If it fails, note the TC ID and raise a new defect item.

---

## Pre-Check — Deploy Readiness

Before running any test cases, confirm the following are deployed:

- [ ] Backend deployed: IIS app pool stopped → `dotnet publish` → app pool started
- [ ] Frontend deployed: `npm run build` → `dist/` copied to IIS port 3000
- [ ] `merged.sql` executed against `SpinRiseSaranya` in SSMS
- [ ] Login works: open `http://172.16.16.40:3000` and sign in as KALSOFTE

---

## Section 1 — Header / Date Validation (D-01 · HF-21/22/23/25)

**Commits:** `9045416`  
**What was fixed:** `disabledDate` now restricts picker to open FY only; last-PR-date rule blocks backdated entry; inline error names the actual last PR date.

| # | Step | Expected | Pass/Fail |
|---|------|----------|-----------|
| 1 | Click **+ New**, open the PR Date picker | Dates outside the current FY (before 01-Apr-2026 or after 31-Mar-2027) are greyed out / unselectable in the picker | |
| 2 | With the picker open, attempt to click a date in a prior FY (e.g. 15-Mar-2026) | Picker blocks selection; date is not accepted | |
| 3 | Note the last saved PR date for your division (e.g. 21-May-2026). Pick a PR Date earlier than that (e.g. 17-May-2026) | Inline field error appears immediately on date selection (not on Save): `"PR Date cannot be earlier than last PR date (21-May-2026) for this division."` — exact date shown | |
| 4 | Pick PR Date = same as last PR date (e.g. 21-May-2026) | No error; date accepted | |
| 5 | Pick PR Date = future date within FY (e.g. 25-May-2026) | No error; date accepted | |

**TC IDs:** HF-21, HF-22, HF-23, HF-25

---

## Section 2 — Record Navigation (D-04 · NV-02/03/04)

**Commit:** `9045416`  
**What was fixed:** `findIndex` now matches on `prNo` only — was previously matching on `prNo + prDate` causing a format-mismatch that sent navigation to the wrong record.

| # | Step | Expected | Pass/Fail |
|---|------|----------|-----------|
| 1 | In View mode, click **«** (First) | Loads the first PR (e.g. PR-00001); **«** and **‹** buttons become disabled | |
| 2 | From first PR, click **›** (Next) | Loads PR-00002 (the immediately next record, not a random jump) | |
| 3 | From PR-00002, click **‹** (Previous) | Returns to PR-00001 | |
| 4 | Click **»** (Last) | Loads the most recent PR; **›** and **»** buttons become disabled | |
| 5 | Navigate to a middle PR, note the PR No., then navigate away and back | Returns to the exact same record, not an offset one | |

**TC IDs:** NV-02, NV-03, NV-04

---

## Section 3 — Delete Mode Toolbar (D-02 · D-05 · R-01 · DL-10 to DL-15)

**Commits:** `9045416`, `3378e75` (R-01 today)  
**What was fixed:** `isDeleteMode` guard applied to New, Find, and Status field. Line-delete `wasEditing` guard preserves edit state. Post-delete returns to View mode.

| # | Step | Expected | Pass/Fail |
|---|------|----------|-----------|
| 1 | In View mode, click **Delete** | Delete picker modal opens | |
| 2 | While modal is open (before selecting a record), check toolbar | **New** button is **disabled**; **Find** button is **disabled** | |
| 3 | Select a PR row in the delete modal (single click) | Row highlighted; "Select to Delete →" button enables; New and Find remain **disabled** | |
| 4 | Close the delete modal (click X / Cancel) | Toolbar returns to View defaults — New and Find become **enabled** | |
| 5 | Re-open Delete, pick a PR, confirm deletion (click Yes on confirmation) | PR is removed; form auto-loads the next-most-recent PR in **View mode**; Save and Cancel are **disabled** | |
| 6 | In Modify or Delete mode, check the Approval Status stepper/field | Status field / stepper is **not visible** (hidden in these modes) | |
| 7 | Open a PR with 2+ lines in **Modify mode**. Delete one line (click trash icon). | Confirmation dialog: `"Do you want to remove this item?"`. On Yes: line is removed; form stays in edit mode (**not** redirected to query mode). Save button remains enabled. | |
| 8 | With exactly 1 line remaining in a PR, inspect the trash icon on that row | Trash icon is **disabled** — cannot delete the last line | |

**TC IDs:** DL-06 (see Section 9), DL-10, DL-11, DL-12, DL-13, DL-14, DL-15, IL-31, CR-PR-01 (R-01)

---

## Section 4 — Item Grid Duplicate Notification (D-03 · D-21 · IL-22 · IL-03e)

**Commit:** `9045416`  
**What was fixed:** Duplicate item+machine detection now shows `Modal.warning` (centred dialog) instead of a dismissable top-of-form toast. User must click OK before further input is accepted.

| # | Step | Expected | Pass/Fail |
|---|------|----------|-----------|
| 1 | Add an item (e.g. 1104001) with machine M1 to a new PR | Item added successfully | |
| 2 | Try to add the same item 1104001 again with the same machine M1 | A **centred modal warning dialog** appears: `"1104001 with the same machine is already in the list"`. The item is NOT added to the grid. | |
| 3 | Without clicking OK, try to type in another field | Form does not accept input — user must acknowledge the modal first | |
| 4 | Click OK on the modal | Modal closes; user can continue editing | |
| 5 | Try to add item 1104001 with a different machine M2 | Item is **added** without any warning (different machine = allowed) | |

**TC IDs:** IL-22, IL-03e

---

## Section 5 — Item Picker — Last PO Rate Decimal (D-08 · IL-03 · IL-10)

**Commit:** `6bb6378`  
**What was fixed:** Last PO Rate column in the item picker modal now always shows exactly 4 decimal places.

| # | Step | Expected | Pass/Fail |
|---|------|----------|-----------|
| 1 | In New/Modify mode with header complete, click any Item Id cell | Item Selection modal opens | |
| 2 | Inspect the **Last PO Rate** column for any item that has a prior PO | Value shows exactly 4 decimal places: e.g. `27.0000`, `145.5000`, `1.0000` — never truncated to 1 or 2dp | |
| 3 | For an item with a whole-number rate (e.g. rate = 500) | Displays `500.0000` | |

**TC IDs:** IL-03, IL-10

---

## Section 6 — PR Find Modal Filter (D-11 · FN-03)

**Commit:** `6bb6378`  
**What was fixed:** The filter box now searches across `prNo`, `depName`, `reqEmpName`, **`iType`** (Requisition Type), and **`iDesc`** (Description).

| # | Step | Expected | Pass/Fail |
|---|------|----------|-----------|
| 1 | Click **Find**; in the search box type a Requisition Type keyword (e.g. `EMERGENCY`) | List narrows to show only EMERGENCY-type PRs | |
| 2 | Clear and type part of a Department name (e.g. `BUFF`) | List narrows to PRs from BUFFING department | |
| 3 | Clear and type a PR number prefix (e.g. `PR-000`) | List narrows accordingly | |
| 4 | Clear filter | Full list restored | |

**TC IDs:** FN-03

---

## Section 7 — Indian Number Formatting in Grid (D-12 · IL-13)

**Commit:** `6bb6378`  
**What was fixed:** `ROCell` and `PRKPIStrip` now use `toLocaleString('en-IN')` consistently. KPI Approx. Budget shows exactly 2dp.

| # | Step | Expected | Pass/Fail |
|---|------|----------|-----------|
| 1 | Open a PR with a line where Qty × Rate > 1 lakh (e.g. Qty=100, Rate=2000 → ₹2,00,000.00) | Approx. Value cell shows Indian grouping: `2,00,000.00` (lakh separator, not `200,000.00`) | |
| 2 | Open a PR with a line > 10 lakh (e.g. ₹12,50,000.00) | Crore/lakh grouping correct | |
| 3 | Inspect the **Approx. Budget** KPI card total | Shows exactly **2 decimal places** with Indian grouping | |
| 4 | Qty column shows **3 decimal places** (e.g. `2.000`) | |
| 5 | Rate column shows **4 decimal places** (e.g. `145.0000`) | |

**TC IDs:** IL-13, IL-12 (Rate symbol verify), IL-09

---

## Section 8 — Breadcrumb Truncation (D-13 · PL-01)

**Commit:** `c682fca`  
**What was fixed:** Breadcrumb container gets `flex:1 / overflow:hidden / minWidth:0` — text no longer truncates at narrow viewports.

| # | Step | Expected | Pass/Fail |
|---|------|----------|-----------|
| 1 | Open Purchase Requisition at standard desktop resolution | Breadcrumb shows full text: `Purchase Order / Purchase Requisition` | |
| 2 | Resize browser to ~900px wide | Breadcrumb still visible and not cut off mid-word; sidebar and header remain stable | |

**TC IDs:** PL-01

---

## Section 9 — Audit Log on Delete (D-09 · DL-06)

**Commit:** `9045416`  
**What was fixed:** `ksp_PR_Delete` now writes a `LogDet_po` INSERT row for both FULL PR delete and LINE-level delete. Host/IP passed from API layer.

| # | Step | Expected | Pass/Fail |
|---|------|----------|-----------|
| 1 | Delete a full PR (complete deletion flow) | In SSMS: `SELECT * FROM LogDet_po WHERE Trans_No = '<deleted PR No>' ORDER BY LogDate DESC` — a DELETE audit row exists with correct `Trans_Mod = 'D'`, `UserID`, and `HostName` | |
| 2 | In Modify mode, delete one line from a multi-line PR, then Save | In SSMS: `SELECT * FROM LogDet_po WHERE Trans_No = '<PR No>'` — a line-delete audit row exists | |

**TC IDs:** DL-06

---

## Section 10 — Sub Cost Centre Lookup (D-15 · IL-17)

**Commit:** `c682fca`  
**What was fixed:** Modal title changed from "Cost Centre Lookup" → "Sub Cost Centre Lookup"; column header "CC Code" → "SCC Code".

| # | Step | Expected | Pass/Fail |
|---|------|----------|-----------|
| 1 | In New/Modify mode, click the Sub Cost Centre cell in any line | Modal opens with title **"Sub Cost Centre Lookup"** | |
| 2 | Inspect the first column header | Shows **"SCC Code"** (not "CC Code") | |
| 3 | Select a cost centre | Value populates in the grid cell | |

**TC IDs:** IL-17

---

## Section 11 — Division Name on Form and Print (D-20 · HF-26/27)

**Commit:** `0facb12`  
**What was fixed:** `ksp_Auth_GetUserById` JOINs `PP_DIVMAS` to return `DivName`. Shown on form header and in QuestPDF print output.

| # | Step | Expected | Pass/Fail |
|---|------|----------|-----------|
| 1 | Log in and open the PR form | Top-right or header area shows the **Division NAME** (e.g. `JAT TECHNO SPINTEX MILL`), not the division code | |
| 2 | Log in as a user from a different division | Division NAME updates to that division's name | |
| 3 | Open any PR and click **Print** | In the PDF, the division identification area shows the Division **NAME**, not the code | |

**TC IDs:** HF-26, HF-27

---

## Section 12 — Print Column Layout (D-07 · R-02 · PR-06/12/18/20)

**Commits:** `46a19f5`, `3378e75` (R-02 today)  
**What was fixed:**  
- Column header: "Item Code" → "Item Id"  
- Required Qty and Current Stock Qty: 3 decimal places (N3)  
- Value column: 2 decimal places (N2)  
- PR Date/Time: actual creation time with 12h AM/PM format  
- R-02: Rate column widened `19.1→22.0mm`, Value column `24.1→27.7mm` — no more truncation on large values

| # | Step | Expected | Pass/Fail |
|---|------|----------|-----------|
| 1 | Open a PR and click **Print** | PDF opens in preview | |
| 2 | Inspect the item table column headers | Header reads **"Item Id"** (not "Item Code") | |
| 3 | Inspect Required Qty and Current Stock Qty columns for any line | Values show **3 decimal places** (e.g. `2.000`, `150.000`) | |
| 4 | Inspect the Value column for any line | Values show **2 decimal places** (e.g. `2,00,000.00`) — with Indian grouping | |
| 5 | Inspect the PR Date/Time in the meta block | Shows actual time with **AM/PM** (e.g. `21/05/2026 05:25 PM`), not `00:00` | |
| 6 | Use a PR with a Rate > ₹10,000 (large value) | Rate/Unit cell in the table is **not truncated** — full value visible (e.g. `12,500.0000`) | |
| 7 | Use a PR where Grand Total > ₹1,00,000 (e.g. PR #30) | Grand Total row is **not truncated** — full Indian-formatted value visible | |
| 8 | Use a PR where Rate/Unit = small decimal (e.g. `1.0000`) | Rate cell still aligned; no clipping | |

**TC IDs:** PR-06, PR-12, PR-18, PR-20

---

## Section 13 — Find Button Disabled in Delete Mode (R-01 · CR-PR-01)

**Commit:** `3378e75` (today)  
**What was fixed:** `PurchaseRequisitionPage.tsx` — Find button `disabled` prop now includes `|| isDeleteMode`.

| # | Step | Expected | Pass/Fail |
|---|------|----------|-----------|
| 1 | In View mode, confirm Find button is **enabled** | Clickable | |
| 2 | Click **Delete** (opens delete modal) | **Find** button immediately becomes **disabled / greyed out** | |
| 3 | Without selecting a record, close the delete modal (X) | **Find** button returns to **enabled** | |
| 4 | Click Delete again, select a record, then cancel (X) | **Find** button returns to **enabled** | |

**TC IDs:** CR-PR-01 (R-01 fix)

---

## Sign-Off

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Tester | MuthuVel M | | |
| TL-IST | Palanivel V | | |
| CEO | T Mani | | |

---

## Items NOT in this checklist (separate re-test or Sprint 2)

| TC | Reason |
|----|--------|
| IL-08a | Focus-after-item-pick — deploy + re-test required; not yet confirmed fixed |
| HF-19a | Tab-stop mandatory field notification — low priority; pending Sprint 1 sign-off |
| IL-28/29 | Image rendering in Line Details drawer — Phase 2 scope |
| SV-06/07 | KSP_INDEDNT_CHECK rule + double-submit guard — environment verify needed |
| MR-01..10 | Mobile responsive — Sprint 2 target, not a blocker for 30-May pilot |
