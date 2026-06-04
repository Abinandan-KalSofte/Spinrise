# SPINRISE — FULLSTACK MODULE DEVELOPMENT PROMPT
## Module Instance: M01 Final Level PR Approval
## Base Template: PROMPT_02 v1.0 | 31-May-2026
## FSD: v1.4 | Mockdown: v1.0 28-May-2026 | UI/UX: SPINRISE_FSD_M01_PRFinalLevelApproval_v1_2.html

---

> **CRITICAL:** This prompt executes code generation only after ALL gates are passed.
> Mandatory sequence: Gap Register closed → DB migration → API contract → Backend → Frontend → QuestPDF → Stage 1
> Skipping any step is a process violation.

> **⛔ CURRENT STATUS: GATE 0 BLOCKED**
> Stage 3 (Domain review by Palanivel) = PENDING
> Stage 4 (CEO countersignature T. Mani) = PENDING
> This prompt file is READY for execution — begin ONLY after both stages are cleared.

---

# ROLE

Act as Senior Fullstack Developer for SPINRISE ERP.

You are implementing the M01 Final Level PR Approval module from:
1. Approved UI/UX design: `Docs/UI_UX Designs/SPINRISE_FSD_M01_PRFinalLevelApproval_v1_1/SPINRISE_FSD_M01_PRFinalLevelApproval_v1_2.html`
2. CEO-countersigned FSD: `Docs/Approved FSDs/M01 Final Level Approval/SPINRISE_FSD_M01_FinalLevel_PR_Approval_v1_4.docx`
3. Screen Mockdown: `Docs/Approved FSDs/M01 Final Level Approval/SPINRISE_M01_FinalLevel_PR_Approval_Mockdown.md`
4. SPINRISE Migration Blueprint v6.2

Your output is production-ready, deployable code.
You do not make UX decisions — those are locked in the approved design.
You do not make business rule decisions — those are locked in the FSD.
You raise gaps and stop if a required specification is missing.

Stack:
- Backend: ASP.NET Core 8, C#, Dapper, SQL Server
- Frontend: React 18, TypeScript, Ant Design 5, Zustand, AG Grid Community
- Reports: QuestPDF only
- Excel/CSV: EPPlus only

---

# INPUTS

```
MODULE:                M01 Purchase Order
SUBMODULE:             Final Level PR Approval
FSD VERSION:           v1.4   CEO-countersigned: [fill after Stage 4 sign-off]
UIUX DESIGN REF:       SPINRISE_FSD_M01_PRFinalLevelApproval_v1_2.html
BLUEPRINT:             v6.2
VB6 SOURCE FORM:       PRApproval_Final.aspx (ASP.NET WebForms — VB6-era logic)
VB6 LINE COUNT:        [confirm from Sasi at Stage 0 sign-off]
DB NAME:               JAT  (server: 172.16.16.52\sql2016 — never SpinRiseSaranya for M01)
API BASE URL:          http://172.16.16.40:5001/api/
FRONTEND URL:          http://172.16.16.40:3000/
JIRA EPIC:             M01-FINAL-APPROVAL
DEVELOPER:             Mohan Babu
SPRINT:                [fill on sprint start]
IMPLEMENTATION DATE:   [fill before running]
```

**COMBINED FSD NOTE:** FSD v1.4 covers Final Level PR Approval only. First Level Approval is a separate FSD/form. Run this prompt for Final Level Approval only.

---

# GATE 0 — PRE-DEVELOPMENT VERIFICATION

**Every item must be CONFIRMED before any code is generated.**
If any item is BLOCKED or UNKNOWN: stop. Report to Abinandan. Do not proceed.

```
GATE 0 CHECKLIST — M01 FINAL LEVEL PR APPROVAL

FSD:
  [ ] FSD version: v1.4  CEO-countersigned: ___-___-2026  CONFIRMED
      ⛔ CURRENTLY BLOCKED — Stage 4 pending as of 28-May-2026
  [ ] CEO countersignature date confirmed on document (not just "submitted" or "awaited")
  [ ] FSD v1.4 is current version (no later countersigned version exists)
  [ ] OI-09 resolution confirmed: FirstApp='Y' write removed from SPINRISE Final Level SP
  [ ] OI-08 confirmed: Final Level state is INDEPENDENT — no shared Zustand store with First/Second Level screens
  [ ] OBS-2 confirmed by Palanivel at Stage 3: imode=1 does NOT exist in ksp_po_finalapproval;
      Company=ALL uses imode=2 + divcode='0'
  [ ] OI-06 CEO Working Session gate: waived by CEO or Working Session held

UI/UX Design:
  [ ] UI/UX design v1_2 approved — sign-off by: _________
  [ ] All gaps in Gap Register = CLOSED or NOT-BLOCKING
  [ ] GAP-01 (SP-F1 CRITICAL) RESOLVED: imode=1 confirmed removed, OBS-2 applies

Domain Gaps:
  [ ] Bypass All behaviour confirmed by domain: Bypass=1 → SP returns PRs with any
      First Approval regardless of Second/Third status. Bypass=0 → only PRs that have
      cleared lower-level approvals. CONFIRM WITH PALANIVEL before coding.
  [ ] Disposition=Declined → FClosed='Y' on PO_PRL confirmed — no undo path (same as Foreclosure)
  [ ] Al_SMSMessage INSERT for ALL disposition codes (1–5) confirmed
  [ ] FinalLevel_Remarks DB column type: varchar(20) — store CAST(int AS varchar) from SP.
      No column type migration required. (CD-08 affects SP parameter only — not DB column.)
  [ ] Item Purchase History endpoint: confirm if already exists from PO module OR new endpoint needed
  [ ] Cross-database "Company=ALL" behaviour: confirm whether imode=2 queries within ONE DB
      (all divisions) or cross-database via linked server. Palanivel to confirm.

DB/Backend:
  [x] SP name confirmed: ksp_po_finalapproval (from Mockdown §4.3 — Sasi cleared Stage 2)
  [x] All required columns already exist on PO_PRL (verified against JAT_Schema.md):
        FinalAppUser varchar(35), FinalLevel_Remarks varchar(20), FinalAppQty numeric(12,3)
        DirectApp char(1), DirectAppDate datetime
        SecondApp char(1), ThirdApp char(1)
        FirstApp char(1) [retained in DB — NOT written by SPINRISE Final Level]
        APPCOST numeric(11,2), LPO_RATE numeric(13,4), LPO_DATE datetime
        row_version timestamp (already on PO_PRL — used for concurrency)
  [x] PO_PRH columns already exist: APPFLG, APP1/APP2/APP3, APP1DATE-APP3DATE,
        APP1TIME-APP3TIME (all verified against JAT_Schema.md)
  [x] No new DB columns required — migration script not needed (verify before running)
  [ ] Confirm KSP_PRItemStock_FUN / KSP_PRItemStock_WITH_DIV exist in JAT DB
  [ ] Confirm pp_database and pp_divmas tables exist in JAT DB for company/division dropdowns
  [ ] Confirm PO_Para table has PRSMSStatusFlg column (written on every imode=4 save)
  [ ] Confirm Al_SMSMessage table column names before writing INSERT in SP

VB6 Migration:
  [x] Stage 0 sign-off received: 23-May-2026 by Sasi (TL-Dev) — CLEARED
  [x] Stage 2 (TL-Dev review) sign-off: 27-May-2026 by Sasi — CLEARED
  [ ] Stage 3 (Domain review) sign-off: Palanivel — ⏳ PENDING
  [ ] Stage 4 (CEO countersignature): T. Mani — ⛔ PENDING
  [x] VB6 Migration Assumption Checklist: complete (see Step 1 below)

GATE 0 APPROVED BY: _________________ DATE: _________
```

---

# STEP 1 — VB6 MIGRATION ASSUMPTION CHECKLIST

| # | VB6 Pattern | Present? | SPINRISE Replacement | Risk if missed |
|---|---|---|---|---|
| 1 | MAX(n)+1 auto-number | **N** | Not applicable — no new document number generated in approval | N/A |
| 2 | Delete-all-lines Modify-save | **N** | Status-update module only — UPDATE existing rows, no insert/delete of PR lines | N/A |
| 3 | Boolean flag with VB6 True/False | **Y** | Bypass flag: VB6 used checkbox value as True/False string. SPINRISE uses int (1/0) as query param | imode routing breaks |
| 4 | Hardcoded CustID/DivCode/UserID | **Y** | VB6 used Session/global vars. SPINRISE: divcode from filter param, FinalAppUser from JWT claim (@User.Identity.Name) | Wrong approver written to DB |
| 5 | String concatenation in SQL | **Y** | CD-09: 4 PRINT statements in production SP. CD-10: phone lookup ran on all imodes. Remove all; parameterize fully | SQL injection risk; performance |
| 6 | CommitTrans boundary | **Y** | VB6 SP used transaction. SPINRISE SP: ALL DML (PO_PRL update + PO_PRH update + PO_Para update + Al_SMSMessage INSERT + LogDet_po INSERT) inside single BEGIN TRANSACTION / COMMIT | Partial saves, orphaned SMS records |
| 7 | Secondary update outside CommitTrans | **Y** | CD-11: Al_SMSMessage INSERT for Disposition=5 (Postponed) missing SendDate + NoofTry. Both columns NULLABLE so non-blocking — but fix in SPINRISE. ALL Al_SMSMessage INSERTs must be inside transaction. PO_Para PRSMSStatusFlg update inside transaction. | Data inconsistency |
| 8 | App-terminating on modal condition | **N** | VB6 used MsgBox — SPINRISE uses Ant Design confirm modals for Qty validation and Save confirmation. No app crash in browser. | N/A |
| 9 | ig_param reference | **N** | Not applicable to M01. Bypass / Company / Division come from filter UI controls, not ig_param. | N/A |
| 10 | prstatus='C' usage | **Y** | CRITICAL: PO_PRL.prstatus='C' = RECEIVED (not Cancelled). Cancelled = PO_PRH.cancelflag='Y'. FClosed='Y' = Foreclosed. Disposition=Declined sets FClosed='Y' on PO_PRL — NOT prstatus='C'. Final approval sets PO_PRL.prstatus='D' (distinct from all above). PO_PRH has NO prstatus column — never write PO_PRH.prstatus. | Wrong status written; data corruption |
| 11 | EmpCommon flag branch | **N** | No employee master lookup in Final Level Approval form. FinalAppUser comes from JWT token. | N/A |
| 12 | Form-level global variables | **Y** | VB6 used form-level variables for DB name, Division, Bypass state. SPINRISE: all state in React component (useState/Zustand). Filter state persists only for the lifetime of the page view. No cross-screen state sharing (OI-08 confirmed). | State bleed between approval screens |
| 13 | F1 key handler | **N** | Not present in Final Level Approval. Ctrl+S mapped to Save (HTML spec). Escape mapped to modal dismiss. | N/A |
| 14 | Single-instance form assumption | **Y** | Multiple approvers can load the form simultaneously. rowversion on PO_PRL provides optimistic concurrency. HTTP 409 returned if row updated between load and save. Frontend shows conflict toast and refreshes. | Lost approval data under concurrent use |
| 15 | FClosed='Y' flag (Foreclosure) | **Y** | Disposition=Declined (code 4) → sets FClosed='Y' on PO_PRL. Same flag used by PR Foreclosure module. No undo path for Declined in this form. Do NOT add undo path unless CEO directs. FCloseddt = GETDATE() when Declined. | Phantom undo for declined PRs |
| 16 | CANCELFLAG vs APPFLG (Cancellation) | **Y** | Before writing Final Approval, check: if PO_PRH.cancelflag='Y' → block with error. Do not approve cancelled PRs. (VB6 did not have this guard — add in SPINRISE.) | Approving already-cancelled PRs |
| 17 | rowversion concurrency column | **Y** | PO_PRL.row_version already exists in JAT (timestamp type). Read row_version on grid load, pass in save request per row, validate in SP: WHERE row_version = @CapturedVersion. Return HTTP 409 if @@ROWCOUNT = 0 after UPDATE. Frontend shows "Record modified by another user — please refresh." | Concurrent approval overwrites |

---

# STEP 2 — DB MIGRATION SCRIPT

**No new columns required.** All necessary columns verified against `Docs/DB_Schema/JAT_Schema.md`:
- `PO_PRL.FinalAppUser` varchar(35) — exists
- `PO_PRL.FinalLevel_Remarks` varchar(20) — exists (SP param is int; store as CAST(int→varchar))
- `PO_PRL.FinalAppQty` numeric(12,3) — exists
- `PO_PRL.DirectApp` char(1) — exists
- `PO_PRL.DirectAppDate` datetime — exists
- `PO_PRL.SecondApp` char(1) — exists
- `PO_PRL.ThirdApp` char(1) — exists
- `PO_PRL.FClosed` char(1) — exists
- `PO_PRL.FCloseddt` datetime — exists
- `PO_PRL.row_version` timestamp — exists
- `PO_PRH.APPFLG` char(1) — exists
- `PO_PRH.APP1/APP2/APP3` varchar(10) — exists
- `PO_PRH.APP1DATE/APP2DATE/APP3DATE` datetime — exists
- `PO_PRH.APP1TIME/APP2TIME/APP3TIME` datetime — exists
- `PO_PRH.row_version` timestamp — exists

**Pre-migration verification (run in SSMS on JAT before any SP deployment):**
```sql
-- Verify all required columns exist on PO_PRL
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'PO_PRL'
  AND COLUMN_NAME IN (
    'FinalAppUser','FinalLevel_Remarks','FinalAppQty',
    'DirectApp','DirectAppDate','SecondApp','ThirdApp',
    'FClosed','FCloseddt','row_version','prstatus',
    'LPO_RATE','LPO_DATE','APPCOST','FirstApp',
    'FirstAppQty','SecondAppQty','ThirdAppQty','qtyreqd'
  )
ORDER BY COLUMN_NAME;

-- Verify all required columns exist on PO_PRH
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'PO_PRH'
  AND COLUMN_NAME IN (
    'APPFLG','APP1','APP2','APP3',
    'APP1DATE','APP2DATE','APP3DATE',
    'APP1TIME','APP2TIME','APP3TIME',
    'cancelflag','row_version','divcode','prno','prdate'
  )
ORDER BY COLUMN_NAME;

-- Verify stock functions exist
SELECT OBJECT_NAME(object_id), type_desc
FROM sys.objects
WHERE name IN ('KSP_PRItemStock_FUN','KSP_PRItemStock_WITH_DIV');

-- Verify PO_Para has PRSMSStatusFlg
SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'PO_Para' AND COLUMN_NAME = 'PRSMSStatusFlg';

-- Verify Al_SMSMessage column names (for INSERT in SP)
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Al_SMSMessage'
ORDER BY ORDINAL_POSITION;

-- Verify pp_database and pp_divmas for company/division dropdowns
SELECT TOP 1 * FROM pp_database;
SELECT TOP 1 * FROM pp_divmas;
```

> If any column is missing: STOP. Report to Abinandan. Do not proceed with SP or backend development.

---

# STEP 3 — API CONTRACT

**imode routing summary (OBS-2 RESOLVED — Sasi 28-May-2026):**

| Condition | imode | divcode passed |
|---|---|---|
| Company=ALL | 2 | '0' |
| Company selected + Division=ALL | 2 | '0' |
| Company selected + Division selected | 3 | selected divcode |
| Save (any combination) | 4 | row's divcode |

**imode=1 does NOT exist. Never add it.**

---

## Endpoint 1 — GET /api/finallevel-pr

Load pending PR lines for Final Level Approval grid.

### Request

```typescript
// Query parameters (all required):
interface FinalApprovalGetQuery {
  dbname:  string;   // Company DB name from pp_database (e.g. 'KML')
  divcode: string;   // Division code or '0' for all divisions (imode=2)
  bypass:  number;   // 1 = show all PRs with any first approval; 0 = only past lower levels
}
// Example: GET /api/finallevel-pr?dbname=KML&divcode=01&bypass=1
```

### Response — Success (HTTP 200)

```typescript
interface FinalApprovalLineDto {
  divcode:       string;   // Division code
  prno:          number;   // PR number (6 digits)
  prdate:        string;   // ISO date "YYYY-MM-DD"
  prsno:         number;   // PR line sequence number
  dbname:        string;   // Company DB name (for Company column in All-mode)
  department:    string;   // Dept name from in_dep.DEPNAME
  itemCode:      string;   // PO_PRL.itemcode
  itemName:      string;   // IN_ITEM.itemname
  uom:           string;   // IN_ITEM.uom
  currentStock:  number;   // 3dp — from KSP_PRItemStock_FUN / _WITH_DIV
  qtyRequired:   number;   // 3dp — CASE: ThirdAppQty → SecondAppQty → FirstAppQty → qtyreqd
  qtyApproved:   number;   // 3dp — pre-populated from PO_PRL.FinalAppQty (or qtyRequired if null)
  disposition:   number;   // int: existing FinalLevel_Remarks cast to int (default 2 = Approved if null)
  lpoRate:       number;   // 4dp — PO_PRL.LPO_RATE
  lpoDate:       string | null;  // "YYYY-MM-DD" — PO_PRL.LPO_DATE
  approxCost:    number | null;  // 2dp — PO_PRL.APPCOST (null if value = 0)
  approvalStatus: 'first' | 'second' | 'final';  // for row colour — derived from FirstApp/SecondApp/ThirdApp
  rowVersion:    string;   // hex string from PO_PRL.row_version — MUST be passed back on save
}

interface FinalApprovalGetResponse {
  items: FinalApprovalLineDto[];
  totalLines:    number;
  totalCost:     number;   // 2dp — sum of (qtyreqd × lpoRate) for all lines
}
```

**Approval status derivation for row colour:**
```
ThirdApp IS NOT NULL AND ThirdApp='Y'  → 'final'   (pale green #7FFF00)
SecondApp IS NOT NULL AND SecondApp='Y' AND ThirdApp IS NULL → 'second' (amber #FFD400)
FirstApp='Y' AND SecondApp IS NULL → 'first'  (pale yellow #FFFFAA)
```

### Response — Error (HTTP 400)

```typescript
interface BusinessErrorResponse {
  code:    string;   // e.g. "NO_RECORDS_FOUND", "INVALID_DIVCODE"
  message: string;
}
```

---

## Endpoint 2 — POST /api/finallevel-pr/approve

Save Final Level Approval decisions for selected rows (batch).

### Request

```typescript
interface FinalApprovalSaveRequest {
  dbname:  string;   // Company DB name
  bypassAll: boolean; // true = SecondApp='Y' written (OI-09); false = SecondApp not written
  items: Array<{
    divcode:     string;
    prno:        number;
    prdate:      string;   // ISO date "YYYY-MM-DD"
    prsno:       number;
    qtyApproved: number;   // 3dp — user-entered value (validated ≤ qtyRequired)
    disposition: number;   // int enum: 1=PL Discuss, 2=Approved, 3=Hold, 4=Declined, 5=Postponed
    rowVersion:  string;   // hex string captured on GET — required for concurrency check
  }>;
}
// Minimum 1 item. Items with disposition=1 (PL Discuss) MUST NOT be sent — frontend enforces.
```

### Response — Success (HTTP 200)

```typescript
interface FinalApprovalSaveResponse {
  approvedCount: number;   // count of rows successfully processed
  message:       string;   // "Purchase Requisition Approval Completed."
}
```

### Response — Concurrency Conflict (HTTP 409)

```typescript
interface ConflictResponse {
  code:    "CONCURRENCY_CONFLICT";
  message: string;   // "One or more records were modified by another user. Please refresh and try again."
  conflictItems: Array<{ prno: number; prsno: number; }>;
}
```

### Response — Business Rule Error (HTTP 400)

```typescript
interface BusinessErrorResponse {
  code:    string;   // "PR_CANCELLED", "NO_ITEMS_SELECTED"
  message: string;
}
```

### Response — Validation Error (HTTP 422)

```typescript
interface ValidationErrorResponse {
  errors: Array<{
    field:   string;   // e.g. "items[0].qtyApproved"
    code:    string;   // e.g. "QTY_EXCEEDS_REQUIRED"
    message: string;
  }>;
}
```

---

## Endpoint 3 — GET /api/finallevel-pr/companies

Populate Company dropdown from pp_database.

```typescript
// Response HTTP 200:
interface CompanyDto {
  dbname:      string;   // pp_database key (e.g. 'KML')
  companyName: string;   // display name
}
// Returns: [{ dbname:'KML', companyName:'Kalpatharu Mill' }, ...]
```

---

## Endpoint 4 — GET /api/finallevel-pr/divisions

Populate Division dropdown (filtered by selected company).

```typescript
// Query: ?dbname=KML
// Response HTTP 200:
interface DivisionDto {
  divcode:      string;   // pp_divmas division code
  divisionName: string;   // pp_divmas division name
  abbr:         string;   // abbreviation for grid display
}
```

---

## Endpoint 5 — GET /api/items/{itemCode}/purchase-history

Item purchase history popup (History "…" button in grid).

```typescript
// Query: ?divcode=01
// Response HTTP 200:
interface ItemHistoryDto {
  poNo:    string;
  poDate:  string;   // "DD/MM/YYYY"
  qty:     number;   // 3dp
  rate:    number;   // 4dp (or 2dp — confirm with domain)
  amount:  number;   // 2dp
}
// Returns last N PO records for the item in the division
```

> **NOTE:** If this endpoint already exists in another controller (e.g. PurchaseOrderController), reuse it — do NOT create a duplicate endpoint.

---

# STEP 4 — STORED PROCEDURE IMPLEMENTATION

```sql
-- ============================================================
-- SP: ksp_po_finalapproval
-- Purpose: Final Level PR Approval — Grid load (imode 2/3) and Save (imode 4)
-- FSD: v1.4 CEO-approved [date]
-- Mockdown: SPINRISE_M01_FinalLevel_PR_Approval_Mockdown.md §4–§8
-- Author: Mohan Babu | Date: [implementation date]
-- DB: JAT (172.16.16.52\sql2016)
-- ============================================================
-- CD Fixes applied vs VB6 AS-IS:
--   CD-07: @logindate parameter REMOVED — SP uses GETDATE() internally
--   CD-08: @FinalLevel_Remarks changed from varchar to int; stored as CAST(int→varchar)
--   CD-09: All 4 PRINT statements removed
--   CD-10: Phone lookup (@phno) moved inside imode=4 block only
--   CD-11: Al_SMSMessage INSERT for Disposition=5 includes SendDate + NoofTry
--   CD-12: CAST(@Prdate AS DATE) used; @@ROWCOUNT checked → HTTP 404 if 0 rows affected
-- OI-09: FirstApp='Y' NOT written by this SP. SecondApp='Y' written ONLY when @Bypass=1.
-- OBS-2: imode=1 does NOT exist. Company=ALL → imode=2, divcode='0'.
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[ksp_po_finalapproval]
    @imode              int,
    @divcode            varchar(2),
    @dbname             varchar(20)     = NULL,
    @Prno               numeric(6,0)    = NULL,
    @Prdate             datetime        = NULL,
    @Prsno              numeric(5,0)    = NULL,
    @FinalAppUser       varchar(35)     = NULL,   -- JWT user claim
    @FinalAppQty        numeric(12,3)   = NULL,
    @FinalLevel_Remarks int             = NULL,   -- CD-08: int (not varchar)
    @Bypass             int             = 1,      -- 1=bypass lower levels; 0=enforce
    @row_version        binary(8)       = NULL,   -- concurrency — PO_PRL.row_version
    @Result             int             OUTPUT    -- 0=success, 1=validation, 2=business, 3=conflict, 4=not found
AS
BEGIN
    SET NOCOUNT ON;

    -- ── imode=2 and imode=3 — SELECT grid data ──────────────────────────────────
    -- imode=2: Company=ALL or Company+All Divisions (divcode='0') — no division filter
    -- imode=3: Specific Company + specific Division
    IF @imode IN (2, 3)
    BEGIN
        SELECT
            l.divcode,
            h.prno,
            CONVERT(varchar(10), h.prdate, 103)     AS prdate,   -- DD/MM/YYYY display
            l.prsno,
            d.DEPNAME                               AS department,
            l.itemcode,
            i.ITEMNAME                              AS itemName,
            i.UOM                                   AS uom,
            -- CD-10 FIX: stock function only called here (not in imode=4):
            CASE
              WHEN @imode = 2
              THEN dbo.KSP_PRItemStock_FUN(l.itemcode)
              ELSE dbo.KSP_PRItemStock_WITH_DIV(l.itemcode, l.divcode)
            END                                     AS currentStock,
            -- Qty Required CASE cascade (Mockdown §4.1):
            CASE
              WHEN l.ThirdAppQty  > 0 THEN l.ThirdAppQty
              WHEN l.SecondAppQty > 0 THEN l.SecondAppQty
              WHEN l.FirstAppQty  > 0 THEN l.FirstAppQty
              ELSE l.qtyreqd
            END                                     AS qtyRequired,
            ISNULL(l.FinalAppQty,
              CASE
                WHEN l.ThirdAppQty  > 0 THEN l.ThirdAppQty
                WHEN l.SecondAppQty > 0 THEN l.SecondAppQty
                WHEN l.FirstAppQty  > 0 THEN l.FirstAppQty
                ELSE l.qtyreqd
              END)                                  AS qtyApproved,
            ISNULL(TRY_CAST(l.FinalLevel_Remarks AS int), 2) AS disposition,
            l.LPO_RATE                              AS lpoRate,
            CASE WHEN l.LPO_DATE IS NOT NULL
              THEN CONVERT(varchar(10), l.LPO_DATE, 103)
              ELSE NULL END                         AS lpoDate,
            CASE WHEN ISNULL(l.APPCOST, 0) = 0 THEN NULL ELSE l.APPCOST END AS approxCost,
            -- Approval status for row colouring:
            CASE
              WHEN l.ThirdApp  IS NOT NULL AND l.ThirdApp  = 'Y' THEN 'final'
              WHEN l.SecondApp IS NOT NULL AND l.SecondApp = 'Y' THEN 'second'
              ELSE 'first'
            END                                     AS approvalStatus,
            master.dbo.fn_varbintohexstr(l.row_version) AS rowVersion
        FROM   PO_PRL  l
        JOIN   PO_PRH  h  ON h.divcode = l.divcode
                         AND h.prno    = l.prno
                         AND CAST(h.prdate AS DATE) = CAST(l.prdate AS DATE)
        JOIN   IN_DEP  d  ON d.DEPCODE = h.depcode
                         AND d.divcode = h.divcode
        JOIN   IN_ITEM i  ON i.ITEMCODE = l.itemcode
        WHERE  l.prstatus NOT IN ('C', 'X', 'Z')   -- exclude Received, Cancelled, Foreclosed
          AND  h.cancelflag <> 'Y'                  -- exclude cancelled PRs
          AND  h.APPFLG    <> 'Y'                   -- not yet fully approved
          -- Bypass logic:
          AND  l.FirstApp  = 'Y'                    -- at minimum first approval done
          AND  (
                @Bypass = 1                         -- bypass: show all with any first approval
                OR (
                    @Bypass = 0
                    AND (l.SecondApp = 'Y' OR l.ThirdApp = 'Y')  -- enforce lower levels
                )
               )
          -- Division filter (imode=2 → all divisions; imode=3 → specific division):
          AND  (@imode = 2 OR l.divcode = @divcode)
        ORDER BY l.divcode, h.prno, h.prdate, l.prsno;

        SET @Result = 0;
        RETURN;
    END

    -- ── imode=4 — SAVE Final Approval (one row per call; backend loops) ──────────
    IF @imode = 4
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;

            -- Guard: Cancelled PR check (SPINRISE addition — VB6 did not have this)
            IF EXISTS (
                SELECT 1 FROM PO_PRH
                WHERE divcode = @divcode
                  AND prno    = @Prno
                  AND CAST(prdate AS DATE) = CAST(@Prdate AS DATE)
                  AND cancelflag = 'Y'
            )
            BEGIN
                SET @Result = 2;   -- business rule error
                RAISERROR('This PR has been cancelled and cannot be approved.', 16, 1);
                ROLLBACK TRANSACTION;
                RETURN;
            END

            -- Concurrency check + UPDATE PO_PRL
            UPDATE PO_PRL
            SET
                FinalAppUser       = @FinalAppUser,
                prstatus           = 'D',
                DirectApp          = 'Y',
                -- OI-09: SecondApp='Y' ONLY when Bypass is active:
                SecondApp          = CASE WHEN @Bypass = 1 THEN 'Y' ELSE SecondApp END,
                ThirdApp           = 'Y',
                DirectAppDate      = GETDATE(),
                qtyreqd            = @FinalAppQty,
                FinalAppQty        = @FinalAppQty,
                FinalLevel_Remarks = CAST(@FinalLevel_Remarks AS varchar(20)),  -- CD-08 fix
                -- Disposition=4 (Declined) → Foreclose the line:
                FClosed            = CASE WHEN @FinalLevel_Remarks = 4 THEN 'Y' ELSE FClosed END,
                FCloseddt          = CASE WHEN @FinalLevel_Remarks = 4 THEN GETDATE() ELSE FCloseddt END
                -- OI-09: FirstApp NOT written here (set by First Level Approval only)
            WHERE divcode = @divcode
              AND prno    = @Prno
              AND CAST(prdate AS DATE) = CAST(@Prdate AS DATE)   -- CD-12: DATE cast
              AND prsno   = @Prsno
              AND row_version = @row_version;   -- concurrency guard

            -- CD-12: Check if UPDATE hit any rows
            IF @@ROWCOUNT = 0
            BEGIN
                -- Either concurrency conflict or row not found — check which:
                IF EXISTS (
                    SELECT 1 FROM PO_PRL
                    WHERE divcode = @divcode AND prno = @Prno
                      AND CAST(prdate AS DATE) = CAST(@Prdate AS DATE)
                      AND prsno = @Prsno
                )
                    SET @Result = 3;   -- concurrency conflict
                ELSE
                    SET @Result = 4;   -- not found
                ROLLBACK TRANSACTION;
                RETURN;
            END

            -- UPDATE PO_PRH — ISNULL pattern (Mockdown §8):
            UPDATE PO_PRH
            SET
                APPFLG   = 'Y',
                APP1     = ISNULL(APP1,    'DIR'),
                APP1DATE = ISNULL(APP1DATE, GETDATE()),
                APP1TIME = ISNULL(APP1TIME, GETDATE()),
                APP2     = ISNULL(APP2,    'DIR'),
                APP2DATE = ISNULL(APP2DATE, GETDATE()),
                APP2TIME = ISNULL(APP2TIME, GETDATE()),
                APP3     = ISNULL(APP3,    'DIR'),
                APP3DATE = ISNULL(APP3DATE, GETDATE()),
                APP3TIME = ISNULL(APP3TIME, GETDATE())
            WHERE divcode = @divcode
              AND prno    = @Prno
              AND CAST(prdate AS DATE) = CAST(@Prdate AS DATE);

            -- UPDATE PO_Para (Mockdown §8 — PRSMSStatusFlg):
            -- CD-10 FIX: moved inside imode=4 block (was outside all imode blocks in VB6)
            UPDATE PO_Para
            SET    PRSMSStatusFlg = 'Y'
            WHERE  divcode = @divcode;   -- confirm key column with DBA before coding

            -- CD-10: Phone lookup (moved inside imode=4 — only needed for SMS)
            DECLARE @phno varchar(20);
            SELECT @phno = [phone_column]    -- confirm column name from Al_SMSMessage/contact table
            FROM   [phone_source_table]
            WHERE  [relevant_condition];

            -- SMS INSERT — ALL disposition codes (OI-09: retained in SPINRISE):
            -- CD-11 FIX: Disposition=5 (Postponed) now includes SendDate + NoofTry
            INSERT INTO Al_SMSMessage (
                [SmsMobile], [SmsMessage], [DivCode],
                [SendDate],  [NoofTry],   [SmsStatus]
                -- add all required columns — confirm exact column list from pre-migration verification
            )
            VALUES (
                @phno,
                CASE @FinalLevel_Remarks
                    WHEN 1 THEN 'PR No.' + CAST(@Prno AS varchar) + ' has been set to PL Discuss'
                    WHEN 2 THEN 'PR No.' + CAST(@Prno AS varchar) + ' has been Approved'
                    WHEN 3 THEN 'PR No.' + CAST(@Prno AS varchar) + ' is on Hold'
                    WHEN 4 THEN 'PR No.' + CAST(@Prno AS varchar) + ' has been Declined'
                    WHEN 5 THEN 'PR No.' + CAST(@Prno AS varchar) + ' has been Postponed'
                END,
                @divcode,
                GETDATE(),  -- CD-11 fix: was missing for Postponed
                0,          -- CD-11 fix: was missing for Postponed
                'P'         -- Pending send status — confirm with domain
            );

            -- Audit log (LogDet_po):
            INSERT INTO LogDet_po (
                divcode, prno, prdate, prsno,
                prstatus, Trans_UserId, Trans_date,
                Trans_Name, Trans_Mod, Activity
            )
            VALUES (
                @divcode, @Prno, @Prdate, @Prsno,
                'D', @FinalAppUser, GETDATE(),
                'Final Level PR Approval', 'FinalApp',
                CASE @FinalLevel_Remarks
                    WHEN 1 THEN 'PL_DISCUSS'
                    WHEN 2 THEN 'APPROVED'
                    WHEN 3 THEN 'HOLD'
                    WHEN 4 THEN 'DECLINED'
                    WHEN 5 THEN 'POSTPONED'
                END
            );

            COMMIT TRANSACTION;
            SET @Result = 0;

        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            SET @Result = 2;
            THROW;
        END CATCH
    END

END
```

> **SP BLOCKER — Confirm before coding:**
> 1. Exact column names in `Al_SMSMessage` (phone column name, message column name, status column, all NOT NULL columns)
> 2. `pp_database` and `pp_divmas` column names for Company/Division dropdown SPs
> 3. Phone source table name and key for @phno lookup
> 4. `PO_Para` key column(s) for the UPDATE WHERE clause
> 5. Confirm `KSP_PRItemStock_FUN` and `KSP_PRItemStock_WITH_DIV` signatures (parameters + return type)
> 6. Confirm exact `master.dbo.fn_varbintohexstr` function name for row_version → hex conversion OR use alternative in C# layer (convert byte[] to hex string before sending to frontend)

**FY Guard:** NOT APPLICABLE — Final Level Approval operates on existing PRs whose date was validated at creation. No date-based FY validation needed here. Document in SP header.

---

# STEP 5 — BACKEND IMPLEMENTATION (ASP.NET Core 8 / C#)

**File locations:**
```
Spinrise.API/Areas/PurchaseOrder/FinalLevelApproval/
    FinalLevelApprovalController.cs

Spinrise.Application/Areas/PurchaseOrder/FinalLevelApproval/
    DTOs/
        FinalApprovalGetQuery.cs
        FinalApprovalLineDto.cs
        FinalApprovalSaveRequest.cs
        FinalApprovalSaveResponse.cs
    Interfaces/
        IFinalLevelApprovalService.cs
    FinalLevelApprovalService.cs

Spinrise.Infrastructure/Areas/PurchaseOrder/FinalLevelApproval/
    FinalLevelApprovalRepository.cs

Spinrise.Shared/Constants/StoredProcedures.cs
    — add: public const string FinalLevelApproval = "ksp_po_finalapproval";
```

### Controller

```csharp
// FinalLevelApprovalController.cs
[ApiController]
[Route("api/finallevel-pr")]
public class FinalLevelApprovalController : BaseApiController
{
    private readonly IFinalLevelApprovalService _service;

    // GET /api/finallevel-pr?dbname=KML&divcode=01&bypass=1
    [HttpGet]
    public async Task<IActionResult> GetPendingApprovals([FromQuery] FinalApprovalGetQuery query)
    {
        if (!ModelState.IsValid) return UnprocessableEntity(ModelState);
        var result = await _service.GetPendingApprovalsAsync(query);
        return result.IsSuccess ? Ok(result.Data) : BadRequest(result.Error);
    }

    // POST /api/finallevel-pr/approve
    [HttpPost("approve")]
    public async Task<IActionResult> SaveApprovals([FromBody] FinalApprovalSaveRequest request)
    {
        if (!ModelState.IsValid) return UnprocessableEntity(ModelState);
        // FinalAppUser from JWT claim — never from request body
        var currentUser = User.Identity?.Name
            ?? throw new InvalidOperationException("User identity missing from JWT.");
        var result = await _service.SaveApprovalsAsync(request, currentUser);
        return result.IsSuccess
            ? Ok(result.Data)
            : result.Error?.Code == "CONCURRENCY_CONFLICT"
                ? Conflict(result.Error)
                : BadRequest(result.Error);
    }

    // GET /api/finallevel-pr/companies
    [HttpGet("companies")]
    public async Task<IActionResult> GetCompanies()
    {
        var result = await _service.GetCompaniesAsync();
        return result.IsSuccess ? Ok(result.Data) : BadRequest(result.Error);
    }

    // GET /api/finallevel-pr/divisions?dbname=KML
    [HttpGet("divisions")]
    public async Task<IActionResult> GetDivisions([FromQuery] string dbname)
    {
        var result = await _service.GetDivisionsAsync(dbname);
        return result.IsSuccess ? Ok(result.Data) : BadRequest(result.Error);
    }
}
```

### Service

```csharp
// FinalLevelApprovalService.cs
public class FinalLevelApprovalService : IFinalLevelApprovalService
{
    // GetPendingApprovalsAsync:
    //   Determine imode from query (divcode='0' or null → imode=2; else imode=3)
    //   Call repository → ksp_po_finalapproval imode=2/3
    //   Map result to FinalApprovalGetResponse with total cost calculation
    //   currentStock: 3dp | lpoRate: 4dp | approxCost: 2dp | totalCost: 2dp

    // SaveApprovalsAsync:
    //   Server-side validation:
    //     - items.Count > 0
    //     - each item.qtyApproved > 0 (CR-M01-FL-003)
    //     - each item.qtyApproved ≤ item.qtyRequired (must re-fetch to validate server-side)
    //     - disposition enum 1–5 only (disposition=1 items must not be in request)
    //   Call repository for each item — pass currentUser as @FinalAppUser
    //   Handle @Result codes:
    //     0 = success → continue
    //     2 = business error → return BadRequest
    //     3 = concurrency conflict → collect conflicting items, return Conflict(409)
    //     4 = not found → return NotFound
    //   All items processed within a single UnitOfWork transaction scope
}
```

### Validation Rules (server-side)

| Rule | Implementation | HTTP on fail |
|---|---|---|
| items.Count > 0 | Check in service before calling SP | 422 |
| qtyApproved > 0 | Check in service (CR-M01-FL-003) | 422 |
| qtyApproved ≤ qtyRequired | Re-fetch qtyRequired from DB in service | 422 |
| disposition in 1..5 | DataAnnotation `[Range(1,5)]` | 422 |
| disposition ≠ 1 in request | Check in service (PL Discuss rows blocked on frontend) | 422 |
| PR not cancelled | Checked in SP → @Result=2 | 400 |
| row_version match | Checked in SP → @Result=3 | 409 |

### DI Registration (Program.cs)

```csharp
// Add to Program.cs alongside existing M01 registrations:
builder.Services.AddScoped<IFinalLevelApprovalService, FinalLevelApprovalService>();
builder.Services.AddScoped<FinalLevelApprovalRepository>();
```

---

# STEP 6 — FRONTEND IMPLEMENTATION (React 18 + TypeScript)

### File Structure

```
src/features/pr/
├── pages/
│   └── FinalLevelApprovalPage.tsx      ← route-level page component
├── components/
│   └── final-approval/
│       ├── FinalApprovalFilterBar.tsx  ← Company / Division / Bypass / Show
│       ├── FinalApprovalGrid.tsx       ← AG Grid with editable cells
│       └── FinalApprovalFooter.tsx     ← 4 summary cards
├── store/
│   └── finalApprovalStore.ts           ← Zustand store
├── api/
│   └── finalApproval.api.ts            ← Axios calls
└── types/
    └── finalApproval.types.ts          ← TypeScript types
```

### Route Registration (App.tsx)

```typescript
// Add route alongside existing PR routes:
<Route path="/purchase/final-level-pr-approval" element={<FinalLevelApprovalPage />} />
// Sidebar menu item: "Purchase Requisition Final Level Approval"
// Menu icon: ✅ (consistent with First Level Approval)
```

### TypeScript Types

```typescript
// finalApproval.types.ts
export interface FinalApprovalLine {
  divcode:        string;
  prno:           number;
  prdate:         string;       // ISO date
  prsno:          number;
  dbname:         string;
  department:     string;
  itemCode:       string;
  itemName:       string;
  uom:            string;
  currentStock:   number;       // 3dp display
  qtyRequired:    number;       // 3dp display — read-only
  qtyApproved:    number;       // 3dp — editable
  disposition:    DispositionCode;
  lpoRate:        number;       // 4dp display
  lpoDate:        string | null;
  approxCost:     number | null; // 2dp display
  approvalStatus: 'first' | 'second' | 'final';
  rowVersion:     string;       // must be passed back on save
  // UI-only state:
  selected:       boolean;      // row checkbox — false when disposition=1
}

export type DispositionCode = 1 | 2 | 3 | 4 | 5;

export const DISPOSITION_LABELS: Record<DispositionCode, string> = {
  1: 'PL Discuss',
  2: 'Approved',
  3: 'Hold',
  4: 'Declined',
  5: 'Postponed',
};

export interface FinalApprovalFilterState {
  dbname:   string;
  divcode:  string;
  bypassAll: boolean;
}
```

### Zustand Store

```typescript
// finalApprovalStore.ts
interface FinalApprovalStore {
  filterState:   FinalApprovalFilterState;
  lines:         FinalApprovalLine[];      // grid rows
  gridLoaded:    boolean;                  // controls Show/Save/Cancel enabled state
  loading:       boolean;
  saving:        boolean;

  // Actions
  setFilter:        (filter: Partial<FinalApprovalFilterState>) => void;
  setLines:         (lines: FinalApprovalLine[]) => void;
  updateLineQty:    (idx: number, qty: number) => void;
  updateDisposition:(idx: number, code: DispositionCode) => void;
  toggleRowSelect:  (idx: number, selected: boolean) => void;
  toggleSelectAll:  (selected: boolean) => void;     // skips PL Discuss rows
  clearGrid:        () => void;
  setLoading:       (v: boolean) => void;
  setSaving:        (v: boolean) => void;
}

// Computed values (use selectors — NOT stored in Zustand):
// - selectedLines:  lines.filter(l => l.selected && l.disposition !== 1)
// - selectedCount:  selectedLines.length
// - selectedCost:   sum(qtyRequired × lpoRate) for selected lines  — CR-M01-FL-005: does NOT use qtyApproved
// - totalCost:      sum(qtyRequired × lpoRate) for all lines       — CR-M01-FL-005
// - totalLines:     lines.length
```

### Toolbar

```typescript
// This is a STATUS-UPDATE module — standard 5-mode CRUD toolbar does NOT apply.
// Custom action bar per UI/UX design:
//
// [↺ Refresh]  |  [✓ Save  Ctrl+S]  [✕ Cancel]
//
// Refresh: always enabled
// Save:    disabled until gridLoaded=true AND selectedCount>0
// Cancel:  disabled until gridLoaded=true
//
// Keyboard: Ctrl+S triggers Save (confirm modal fires)
// Keyboard: Escape dismisses all confirm modals

const FinalApprovalToolbar: React.FC = () => {
  const { gridLoaded, saving, lines } = useFinalApprovalStore();
  const selectedCount = lines.filter(l => l.selected && l.disposition !== 1).length;

  return (
    <div className="toolbar">
      <Button icon={<ReloadOutlined />} onClick={handleRefresh}>Refresh</Button>
      <Divider type="vertical" />
      <Button
        type="primary"
        icon={<CheckOutlined />}
        disabled={!gridLoaded || selectedCount === 0 || saving}
        onClick={handleSave}
      >
        Save <KbdBadge>Ctrl+S</KbdBadge>
      </Button>
      <Button
        icon={<CloseOutlined />}
        disabled={!gridLoaded}
        onClick={handleCancel}
      >
        Cancel
      </Button>
    </div>
  );
};
```

### Filter Bar

```typescript
// FinalApprovalFilterBar.tsx
// Controls: Company (select) | Division (select, disabled when Company=ALL) | Bypass All (checkbox, default checked) | Show (primary button)
//
// Company=ALL → divcode='0', Division selector disabled
// Division always shows "ALL" as first option (divcode='0')
// Show button: calls GET /api/finallevel-pr — always triggers fresh load
// Bypass All: checked by default. No debounce — only re-fetches on Show click.

const imode = divcode === '0' ? 2 : 3;   // never send imode to API — derive in service
```

### AG Grid Configuration

```typescript
// FinalApprovalGrid.tsx
// AG Grid Community — row-level editing with checkbox selection

const rowClassRules = {
  'row-final-app':  (params: RowClassParams) => params.data.approvalStatus === 'final',
  'row-second-app': (params: RowClassParams) => params.data.approvalStatus === 'second',
  'row-first-app':  (params: RowClassParams) => params.data.approvalStatus === 'first',
};

// CSS (in module.css or global):
// .row-first-app  { background-color: #FFFFAA !important; }   /* pale yellow */
// .row-second-app { background-color: #FFD400 !important; }   /* amber */
// .row-final-app  { background-color: #7FFF00 !important; }   /* pale green */

const columnDefs: ColDef<FinalApprovalLine>[] = [
  {
    // Checkbox column — disabled when disposition=1 (PL Discuss)
    checkboxSelection: true,
    headerCheckboxSelection: true,
    headerCheckboxSelectionFilteredOnly: true,
    width: 32,
    pinned: 'left',
    resizable: false,
    suppressMovable: true,
    cellRenderer: CheckboxCellRenderer,   // custom: disabled if row.disposition === 1
  },
  { field: 'dbname',       headerName: 'Company',    width: 60,  hide: !allCompaniesMode },
  { field: 'divcode',      headerName: 'Div',        width: 40 },
  { field: 'prno',         headerName: 'PR No.',     width: 54,  type: 'rightAligned',
    cellStyle: { fontFamily: 'var(--mono)', fontWeight: 700 } },
  { field: 'prdate',       headerName: 'PR Date',    width: 80,
    valueFormatter: p => formatDate(p.value) },    // DD/MM/YYYY
  { field: 'department',   headerName: 'Department', width: 90 },
  { field: 'itemName',     headerName: 'Item Name',  width: 140, flex: 1 },
  { field: 'uom',          headerName: 'Unit',       width: 38 },
  { field: 'currentStock', headerName: 'Current Stock', width: 74, type: 'rightAligned',
    valueFormatter: p => p.value?.toFixed(3) ?? '—' },
  { field: 'qtyRequired',  headerName: 'Qty Required', width: 74, type: 'rightAligned',
    valueFormatter: p => p.value?.toFixed(3) },
  {
    // Editable — inline InputNumber; validate ≤ qtyRequired on blur
    field: 'qtyApproved',
    headerName: 'Qty Approved',
    width: 82,
    type: 'rightAligned',
    editable: true,
    cellEditor: 'agNumberCellEditor',
    cellEditorParams: { precision: 3, min: 0.001 },
    valueSetter: params => {
      const val = parseFloat(params.newValue);
      if (isNaN(val) || val <= 0) {
        // CR-M01-FL-003: zero/negative → reset to 1
        params.data.qtyApproved = 1;
        showQtyWarning('zero');
        return false;
      }
      if (val > params.data.qtyRequired) {
        params.data.qtyApproved = params.data.qtyRequired;
        showQtyWarning('exceeds', val, params.data.qtyRequired);
        return false;
      }
      params.data.qtyApproved = parseFloat(val.toFixed(3));
      return true;
    },
    valueFormatter: p => p.value?.toFixed(3),
  },
  {
    // Editable dropdown — Disposition
    field: 'disposition',
    headerName: 'Disposition',
    width: 108,
    editable: true,
    cellEditor: 'agSelectCellEditor',
    cellEditorParams: { values: [1, 2, 3, 4, 5] },
    valueFormatter: p => DISPOSITION_LABELS[p.value as DispositionCode] ?? '—',
    onCellValueChanged: params => {
      // BR-PLDISCUSS-01: PL Discuss → immediately uncheck and disable row checkbox
      if (params.newValue === 1) {
        params.data.selected = false;
        params.api.refreshCells({ rowNodes: [params.node!], columns: ['checkboxSelection'] });
      } else if (params.oldValue === 1) {
        // Changed away from PL Discuss → re-enable checkbox
        params.api.refreshCells({ rowNodes: [params.node!], columns: ['checkboxSelection'] });
      }
      updateFooter();
    },
  },
  { field: 'lpoRate',   headerName: 'LPO Rate',  width: 70,  type: 'rightAligned',
    valueFormatter: p => p.value?.toFixed(4) },
  { field: 'lpoDate',   headerName: 'LPO Date',  width: 74,
    valueFormatter: p => p.value ? formatDate(p.value) : '—' },
  { field: 'approxCost', headerName: 'Approx. Value', width: 82, type: 'rightAligned',
    valueFormatter: p => p.value != null ? p.value.toFixed(2) : '—' },
  {
    // Item Purchase History button
    headerName: '',
    width: 30,
    cellRenderer: HistoryButtonCellRenderer,
    // onClick: open Ant Design Drawer with GET /api/items/{itemCode}/purchase-history?divcode=
  },
];

const gridOptions = {
  rowHeight:     32,
  headerHeight:  36,
  rowClassRules,
  rowSelection:  'multiple',
  suppressRowClickSelection: true,   // checkbox only — not row-click
  getRowId: params => `${params.data.prno}-${params.data.prsno}-${params.data.divcode}`,
};
```

### Confirmation Modals

```typescript
// 1. Qty Validation Warning (BR-QTY-01) — shown on blur when qty > qtyRequired or ≤ 0:
Modal.warning({
  title: 'Quantity Validation',
  content: `Approved quantity should be lesser/equal to Required Quantity.
            The value has been reset to ${qtyRequired.toFixed(3)}.`,
  onOk: () => {},
});

// 2. Save Confirmation — required before ANY save (irreversible write):
Modal.confirm({
  title: 'Confirm Final Approval',
  icon: <SaveOutlined />,
  content: `Save final-level approval for the selected ${selectedCount} PR line(s)?
            This action sets PRSTATUS = 'D' and sends SMS notifications.`,
  okText: 'Save Approval',
  cancelText: 'Cancel',
  onOk: () => submitSave(),
});

// 3. No Records Selected:
Modal.info({
  title: 'No Records Selected',
  content: 'No records are selected to approve. Please check at least one row. Rows with Disposition = PL Discuss cannot be selected.',
});

// 4. Concurrency Conflict (HTTP 409 response):
Modal.error({
  title: 'Conflict — Record Modified',
  content: 'One or more records were modified by another user. Please refresh and try again.',
  onOk: () => handleRefresh(),
});
```

### Footer Summary Cards

```typescript
// FinalApprovalFooter.tsx — 4 cards (only visible when grid is loaded)
// CR-M01-FL-005 (CEO 31-May-2026): Approx.Value = qtyRequired × lpoRate.
//   Does NOT recalculate when Qty Approved is edited. Source: FSD v1.4 §3.2.
// CR-M01-FL-006: All values computed dynamically — no hardcoded values.

const selectedLines = lines.filter(l => l.selected && l.disposition !== 1);
const selectedCost  = selectedLines.reduce((s, l) => s + (l.qtyRequired * l.lpoRate), 0);
const totalCost     = lines.reduce((s, l) => s + (l.qtyRequired * l.lpoRate), 0);

// Card 1: Total Lines      = lines.length
// Card 2: Selected For Save = selectedLines.length + sub: "rows checked — only these commit on Save"
// Card 3: Approx. Cost (Selected) = selectedCost.toFixed(2) with ₹ prefix
// Card 4: Total Approx. Cost = totalCost.toFixed(2) with ₹ prefix
```

### Save Flow

```typescript
const handleSave = async () => {
  const eligibleRows = lines.filter(l => l.selected && l.disposition !== 1);
  if (eligibleRows.length === 0) {
    showNoRecordsModal();
    return;
  }
  // Show confirmation modal first:
  Modal.confirm({
    title: 'Confirm Final Approval',
    content: `Save final-level approval for the selected ${eligibleRows.length} PR line(s)?`,
    okText: 'Save Approval',
    onOk: async () => {
      setSaving(true);
      try {
        const request: FinalApprovalSaveRequest = {
          dbname:   filterState.dbname,
          bypassAll: filterState.bypassAll,
          items: eligibleRows.map(r => ({
            divcode:     r.divcode,
            prno:        r.prno,
            prdate:      r.prdate,
            prsno:       r.prsno,
            qtyApproved: r.qtyApproved,
            disposition: r.disposition,
            rowVersion:  r.rowVersion,
          })),
        };
        const result = await finalApprovalApi.saveApprovals(request);
        showToast('success', 'Purchase Requisition Approval Completed.');
        await handleRefresh();   // reload grid after save
      } catch (err) {
        if (isConflictError(err)) {
          showConflictModal();
          await handleRefresh();
        } else {
          showErrorToast(err);
        }
      } finally {
        setSaving(false);
      }
    },
  });
};
```

### Legend Strip

```typescript
// Inline in grid bar (not a floating overlay):
// [■ pale yellow] First Approval   [■ amber] Second Approval   [■ pale green] Third Approval Done
// Colours match: --app-first:#FFFFAA / --app-second:#FFD400 / --app-final:#7FFF00
```

### Decimal Precision

```typescript
import { DECIMAL_PRECISION } from '@/constants/precision';
// currentStock: DECIMAL_PRECISION.QUANTITY (3dp)
// qtyRequired:  DECIMAL_PRECISION.QUANTITY (3dp)
// qtyApproved:  DECIMAL_PRECISION.QUANTITY (3dp)
// lpoRate:      DECIMAL_PRECISION.RATE (4dp)
// approxCost:   DECIMAL_PRECISION.VALUE (2dp)
// totalCost:    DECIMAL_PRECISION.VALUE (2dp)
```

---

# STEP 7 — QUESTPDF PRINT TEMPLATE

**STEP 7: NOT APPLICABLE** — FSD v1.4 confirms no print output for Final Level PR Approval.
This is an action/approval form only. No PDF document is generated.

Reference: Mockdown §10 sign-off block — no print step mentioned; consistent with Foreclosure and Cancellation modules.

---

# STEP 8 — STAGE 1 SELF-CHECK

Developer must complete before any IST submission. Attach results to IST email.

```
STAGE 1 SELF-CHECK — M01 Final Level PR Approval — [Date]
Developer: Mohan Babu | FSD: v1.4

FILTER AND GRID LOAD:
  [ ] Company=ALL → Division disabled; Show → imode=2 grid loads correctly
  [ ] Company=KML + Division=ALL → imode=2 grid loads
  [ ] Company=KML + Division=01 → imode=3 grid loads with division filter
  [ ] Bypass=ON: PRs with First Approval only appear (no Second/Third required)
  [ ] Bypass=OFF: Only PRs with Second or Third approval appear
  [ ] Grid placeholder shown on initial load — no data until Show clicked
  [ ] Save and Cancel disabled until Show clicked
  [ ] Refresh button: if no grid loaded → info toast; if grid loaded → reload grid

ROW COLOURS:
  [ ] ThirdApp done → pale green (#7FFF00) row
  [ ] SecondApp done (no ThirdApp) → amber (#FFD400) row
  [ ] FirstApp only → pale yellow (#FFFFAA) row
  [ ] Legend strip visible in grid bar (inline — not floating)

CHECKBOX BEHAVIOUR:
  [ ] Disposition=PL Discuss → row checkbox immediately disabled and unchecked
  [ ] Change disposition from PL Discuss to other → checkbox re-enabled
  [ ] Header checkbox: selects all non-PL-Discuss rows
  [ ] Save disabled when 0 eligible rows selected

QTY APPROVED VALIDATION (BR-QTY-01 / CR-M01-FL-003):
  [ ] Enter value > qtyRequired → reset to qtyRequired, show warning modal
  [ ] Enter 0 or negative → reset to 1, show error toast
  [ ] Enter valid value (0 < x ≤ qtyRequired) → accepted, 3dp displayed
  [ ] Numeric-only keydown enforced (letters, symbols rejected except decimal point)

DISPOSITION SAVE BEHAVIOUR:
  [ ] Disposition=2 (Approved) → PO_PRL: prstatus='D', ThirdApp='Y', DirectApp='Y'
  [ ] Disposition=2 + Bypass=ON → SecondApp='Y' also written (OI-09 confirmed)
  [ ] Disposition=2 + Bypass=OFF → SecondApp NOT written
  [ ] Disposition=4 (Declined) → PO_PRL: FClosed='Y', FCloseddt populated — confirm in DB
  [ ] PO_PRH: APPFLG='Y' after save — confirm in DB
  [ ] PO_PRH: APP1/APP2/APP3 = 'DIR' when previously null — confirm in DB
  [ ] PO_Para: PRSMSStatusFlg='Y' after save — confirm in DB
  [ ] LogDet_po: audit record inserted — confirm in DB
  [ ] Al_SMSMessage: record inserted for ALL disposition codes — confirm in DB

CONCURRENCY:
  [ ] Open form in two browser tabs, load same grid
  [ ] Tab A: change disposition, save → success
  [ ] Tab B: attempt save same row → HTTP 409 → "Record modified by another user" toast shown
  [ ] Tab B: refresh refreshes grid with latest data

SAVE CONFIRMATION:
  [ ] Save with eligible rows → confirm modal appears with correct row count
  [ ] Confirm → save proceeds, success toast, grid reloads
  [ ] Cancel in modal → no save, grid unchanged

FOOTER CARDS:
  [ ] Total Lines: correct count of all grid rows
  [ ] Selected For Save: correct count of checked non-PL-Discuss rows
  [ ] Approx. Cost (Selected): sum of qtyRequired × lpoRate for selected rows (NOT qtyApproved)
  [ ] Total Approx. Cost: sum of qtyRequired × lpoRate for all rows
  [ ] Footer values update immediately on checkbox change, disposition change

ITEM HISTORY BUTTON:
  [ ] "…" button in last grid column opens history drawer/modal
  [ ] History shows PO records for the item with correct Div scope
  [ ] Close dismisses modal cleanly

DECIMAL PRECISION:
  [ ] Current Stock: 3dp
  [ ] Qty Required: 3dp
  [ ] Qty Approved: 3dp
  [ ] LPO Rate: 4dp
  [ ] Approx. Value: 2dp
  [ ] Footer costs: 2dp with comma thousands separator

BLUEPRINT COMPLIANCE:
  [ ] No raw hex colours in any component — Blueprint tokens only (except row colours: #FFFFAA / #FFD400 / #7FFF00 which are AS-IS per FSD — use CSS variables --app-first / --app-second / --app-final)
  [ ] Grid row height: 32px
  [ ] Field height: 32px (filter bar controls)
  [ ] Doc band breadcrumb: "Purchase Order › Final Level PR Approval"
  [ ] Page title in sidebar: active highlight on "Purchase Requisition Final Level Approval"
  [ ] Ctrl+S keyboard shortcut triggers Save
  [ ] Escape key dismisses all confirm modals

OI / CD FIX VERIFICATION:
  [ ] OI-09: FirstApp NOT written by Final Level SP — verified in DB after save
  [ ] OI-08: This screen shares NO state with First Level or Second Level screens — confirmed
  [ ] CD-07: logindate NOT in API request DTO — confirmed
  [ ] CD-08: disposition passed as int — confirmed
  [ ] CD-09: No PRINT statements in deployed SP — confirmed
  [ ] CD-10: Phone lookup only runs in imode=4 — confirmed
  [ ] CD-11: Postponed disposition Al_SMSMessage has SendDate + NoofTry — confirmed in DB
  [ ] CD-12: CAST(@Prdate AS DATE) used in SP — confirmed; @@ROWCOUNT checked — confirmed

STEP 7 (PRINT):
  [x] NOT APPLICABLE — FSD v1.4 confirms no print output. No further action needed.

ALL ITEMS PASS? [ ] YES → proceed to IST
                [ ] NO  → fix before IST submission
```

---

# STEP 9 — FSD COMPLIANCE REPORT

```
FSD COMPLIANCE REPORT
Module: M01 Purchase Order | FSD: v1.4 CEO-approved [date]
UI/UX Design: SPINRISE_FSD_M01_PRFinalLevelApproval_v1_2.html
CR Deployed: v[version] | Date: [date]
Developer: Mohan Babu

1. DESIGN POINTS CONFIRMED COMPLIANT:
   1.  Filter bar: Company, Division, Bypass All — implemented per Mockdown §3
   2.  imode routing: Company=ALL → imode=2+divcode='0' (OBS-2 resolution) — confirmed
   3.  imode=1 removed: never added — confirmed
   4.  Row colours: #FFFFAA / #FFD400 / #7FFF00 per Mockdown §4.4 — confirmed
   5.  Approval status legend: inline in grid bar — confirmed
   6.  Disposition dropdown codes 1–5 per Mockdown §4.3 — confirmed
   7.  PL Discuss (code=1): row checkbox immediately disabled — confirmed
   8.  Qty Approved editable input: 3dp, validation ≤ qtyRequired — confirmed
   9.  Qty Required CASE cascade (ThirdAppQty→SecondAppQty→FirstAppQty→qtyreqd) — confirmed
   10. OI-09: FirstApp NOT written by Final Level SP — confirmed
   11. SecondApp='Y' written only when Bypass=ON — confirmed
   12. Disposition=Declined → FClosed='Y' + FCloseddt on PO_PRL — confirmed
   13. PO_PRH APPFLG='Y' + all APP1/2/3 fields with ISNULL pattern — confirmed
   14. PO_Para PRSMSStatusFlg='Y' updated on every imode=4 save — confirmed
   15. Al_SMSMessage INSERT for ALL disposition codes 1–5 — confirmed
   16. CD-11 fix: Disposition=5 (Postponed) Al_SMSMessage includes SendDate+NoofTry — confirmed
   17. rowversion concurrency: HTTP 409 on conflict — confirmed
   18. CR-M01-FL-003: qtyApproved ≤ 0 → reset to 1 — confirmed
   19. CR-M01-FL-005: Approx.Value = qtyRequired × lpoRate (not qtyApproved) — confirmed
   20. CR-M01-FL-006: footer computed dynamically — confirmed
   21. Cancellation guard: PR with cancelflag='Y' → blocked — confirmed
   22. STEP 7: Print NOT APPLICABLE — confirmed

2. GAPS (resolved before code generation):
   G-01 (SP-F1): imode=1 branch — RESOLVED as OBS-2: imode=2+divcode='0' for Company=ALL
   G-02: Bypass flag semantics — RESOLVED: Bypass=1 shows all PRs with any first approval
   G-03: Al_SMSMessage column names — RESOLVED: [fill after pre-migration verification]
   G-04: pp_database / pp_divmas column names — RESOLVED: [fill after verification]
   G-05: Item history endpoint — RESOLVED: [new endpoint / reuse existing — confirm]

3. DOMAIN QUESTIONS RESOLVED:
   Q-01: Bypass All flag interpretation — Palanivel confirmed at Stage 3: [date]
   Q-02: Cross-database Company=ALL behaviour — Palanivel confirmed at Stage 3: [date]
   Q-03: PO_Para update key column — DBA confirmed: [date]

4. OPEN CEO DECISIONS (if any):
   [If none after Stage 4: "None — all items resolved before development"]

5. DEFERRED ITEMS (CEO-approved):
   [None anticipated]
```

---

# DEPLOYMENT NOTICE FORMAT

```
Subject: M01 Final Level PR Approval — Build v[X.X] Deployed — [Date]

This build implements:
  Module:    M01 Purchase Order — Final Level PR Approval
  FSD:       v1.4, CEO-approved [date]
  UI/UX:     SPINRISE_FSD_M01_PRFinalLevelApproval_v1_2.html, approved [date]
  Deployed:  http://172.16.16.40:3000/purchase/final-level-pr-approval at [time]
  CR Version: v[X.X]

Changes in this build:
  1. Final Level PR Approval form — complete implementation
  2. ksp_po_finalapproval SP — all CD-07 to CD-12 defects fixed
  3. GET /api/finallevel-pr — grid load with imode=2/3 routing
  4. POST /api/finallevel-pr/approve — batch save with rowversion concurrency
  5. Row colour by approval status (First/Second/Third)
  6. Bypass All flag — imode=2 SP routing confirmed (OBS-2)
  7. OI-09: FirstApp write removed; SecondApp='Y' only on Bypass=ON
  8. Disposition=Declined → FClosed='Y' on PO_PRL
  9. SMS notifications for all 5 disposition codes (CD-11 Postponed fix included)
  10. Cancellation guard: cancelled PRs blocked from approval

Test environment:
  Frontend: http://172.16.16.40:3000/purchase/final-level-pr-approval
  Backend:  http://172.16.16.40:5001/api/finallevel-pr

IST Test Checklist: [attached / see [filename]]
FSD Compliance Report: [attached]
Stage 1 Self-Check: COMPLETE — all items PASS

Next step: IST review by [Muthuvel / Seenivasan] | TL-IST gate: Palanivel
```

---

# IMPLEMENTATION SEQUENCE — ENFORCED ORDER

```
1. Gate 0 verification — ALL items confirmed (Stage 3 + Stage 4 REQUIRED before proceeding)
2. VB6 migration assumption checklist — complete (see Step 1 above — already filled)
3. Pre-migration DB verification — run verification queries in SSMS on JAT
4. No new columns needed — no migration script execution required
5. Confirm Al_SMSMessage / pp_database / pp_divmas column names before SP coding
6. SP: ksp_po_finalapproval — CREATE OR ALTER with all CD fixes
7. API contract review — agreed between Mohan Babu and Abinandan
8. Backend controllers + services + repositories
9. Frontend: Zustand store → API layer → filter bar → AG Grid → footer → modals
10. Step 7: NOT APPLICABLE (confirmed)
11. Stage 1 self-check — all items PASS
12. FSD Compliance Report — complete
13. IST handover package — deployed + checklist + compliance report
```

**No step may be skipped. No step may be reordered.**

---

*SPINRISE Project · Kalpatharu Software Ltd · Internal Confidential · Blueprint v6.2*
*Prompt compiled: 31-May-2026 by Abinandan | Source: Mockdown v1.0 + UI/UX v1_2 + JAT Schema*
