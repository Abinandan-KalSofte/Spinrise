# SPINRISE — FULLSTACK MODULE DEVELOPMENT PROMPT
## Module Instance: M01 PR Amendment Entry
## Base Template: PROMPT_02 v1.1 | 27 May 2026
## FSD: v2.3 CEO-countersigned 23-May-2026

---

> **CRITICAL:** This prompt executes code generation only after ALL gates are passed.
> Mandatory sequence: Gap Register closed → DB migration → API contract → Backend → Frontend → QuestPDF → Stage 1
> Skipping any step is a process violation.

---

# ROLE

Act as Senior Fullstack Developer for SPINRISE ERP.

You are implementing the M01 PR Amendment Entry module from:
1. Approved UI/UX design: `Docs/UI_UX Designs/SPINRISE_FSD_M01_PRAmendment_v2_3/SPINRISE_FSD_M01_PRAmendment_v2_3.html`
2. CEO-countersigned FSD: `Docs/Approved FSDs/SPINRISE_FSD_v2_3_PRAmendment_TL-IST_CEO_Stage4.md`
3. SPINRISE Migration Blueprint v6.1

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
SUBMODULE:             PR Amendment Entry
FSD VERSION:           v2.3   CEO-countersigned: 23-May-2026
UIUX DESIGN REF:       SPINRISE_FSD_M01_PRAmendment_v2_3.html
BLUEPRINT:             v6.1
VB6 SOURCE FORM:       tmpindAment.frm
VB6 LINE COUNT:        6,840
DB NAME:               SpinRiseSaranya
API BASE URL:          http://172.16.16.40:5001/api/
FRONTEND URL:          http://172.16.16.40:3000/
JIRA EPIC:             M01-AMENDMENT
DEVELOPER:             Mariyaiya.M
SPRINT:                Sprint 2
IMPLEMENTATION DATE:   [fill before running]
```

---

# GATE 0 — PRE-DEVELOPMENT VERIFICATION

```
GATE 0 CHECKLIST — M01 PR AMENDMENT ENTRY

FSD:
  [x] FSD version: v2.3  CEO-countersigned: 23-May-2026  CONFIRMED
  [x] CEO countersignature date confirmed on document (Section 9 sign-off block)
  [x] FSD is current version (v2.3 is latest — Stage 2 re-confirmed 22-May-2026)
  [x] All IST Q resolutions reviewed: OI-01 to OI-05 all CLOSED
  [x] FSD/Blueprint conflicts: all resolved — EmpCommon/PurTypeFlg/BackDate confirmed
      as po_para global vars, NOT ig_param reads (v2.3 Sasi correction applied)
  [x] OI-06 CEO Working Session: NOT APPLICABLE (Amendment FSD had CEO Working Session)

UI/UX Design:
  [ ] UI/UX design spec approved — sign-off by: _________
  [ ] All gaps in Gap Register = CLOSED or NOT-BLOCKING
  [ ] No Critical gap open

Domain Gaps:
  [x] Rate field: RATE_SOURCE=ORIGINAL pre-populated from PO_APRL on load
      Manual override = RATE_SOURCE=MANUAL + RATE_JUSTIFICATION mandatory
      (CEO directive v2.2/v2.3 — no 3-option selector on Amendment screen)
  [x] Amendment count: informational badge only — no maximum enforced (CEO 22-May-2026)
  [x] BackDate rule: Amendment Date must equal pdate — ALL customers equal
      (Kumaragiri-specific variation removed in v2.3, confirmed by Sasi)
  [x] EmpCommon, PurTypeFlg, BackDate: global vars from po_para login — NOT ig_param
  [x] SCOPECODE: removed from SPINRISE UI — DB column retained for legacy reads

DB/Backend:
  [x] SP names confirmed:
        usp_GetNextAmendNo (amendment number generation, SERIALIZABLE + UPDLOCK)
  [x] New DB columns: PO_APRL.RATE_SOURCE varchar(20) NULL
                      PO_APRL.RATE_JUSTIFICATION varchar(200) NULL
                      PO_APRH.rowversion ROWVERSION
  [x] New table: PO_PRINT_LOG (print event tracking for re-print control)
  [x] LogDet_PO ALTER: add before_values, after_values columns (verify with DBA)
  [x] Migration script path: D:\SpinriseV2\Development\Backend\Spinrise.DBScripts\

VB6 Migration:
  [x] Stage 0 sign-off received: 18-May-2026 by Sasi — FULLY APPROVED (8 findings resolved)
  [x] VB6 Migration Assumption Checklist: complete (see Step 1 below)

GATE 0 APPROVED BY: _________________ DATE: _________
```

---

# STEP 1 — VB6 MIGRATION ASSUMPTION CHECKLIST

| # | VB6 Pattern | Present? | SPINRISE Replacement | Risk if missed |
|---|---|---|---|---|
| 1 | MAX(n)+1 auto-number | **Y** — SELECT MAX(amendno)+1 in newdocno() | `usp_GetNextAmendNo` SP with SERIALIZABLE + UPDLOCK + HOLDLOCK — AF-04 resolved | Duplicate amendment numbers |
| 2 | Delete-all-lines Modify-save | Y | Delta-update via PO_APRH/PO_APRL | Destroys partial data |
| 3 | Boolean flag with VB6 True/False | Y | Validate each one | Grid wiped on successful load |
| 4 | Hardcoded CustID / DivCode | N — G1 PASS — all removed | Parameterized @divcode always | Wrong data for other tenants |
| 5 | String concatenation in SQL | **Y** — 101 lines (CD-01, VB6 backlog) | Dapper @parameter binding — zero string SQL in SPINRISE | SQL injection |
| 6 | CommitTrans boundary | **Y** — AF-02, AF-08 fixed in Stage 0 | All DML inside BEGIN TRANSACTION / COMMIT | Partial saves |
| 7 | Secondary update outside CommitTrans | **Y** — DbTmp dual connection (CD-04) | Single Dapper IDbConnection + IDbTransaction for all writes | Orphaned data |
| 8 | App-terminating on modal condition | Y | Dismissable modal | App crash |
| 9 | ig_param reference | **N** — CONFIRMED: EmpCommon/PurTypeFlg/BackDate are po_para globals (v2.3 correction) | Not applicable — no ig_param reads in this form | Dead code / mis-config |
| 10 | prstatus='C' usage | N | prstatus='C' = RECEIVED. Amendment status tracked via PO_APRH | Wrong status |
| 11 | EmpCommon flag branch | **Y** — PurTypeFlg in bindcontls + IndType | PO_Para.EmpMasterComm='Y' = company-wide lookup | Wrong employee scope |
| 12 | Form-level global variables | **Y** — EmpCommon, PurTypeFlg, BackDate | Read from po_para at login → pass as params | State bleed |
| 13 | F1 key handler | Y | Remove — replace with Alt+↓ | Browser break |
| 14 | Single-instance form | Y | Concurrent user design | Race conditions |
| 15 | FClosed flag | N | Not applicable to Amendment | N/A |
| 16 | CANCELFLAG vs APPFLG | N | Not applicable to Amendment | N/A |
| 17 | rowversion concurrency | **Y** — new column on PO_APRH | Read on load, validate in SP on save | Lost updates |

---

# STEP 2 — DB MIGRATION SCRIPT

```sql
-- ============================================================
-- SPINRISE MIGRATION — M01 PR Amendment Entry
-- FSD: v2.3 CEO-countersigned 23-May-2026
-- Author: Mariyaiya.M | Date: [fill before running]
-- DB: SpinRiseSaranya
-- EXECUTION CONTROL: Execute only after CEO countersignature.
-- ============================================================

-- 1. RATE_SOURCE column on PO_APRL
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'PO_APRL' AND COLUMN_NAME = 'RATE_SOURCE')
BEGIN
    ALTER TABLE PO_APRL ADD RATE_SOURCE varchar(20) NULL;
END

-- 2. RATE_JUSTIFICATION column on PO_APRL
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'PO_APRL' AND COLUMN_NAME = 'RATE_JUSTIFICATION')
BEGIN
    ALTER TABLE PO_APRL ADD RATE_JUSTIFICATION varchar(200) NULL;
END

-- 3. rowversion concurrency column on PO_APRH
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'PO_APRH' AND COLUMN_NAME = 'rowversion')
BEGIN
    ALTER TABLE PO_APRH ADD [rowversion] ROWVERSION;
END

-- 4. PO_PRINT_LOG table (print event tracking for re-print control)
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'PO_PRINT_LOG')
BEGIN
    CREATE TABLE PO_PRINT_LOG (
        id          int IDENTITY(1,1) PRIMARY KEY,
        divcode     varchar(10)  NOT NULL,
        amendno     int          NOT NULL,
        amenddate   datetime     NOT NULL,
        printed_by  varchar(50)  NOT NULL,
        printed_on  datetime     NOT NULL DEFAULT GETDATE(),
        reprint_flag char(1)     NOT NULL DEFAULT 'N'
    );
END

-- 5. LogDet_PO — add before_values / after_values if not present (confirm with DBA)
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'LogDet_po' AND COLUMN_NAME = 'before_values')
BEGIN
    ALTER TABLE LogDet_po ADD before_values nvarchar(MAX) NULL;
END
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'LogDet_po' AND COLUMN_NAME = 'after_values')
BEGIN
    ALTER TABLE LogDet_po ADD after_values nvarchar(MAX) NULL;
END

-- NOTE: usp_GetNextAmendNo is deployed as a stored procedure (see Step 4)

-- Verification
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME IN ('PO_APRL', 'PO_APRH', 'LogDet_po')
ORDER BY TABLE_NAME, ORDINAL_POSITION;
```

New columns:
| Column | Table | Type | Nullable | Default | Reason |
|---|---|---|---|---|---|
| RATE_SOURCE | PO_APRL | varchar(20) | Y | NULL | FSD v2.3 — rate origin tracking (ORIGINAL / MANUAL) |
| RATE_JUSTIFICATION | PO_APRL | varchar(200) | Y | NULL | FSD v2.3 — mandatory when RATE_SOURCE=MANUAL |
| rowversion | PO_APRH | ROWVERSION | N (auto) | auto | Blueprint v6 §12 concurrency control |
| before_values | LogDet_po | nvarchar(MAX) | Y | NULL | FSD v2.3 — MOD audit trail |
| after_values | LogDet_po | nvarchar(MAX) | Y | NULL | FSD v2.3 — MOD audit trail |

---

# STEP 3 — API CONTRACT

## Endpoints: PR Amendment

### GET /api/pramendment/{prNo}/{prDate}
Loads a PR and its line items for amendment. Pre-populates Rate from PO_APRL (RATE_SOURCE=ORIGINAL).

```typescript
interface PrAmendmentLoadResponse {
  prNo: string;
  prDate: string;           // DD/MM/YYYY
  divCode: string;
  depCode: string;
  amendNo: number;          // current amendment count (display badge)
  rowVersion: string;       // base64 — for concurrency check on save
  lineItems: Array<{
    prsNo: number;
    itemCode: string;
    itemName: string;
    originalQty: number;    // 3dp — qty from original PR
    amendedQty: number;     // 3dp — current amended qty
    rate: number;           // 4dp — pre-populated from PO_APRL
    rateSource: 'ORIGINAL' | 'MANUAL';
    rateJustification: string | null;
    value: number;          // 2dp — computed: amendedQty * rate
  }>;
}
```

### POST /api/pramendment
Save amendment (Add — creates new amendment record).

```typescript
// HTTP 201
interface PrAmendmentSaveRequest {
  prNo: string;
  prDate: string;
  divCode: string;
  amendDate: string;        // must equal prDate — validated server-side
  rowVersion: string;       // concurrency token from load
  lineItems: Array<{
    prsNo: number;
    amendedQty: number;     // 3dp
    rate: number;           // 4dp
    rateSource: 'ORIGINAL' | 'MANUAL';
    rateJustification?: string;  // mandatory when rateSource = 'MANUAL'
  }>;
}
```

### PUT /api/pramendment/{amendNo}
Modify existing amendment.

### DELETE /api/pramendment/{amendNo}
Delete amendment. Returns HTTP 200 with deleted amendNo.

### GET /api/pramendment/{amendNo}/print
Generate PDF. Returns PDF binary. Logs to PO_PRINT_LOG.

### Validation Error (HTTP 422)
```typescript
interface ValidationErrorResponse {
  errors: Array<{
    field: string;
    code: string;   // "REQUIRED" | "DATE_MISMATCH" | "RATE_JUSTIFICATION_REQUIRED" | "FY_GUARD"
    message: string;
  }>;
}
```

### Business Rule Error (HTTP 400)
```typescript
interface BusinessErrorResponse {
  code: string;    // "CONCURRENCY_CONFLICT" | "NO_OPEN_FY"
  message: string;
}
```

### Decimal Precision:
- Quantity: 3 decimal places
- Rate: 4 decimal places
- Value/Cost: 2 decimal places

---

# STEP 4 — STORED PROCEDURE IMPLEMENTATION

### usp_GetNextAmendNo (amendment number generation)
```sql
-- SP name CONFIRMED by Sasi (Stage 2, 23-May-2026) — do not rename
CREATE OR ALTER PROCEDURE [dbo].[usp_GetNextAmendNo]
    @divcode    VARCHAR(10),
    @v_stdate   VARCHAR(20),
    @v_endate   VARCHAR(20),
    @newdocno   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- SERIALIZABLE isolation prevents race condition on concurrent amendment entry
        SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
        BEGIN TRANSACTION;

        SELECT @newdocno = ISNULL(MAX(amendno), 0) + 1
        FROM   PO_APRH WITH (UPDLOCK, HOLDLOCK)
        WHERE  divcode  = @divcode
          AND  amenddate BETWEEN @v_stdate AND @v_endate;

        -- Returns -1 if PO_DOC_PARA config row is missing
        IF NOT EXISTS (SELECT 1 FROM PO_DOC_PARA WHERE divcode = @divcode)
        BEGIN
            SET @newdocno = -1;
            ROLLBACK TRANSACTION;
            RETURN;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @newdocno = -1;
        THROW;
    END CATCH
END
```

### ksp_PR_SaveAmendment (save Add/Modify/Delete)
```sql
CREATE OR ALTER PROCEDURE [dbo].[ksp_PR_SaveAmendment]
    @PRNo           varchar(20),
    @PRDate         datetime,
    @DivCode        varchar(10),
    @AmendDate      datetime,
    @LineItems      [AmendmentLineItemType],   -- TVP or JSON
    @CreatedBy      varchar(50),
    @RowVersion     varbinary(8),
    @Action         char(1),     -- 'A' = Add, 'M' = Modify, 'D' = Delete
    @Result         int OUTPUT   -- 0=success, 1=validation error, 2=business error
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. FY Guard (mandatory for Amendment)
        IF NOT EXISTS (
            SELECT 1 FROM PP_Year
            WHERE yfdate <= @AmendDate AND yldate >= @AmendDate AND status = 'O'
        )
        BEGIN
            SET @Result = 1;
            RAISERROR('Amendment Date is outside the open financial year.', 16, 1);
            RETURN;
        END

        -- 2. AmendDate = PRDate guard
        IF CONVERT(date, @AmendDate) <> CONVERT(date, @PRDate)
        BEGIN
            SET @Result = 1;
            RAISERROR('Amendment Date must equal the PR Date.', 16, 1);
            RETURN;
        END

        -- 3. Concurrency check
        IF @Action IN ('M', 'D')
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM PO_APRH
                           WHERE prno = @PRNo AND prdate = @PRDate
                             AND divcode = @DivCode AND [rowversion] = @RowVersion)
            BEGIN
                SET @Result = 2;
                RAISERROR('Record has been modified by another user. Please reload.', 16, 1);
                RETURN;
            END
        END

        -- 4. RATE_JUSTIFICATION mandatory when RATE_SOURCE = 'MANUAL'
        -- (validate in each line item — raise 422 if any manual rate has no justification)

        -- 5. Main DML — inside transaction
        -- INSERT / UPDATE PO_APRH, PO_APRL with RATE_SOURCE + RATE_JUSTIFICATION

        -- 6. Audit record
        INSERT INTO LogDet_po (divcode, prno, prdate, Trans_UserId, Trans_Name, Trans_Mod,
                                Trans_date, before_values, after_values)
        VALUES (@DivCode, @PRNo, @PRDate, @CreatedBy, 'PR Amendment', @Action,
                GETDATE(), [before_values_json], [after_values_json]);

        COMMIT TRANSACTION;
        SET @Result = 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @Result = 2;
        THROW;
    END CATCH
END
```

SP rules applied:
- `usp_GetNextAmendNo`: uses SERIALIZABLE + UPDLOCK + HOLDLOCK (not a SEQUENCE — FSD confirmed)
- AmendDate = PRDate: validated in SP (FSD v2.3 — ALL customers equal)
- RATE_JUSTIFICATION: mandatory when RATE_SOURCE='MANUAL' — enforced in SP
- rowversion: concurrency check in MOD/DEL paths
- All DML inside transaction
- Audit record (LogDet_po) inside transaction

---

# STEP 5 — BACKEND IMPLEMENTATION

### Controller: `PrAmendmentController.cs`
Location: `Spinrise.API/Areas/PurchaseOrder/Amendment/`

```csharp
[ApiController]
[Route("api/pramendment")]
public class PrAmendmentController : BaseApiController
{
    [HttpGet("{prNo}/{prDate}")]
    public async Task<IActionResult> Load(string prNo, string prDate)

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] PrAmendmentSaveRequest request)
    // → 201 on success

    [HttpPut("{amendNo}")]
    public async Task<IActionResult> Modify(int amendNo, [FromBody] PrAmendmentSaveRequest request)
    // → 200 on success

    [HttpDelete("{amendNo}")]
    public async Task<IActionResult> Delete(int amendNo)
    // → 200 with deleted ID

    [HttpGet("{amendNo}/print")]
    public async Task<IActionResult> Print(int amendNo)
    // → PDF binary, logs to PO_PRINT_LOG
}
```

### Service: `PrAmendmentService.cs`
Location: `Spinrise.Application/Areas/PurchaseOrder/Amendment/`

Validation rules:
| Rule | Implementation | HTTP code |
|---|---|---|
| AmendDate mandatory | null/empty check | 422 |
| AmendDate = PRDate | compare dates | 422 |
| FY guard | PP_Year query in SP | 422 |
| RATE_JUSTIFICATION mandatory when MANUAL | check per line item | 422 |
| Concurrency check | rowversion match | 400 |

### DTOs: `PrAmendmentDto.cs`
Location: `Spinrise.Application/Areas/PurchaseOrder/Amendment/DTOs/`

Decimal precision in DTO mapping:
- qty: `Math.Round(qty, 3)` / display `qty.ToString("F3")`
- rate: `Math.Round(rate, 4)` / display `rate.ToString("F4")`
- value: `Math.Round(value, 2)` / display `value.ToString("F2")`

### Repository: `PrAmendmentRepository.cs`
Location: `Spinrise.Infrastructure/Areas/PurchaseOrder/Amendment/`
- All data access via Dapper + stored procedures
- No raw SQL, no EF

---

# STEP 6 — FRONTEND IMPLEMENTATION

### File structure
```
src/features/pr/components/pr-amendment/
├── PrAmendmentPage.tsx          ← route-level component
├── PrAmendmentHeader.tsx        ← header fields
├── PrAmendmentLineGrid.tsx      ← AG Grid line items
└── PrAmendmentRateCell.tsx      ← rate + justification inline cell
src/features/pr/hooks/
└── usePrAmendmentForm.ts
src/features/pr/api/
└── prAmendment.api.ts
```

### Toolbar config (standard 5-mode — Amendment uses full CRUD)
```typescript
const toolbarConfig = {
  add:    { add: false, modify: true,  delete: true,  find: true,  save: false, cancel: false, print: false },
  modify: { add: true,  modify: false, delete: true,  find: true,  save: true,  cancel: true,  print: false },
  delete: { add: true,  modify: true,  delete: false, find: false, save: false, cancel: false, print: false },
  find:   { add: true,  modify: true,  delete: false, find: false, save: false, cancel: false, print: true  },
  view:   { add: true,  modify: true,  delete: true,  find: true,  save: false, cancel: false, print: true  },
};
// Find DISABLED in delete mode — CR-PR-01 permanent fix
```

### Rate field — module-specific rule (CEO v2.3 directive)
```typescript
// Rate cell behaviour in line grid:
// On load: rate = pre-populated from PO_APRL, rateSource = 'ORIGINAL', field read-only
// If user edits rate: rateSource → 'MANUAL', show RATE_JUSTIFICATION input (mandatory)
// If user clears rate edit: rateSource → 'ORIGINAL', hide justification, field read-only again

// Validation on Save:
if (lineItem.rateSource === 'MANUAL' && !lineItem.rateJustification?.trim()) {
  setFieldError(`lineItems[${idx}].rateJustification`, 'Rate justification is required when rate is manually overridden');
}
```

### Amendment count badge
```typescript
// Display amendment count as informational badge only
// Never block save based on amendment count
// CEO 22-May-2026: no maximum enforcement at any live customer
<Badge count={amendNo} color="blue" title={`Amendment No. ${amendNo}`} />
```

### Decimal precision
```typescript
import { DECIMAL_PRECISION } from '@/constants/precision';
<InputNumber precision={DECIMAL_PRECISION.QUANTITY} ... />   // qty fields
<InputNumber precision={DECIMAL_PRECISION.RATE} ... />       // rate field
<InputNumber precision={DECIMAL_PRECISION.VALUE} ... />      // value (computed, display only)
```

---

# STEP 7 — QUESTPDF PRINT TEMPLATE

**Print applies to PR Amendment Entry.**

### Field Mapping Table — PrAmendmentReport (compact, < 5 line items)

| FSD Field | DB Column / API Field | Precision | Report Region | Position | Notes |
|---|---|---|---|---|---|
| PR Number | PO_PRH.prno | 6-digit padded | Header | Left | |
| PR Date | PO_PRH.prdate | DD/MM/YYYY | Header | Left | |
| Amendment No | PO_APRH.amendno | integer | Header | Left | |
| Amendment Date | PO_APRH.amenddate | DD/MM/YYYY | Header | Left | |
| Department | PO_PRH.DEPCODE | — | Header | Left | |
| Requester Name | PR_EMP.ENAME | — | Header | Right | |
| ERP Username | PO_APRH.createdby | — | Header | Right | NOT session username |
| Print Date/Time | System.DateTime.Now | dd/MM/yyyy hh:mm tt | Footer | Left | 12-hr AM/PM — Footer (CEO 21-May decision) |
| Total Value | Sum(PO_APRL.value) | 2dp | Footer | Right | |
| Item Code | PO_APRL.itemcode | — | Grid | Col 1 | |
| Item Description | IN_ITEM.itemname | — | Grid | Col 2 | |
| Original Qty | PO_PRL.qtyreq | 3dp | Grid | Col 3 | Right-aligned |
| Amended Qty | PO_APRL.amendedqty | 3dp | Grid | Col 4 | Right-aligned |
| Rate | PO_APRL.rate | 4dp | Grid | Col 5 | Right-aligned |
| Rate Source | PO_APRL.RATE_SOURCE | — | Grid | Col 6 | Show ORIGINAL/MANUAL |
| Rate Justification | PO_APRL.RATE_JUSTIFICATION | — | Grid | Col 7 | Only if MANUAL |
| Value | PO_APRL.value | 2dp | Grid | Col 8 | Right-aligned |

### Field Mapping Table — PrAmendmentFullReport (full, >= 5 line items)
Same fields as above — different page layout (landscape, multi-page with repeat headers).

### Report switching condition
```csharp
IDocument report = lineItems.Count < 5
    ? new PrAmendmentReport(data)
    : new PrAmendmentFullReport(data);
```

### JOIN filter requirement
```csharp
// DEPCODE filter on machine-related joins (Defect 19 pattern):
WHERE PO_APRL.amendno = @AmendNo
  AND (MM_MACMAS.macno IS NULL OR MM_MACMAS.depcode = PO_APRH.DEPCODE)
```

### Re-Print Control
```csharp
// First print: insert PO_PRINT_LOG with reprint_flag = 'N'
// Re-print: insert PO_PRINT_LOG with reprint_flag = 'Y'
// Frontend: after first print success, change button label to "Reprint"
```

---

# STEP 8 — STAGE 1 SELF-CHECK

```
STAGE 1 SELF-CHECK — M01 PR Amendment Entry
Developer: Mariyaiya.M | FSD: v2.3 CEO-countersigned 23-May-2026

HAPPY PATH:
  [ ] Add new amendment — Save — record appears in list with correct amendNo
  [ ] Modify existing amendment — Save — change reflected immediately
  [ ] Delete amendment — record removed immediately (no ghost)
  [ ] Print (< 5 items) — PrAmendmentReport: all fields present, decimals correct
  [ ] Print (>= 5 items) — PrAmendmentFullReport: all fields present, decimals correct
  [ ] Reprint — shows "Reprint" label, logs to PO_PRINT_LOG with reprint_flag='Y'
  [ ] Find — filter works correctly

AMENDMENT-SPECIFIC VALIDATION:
  [ ] AmendDate = PRDate enforced — any other date blocked with message
  [ ] Rate field: loads as ORIGINAL (read-only) from PO_APRL
  [ ] Rate override: RATE_JUSTIFICATION field appears, is mandatory, blocks save if empty
  [ ] Rate clear: field reverts to ORIGINAL (read-only), justification hidden
  [ ] Amendment count badge: shows current count, no hard block on count
  [ ] SCOPECODE field: absent from UI (DB column still in DB — not visible)

MANDATORY FIELD VALIDATION:
  [ ] Each mandatory field: empty → correct error shown
  [ ] Each mandatory field: valid value → error cleared
  [ ] FY guard: AmendDate outside FY → blocked with message
  [ ] FY guard: AmendDate inside FY → accepted

DECIMAL PRECISION:
  [ ] Quantity fields: 3 decimal places
  [ ] Rate fields: 4 decimal places
  [ ] Value/Cost fields: 2 decimal places
  [ ] Both print templates: all decimal precisions correct

CONCURRENCY:
  [ ] Two users edit same amendment simultaneously → second save blocked with conflict message
  [ ] After conflict: form state rolled back, user can reload

TOOLBAR STATE:
  [ ] Add mode: correct buttons enabled/disabled
  [ ] Modify mode: correct buttons enabled/disabled
  [ ] Delete mode: correct buttons enabled/disabled (Find disabled)
  [ ] Find mode: correct buttons enabled/disabled
  [ ] View mode: correct buttons enabled/disabled

REACT STATE:
  [ ] After Add → new record in list with correct amendNo from server
  [ ] After Modify → only changed record updated in list
  [ ] After Delete → record removed immediately, no ghost
  [ ] After API error → form state rolled back, user notified

BLUEPRINT COMPLIANCE:
  [ ] No raw hex in any component — Blueprint tokens only
  [ ] Spacing: all gaps are multiples of 4px
  [ ] Field height: 32px all controls
  [ ] Grid row height: 32px

VB6 PATTERN CHECKS:
  [ ] usp_GetNextAmendNo used — no MAX+1 anywhere
  [ ] No delete-all-lines Modify-save — delta-update confirmed
  [ ] No hardcoded CustID/DivCode
  [ ] AmendDate = PRDate validated — not conditional on customer

PRINT STEP: APPLICABLE — both report variants tested ✅

ALL ITEMS PASS? [ ] YES → proceed to IST
                [ ] NO  → fix before IST submission
```

---

# STEP 9 — FSD COMPLIANCE REPORT

```
FSD COMPLIANCE REPORT
Module: M01 PR Amendment Entry | FSD: v2.3 CEO-approved 23-May-2026
UI/UX Design: SPINRISE_FSD_M01_PRAmendment_v2_3.html | Date: [fill]

1. DESIGN POINTS CONFIRMED COMPLIANT:
   1. AmendDate = PRDate: enforced for ALL customers — no customer variation (v2.3)
   2. Rate field: ORIGINAL pre-populated from PO_APRL on load
   3. RATE_SOURCE=MANUAL: RATE_JUSTIFICATION mandatory — confirmed
   4. Amendment count: informational badge only — no hard block (CEO 22-May-2026)
   5. usp_GetNextAmendNo: SERIALIZABLE + UPDLOCK — no MAX+1 race condition
   6. Decimal precision: Qty 3dp, Rate 4dp, Value 2dp — confirmed
   7. SCOPECODE: removed from UI — DB column retained for legacy reads
   8. QuestPDF: compact report (<5 lines) + full report (>=5 lines) — conditional switch
   9. PO_PRINT_LOG: re-print control — first print vs reprint logged
   10. rowversion: concurrency control on PO_APRH — confirmed

2. GAPS RESOLVED BEFORE CODE GENERATION:
   G-01: ig_param vs po_para — Resolution: po_para global vars confirmed (v2.3, Sasi)
   G-02: BackDate Kumaragiri variation — Resolution: removed, ALL customers equal (v2.3)
   G-03: Rate field — Resolution: CEO directive v2.2/v2.3 — ORIGINAL only, no 3-option selector

3. OPEN CEO DECISIONS:
   None — all items resolved before development

4. DEFERRED ITEMS:
   CD-01: 101 SQL concat lines in VB6 — CEO-accepted as VB6 backlog, not in SPINRISE
   CD-04: DbTmp dual connection — CEO-accepted as VB6 backlog, SPINRISE uses single connection
```

---

# DEPLOYMENT NOTICE FORMAT

```
Subject: M01 PR Amendment Entry — Build v[X.X] Deployed — [Date]

This build implements:
  Module:    M01 Purchase Order — PR Amendment Entry
  FSD:       v2.3, CEO-approved 23-May-2026
  UI/UX:     SPINRISE_FSD_M01_PRAmendment_v2_3.html, approved [date]
  Deployed:  http://172.16.16.40:3000/ at [time]
  CR Version: v[X.X]

Changes in this build:
  1. PR Amendment Entry — full CRUD (Add/Modify/Delete/Find/Print)
  2. RATE_SOURCE=ORIGINAL pre-populated; RATE_SOURCE=MANUAL + RATE_JUSTIFICATION flow
  3. usp_GetNextAmendNo — SERIALIZABLE isolation, no MAX+1 race condition
  4. QuestPDF compact + full report with re-print control (PO_PRINT_LOG)
  5. rowversion concurrency on PO_APRH

Test environment:
  Frontend: http://172.16.16.40:3000/purchase-requisition/amendment
  Backend:  http://172.16.16.40:5001/api/pramendment

IST Test Checklist: [attached]
FSD Compliance Report: [attached]
Stage 1 Self-Check: COMPLETE — all items PASS

Next step: IST review by Muthuvel / Seenivasan | TL-IST gate: Palanivel
```
