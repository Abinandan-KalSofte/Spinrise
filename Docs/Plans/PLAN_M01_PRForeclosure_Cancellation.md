# PLAN — M01: PR Foreclosure & Cancellation
**Updated:** 28 May 2026 — Revised against FSD v1.1 (Approved 19 May 2026, Stage 2 cleared 20 May 2026)  
**FSD Authority:** `Docs/Approved FSDs/docss/SPINRISE_FSD_M01_PRForeclosure_Cancellation_v1.1.docx`  
**UI/UX Foreclosure:** `SPINRISE_FSD_M01_PRForeclosure_v1_1.html`  
**UI/UX Cancellation:** `SPINRISE_FSD_M01_PRCancellationUndo_v1_1.html`  
**Branch:** `feature/m01-pr` (extend existing)  
**Build Order:** DB Migration → SP → Constants → DTOs → Interfaces → Infrastructure → Services → API → Frontend → Routes → Tests

---

> **GATE:** No coding before CEO countersignature (Stage 4). DB Migration (Phase 0) executes only after CEO sign-off.  
> **OI-06 OPEN:** CEO Working Session was not held before Stage 1 FSD writing — confirm waived by CEO T. Mani before Sprint start.

---

## Module Overview

| Sub-Module | Route | Description |
|---|---|---|
| PR Foreclosure | `/purchase-requisition/foreclosure` | Force-close open PR lines with positive balance. Irreversible. No undo. Cross-FY scope. |
| PR Cancellation | `/purchase-requisition/cancellation` | Cancel a full PR with reason. Undo within current FY only. Restores pre-cancel approval status. |

---

## FSD Critical Analysis — Corrections from Prior Draft

The following were **wrong in the previous planner draft** and are corrected throughout this document:

| # | Error | FSD Correct Answer |
|---|---|---|
| 1 | SP names confirmed by Sasi (28 May 2026) | Prefix: `ksp_PR_` — consistent with all existing M01 SPs |
| 2 | 7 SPs planned | Only 3 lookup SPs. Save/Cancel/Undo = inline Dapper inside services |
| 3 | Undo sets `PRSTATUS=NULL` | WRONG — must restore `pre_cancel_status` (BR-UNDO-01, CEO 26 May) |
| 4 | No schema migration section | `PO_PRH.pre_cancel_status`, `row_version` on both tables required |
| 5 | SP has no `@divcode` param | All 3 SPs need `@divcode varchar(10)` |
| 6 | Cancellation SPs have no FY params | `ksp_PR_GetCancellablePRs` and `ksp_PR_GetCancelledPRsForUndo` need `@yfdate`, `@yldate` |
| 7 | Foreclosure has FY filter implied | OI-01-F1 CLOSED: NO FY filter — cross-FY scope, all open PRs |
| 8 | Cancellable PRs missing `APPFLG` | Must add `APPFLG <> 'Y'` filter (OI-03-F2 CLOSED: field confirmed `PO_PRH.APPFLG`) |
| 9 | Cancellable PRs missing PO_ORD check | OI-02-F2 CLOSED by CEO: exclude PRs with any PO_ORD record |
| 10 | Balance formula incomplete | Must also enforce `qtyord - qtyrec >= 0` |
| 11 | Foreclosure per-row UPDATE missing `prdate`, `itemcode` in WHERE | VB6 WHERE: `prno + prdate + prsno + itemcode + divcode` |
| 12 | Cancel reason no alphanumeric validation | FSD: `ToAlphaNumber` equivalent — alphanumeric only |
| 13 | Print: UI has disabled Print button | Correct — HTML prototype shows disabled Print. No backend print SP/class needed. |

---

## PHASE 0 — DB Migration (Execute Once — After CEO Countersignature)

> **EXECUTE CONTROL:** Run only after CEO T. Mani countersignature (Stage 4).  
> Do NOT run in any live database before CEO approval.  
> Consolidate with M01 PR Form and PO Form DB migration scripts — Sasi to confirm before sprint.

### ALTER TABLE statements:

```sql
-- Required before SPINRISE go-live (shared cross-module changes)

-- Concurrency control: PO_PRH
ALTER TABLE PO_PRH ADD row_version ROWVERSION;

-- Concurrency control: PO_PRL
ALTER TABLE PO_PRL ADD row_version ROWVERSION;

-- BR-UNDO-01: stores PRSTATUS at time of cancellation for exact restoration on Undo
-- CEO confirmed 26 May 2026. Required for Undo Cancellation flow.
ALTER TABLE PO_PRH ADD pre_cancel_status char(1) NULL;
```

### Confirmed existing DDL (no ALTER required):

| Column | Table | Status |
|---|---|---|
| `FClosed char(1) NULL` | `PO_PRL` | CONFIRMED EXISTS |
| `FCloseddt datetime NULL` | `PO_PRL` | CONFIRMED EXISTS |
| `APPFLG char(1) NULL DEFAULT 'N'` | `PO_PRH` | CONFIRMED EXISTS (OI-03-F2 CLOSED) |
| All 15 LogDet_PO columns | `LogDet_PO` | CONFIRMED — no ALTER required |
| `Quantity numeric(15,3)` | `LogDet_PO` | CONFIRMED — 3dp decimal values insert correctly |

---

## PHASE 1 — Stored Procedures (3 Lookup SPs Only)

> **IMPORTANT:** Only 3 new SPs exist for this module. These are READ-ONLY lookup SPs only.  
> Save / Cancel / Undo DML operations use **inline parameterized Dapper** inside services — no separate SPs.  
> VB6 had no SPs for either form — all SQL was inline. SPINRISE introduces SPs only for the lookup modals.  
> SP names confirmed by Sasi at Stage 2 (20 May 2026).  
> All SPs: `SET NOCOUNT ON`, `TRY/CATCH`, no `SELECT *`, `CREATE OR ALTER PROCEDURE`.  
> Deploy via `merged.sql` only — never run individual SP files in production.

---

### SP-01: `ksp_PR_GetOpenForForeclosure`

**Purpose:** Load all PR lines eligible for foreclosure — populates the Foreclosure grid.  
**Scope:** Cross-FY — no financial year filter (OI-01-F1 CLOSED: prior-FY PRs may legitimately be foreclosed).

**Parameters (confirmed Sasi Stage 2):**
```sql
@divcode      varchar(10)
@prno_filter  varchar(20) = NULL   -- optional; NULL = return all; LIKE match on prno prefix
```

**Filter criteria:**
- `PO_PRL.FClosed <> 'Y'` (or IS NULL) — not already force-closed
- `PO_PRH.cancelflag = 'N'` — not cancelled
- Balance > 0: `ISNULL(PO_PRL.QTYREQD,0) - ISNULL(PO_PRL.QTYORD,0) - ISNULL(PO_PRL.enq_qty,0) > 0`
- `PO_PRL.QTYORD - ISNULL(PO_PRL.qtyrec,0) >= 0` — additional Billdisplay condition from VB6 code
- `PO_PRH.divcode = @divcode` — division scope (all queries)
- When `@prno_filter IS NOT NULL`: `PO_PRH.prno LIKE @prno_filter + '%'`
- **No** `yfdate`/`yldate` filter — cross-FY scope confirmed

**Joins:**
```
PO_PRH  (a) → PO_PRL (b) ON a.prno=b.prno AND a.divcode=b.divcode
PO_PRL  (b) → In_dep (c) ON b.depcode=c.depcode AND b.divcode=c.divcode
PO_PRL  (b) → in_item (d) ON b.itemcode=d.itemcode AND b.divcode=d.divcode
in_item (d) → mm_MACmas (e) LEFT JOIN ON e.MacFlag='M' AND e.divcode=d.divcode
                                        AND e.depcode=b.depcode AND e.macno=b.macno
```

**Result columns (match HTML `fc-table` grid exactly):**

| Column | Source | Format |
|---|---|---|
| PRNo | `PO_PRH.prno` | numeric — formatted frontend to 5-digit zero-pad |
| PRDate | `PO_PRH.prdate` | datetime |
| Department | `In_dep.Depname` | varchar |
| PrSno | `PO_PRL.prsno` | numeric |
| ItemCode | `in_item.itemcode` | varchar(10) |
| ItemName | `in_item.Itemname` | varchar |
| UOM | `in_item.UOM` | varchar |
| PrQty | `ISNULL(PO_PRL.QTYREQD,0)` | numeric(12,3) |
| OrdQty | `ISNULL(PO_PRL.QTYORD,0)` | numeric(12,3) |
| Balance | `ISNULL(QTYREQD,0)-ISNULL(QTYORD,0)-ISNULL(enq_qty,0)` | numeric — 3 dp |
| SccCode | `mm_MACmas.SCCCODE` | varchar — CEO direction 26 May 2026 |
| PrDate (row key) | `PO_PRH.prdate` | needed for per-row UPDATE WHERE clause |
| DepCode | `PO_PRH.depcode` | needed for LogDet_PO audit per row |
| PrevStatus | `PO_PRL.PRSTATUS` | char(1) — displayed as badge |

**ORDER BY:** `prdate, prno, prsno`

**File:** `Spinrise.DBScripts/Scripts/02-StoredProcedures/ksp_PR_GetOpenForForeclosure.sql`

---

### SP-02: `ksp_PR_GetCancellablePRs`

**Purpose:** Populate the "Select PR to Cancel" lookup modal (ScopeLookup equivalent).  
**Scope:** Current financial year only — `prdate BETWEEN @yfdate AND @yldate`.

**Parameters (confirmed Sasi Stage 2):**
```sql
@divcode   varchar(10)
@yfdate    datetime
@yldate    datetime
```

**Filter criteria:**
- `PO_PRH.CANCELFLAG IS NULL` (not already cancelled — original VB6 used `IS NULL`, not `<> 'Y'`)
- `PO_PRH.APPFLG <> 'Y'` — not approved (OI-03-F2 CLOSED: confirmed field `PO_PRH.APPFLG`)
- `PO_PRL.QTYORD = 0` — none ordered (aggregate per PR)
- `PO_PRH.prno NOT IN (SELECT prno FROM PO_ENQL WHERE divcode=@divcode)` — not yet enquired
- `PO_PRH.prno NOT IN (SELECT prno FROM PO_ORD WHERE divcode=@divcode)` — no PO raised against this PR (OI-02-F2 CLOSED by CEO 20 May 2026)
- `PO_PRH.prdate BETWEEN @yfdate AND @yldate` — within current FY
- `PO_PRH.divcode = @divcode`

**When PO_ORD record exists:** API returns HTTP 422 with message: *"A Purchase Order has been raised against this PR. Cancel the PO before cancelling the PR."*

**Result columns (match HTML Cancel modal table):**

| Column | Source |
|---|---|
| PRNo | `PO_PRH.prno` |
| PRDate | `PO_PRH.prdate` |
| Department | `In_dep.Depname` + `In_dep.depcode` |
| Requester | `PO_PRH.reqname` (or `pr_emp.ename` if empno linked) |
| ItemCount | `COUNT(PO_PRL.prsno)` |
| RefNo | `PO_PRH.refno` |
| PRType | from `PO_INDENTTYPE` via `PO_PRH.ITYPE` |
| Section | `PO_PRH.section` |
| CreatedBy | `PO_PRH.reqname` |
| Status | `PO_PRL.PRSTATUS` (first line or consistent) |
| DepCode | `PO_PRH.depcode` (needed for cancel WHERE) |
| PRDate (key) | `PO_PRH.prdate` (needed for cancel WHERE) |

**File:** `Spinrise.DBScripts/Scripts/02-StoredProcedures/ksp_PR_GetCancellablePRs.sql`

---

### SP-03: `ksp_PR_GetCancelledPRsForUndo`

**Purpose:** Populate the "Select Cancelled PR to Undo" lookup modal (undoLookup equivalent).  
**Scope:** Current financial year only — `prdate BETWEEN @yfdate AND @yldate`.

**Parameters (confirmed Sasi Stage 2):**
```sql
@divcode   varchar(10)
@yfdate    datetime
@yldate    datetime
```

**Filter criteria:**
- `PO_PRH.CANCELFLAG = 'Y'`
- `PO_PRH.prdate BETWEEN @yfdate AND @yldate`
- `PO_PRH.divcode = @divcode`

**Result columns (match HTML Undo modal table):**

| Column | Source |
|---|---|
| PRNo | `PO_PRH.prno` |
| PRDate | `PO_PRH.prdate` |
| Department | `In_dep.Depname` |
| RequestedBy | `PO_PRH.reqname` |
| CancelledOn | `PO_PRH.canceldt` |
| PrevStatus | `PO_PRH.pre_cancel_status` — the saved pre-cancel PRSTATUS (BR-UNDO-01) |
| DepCode | `PO_PRH.depcode` (needed for undo WHERE) |

**File:** `Spinrise.DBScripts/Scripts/02-StoredProcedures/ksp_PR_GetCancelledPRsForUndo.sql`

---

### merged.sql update
After all 3 SPs are created, append them to `Development/Backend/Spinrise.DBScripts/merged.sql`.

---

## PHASE 2 — Constants

**File:** `Development/Backend/Spinrise.Shared/Constants/StoredProcedures.cs`

Add only these 3 constants (Save/Cancel/Undo use inline Dapper — no SP constants needed):

```csharp
// PR Foreclosure & Cancellation — Lookup SPs only
// SP names confirmed by Sasi (Stage 2, 20 May 2026)
public const string PR_GetOpenForForeclosure    = "ksp_PR_GetOpenForForeclosure";
public const string PR_GetCancellablePRs        = "ksp_PR_GetCancellablePRs";
public const string PR_GetCancelledPRsForUndo   = "ksp_PR_GetCancelledPRsForUndo";
```

---

## PHASE 3 — DTOs (Application Layer)

**Location:** `Development/Backend/Spinrise.Application/Areas/PurchaseOrder/PurchaseRequisition/DTOs/`

### New DTOs to create:

#### `PrForeclosureLineDto.cs`
```csharp
int    PRNo
string PRDate        // dd-MMM-yyyy string
string Department    // In_dep.Depname
string DepCode       // PO_PRH.depcode — needed for LogDet_PO per-row audit
int    PrSno
string ItemCode
string ItemName
string UOM
decimal PrQty        // PO_PRL.QTYREQD — 3 dp
decimal OrdQty       // ISNULL(QTYORD,0) — 3 dp
decimal Balance      // QTYREQD-QTYORD-enq_qty — 3 dp
string SccCode       // mm_MACmas.SCCCODE
string PrevStatus    // PO_PRL.PRSTATUS raw char
```

#### `PrForeclosureSaveRequestDto.cs`
```csharp
[Required][MinLength(1)] List<PrForeclosureLineKeyDto> Lines
```

#### `PrForeclosureLineKeyDto.cs`
```csharp
[Required] int    PRNo
[Required] string PRDate    // needed in UPDATE WHERE clause
[Required] int    PrSno
[Required] string ItemCode  // needed in UPDATE WHERE clause
[Required] string DepCode   // needed for LogDet_PO audit
decimal Balance             // balance qty — written to LogDet_PO.Quantity
```

#### `PrCancellablePrDto.cs`
```csharp
int    PRNo
string PRDate
string DepCode       // needed for cancel WHERE clause
string Department    // display
string Requester
int    ItemCount
string RefNo
string PRType
string Section
string CreatedBy
string Status
```

#### `PrForCancellationHeaderDto.cs`
```csharp
int    PRNo
string PRDate
string DepCode       // needed for cancel/undo WHERE clause
string Department
string Section
string RequestedBy
string PRType
string RefNo
string CreatedBy
string Status        // current PRSTATUS badge
```

#### `PrForCancellationLineDto.cs`

Columns from VB6 bindcontls rs (PO_PRL + IN_ITEM + mm_MACmas), matching HTML prototype grid:

```csharp
int     Sno            // prsno
string  ItemCode       // in_item.itemcode
string  ItemName       // in_item.Itemname
string  UOM            // in_item.UOM
decimal QtyRequired    // PO_PRL.QTYIND (original indent qty)
decimal QtyApproved    // PO_PRL.QTYREQD (approved qty)
decimal QtyOrdered     // PO_PRL.QTYord
decimal QtyReceived    // PO_PRL.qtyrec
decimal Rate           // in_item.RATE — 4 dp
decimal ApproxCost     // PO_PRL.appcost — 2 dp
decimal CurrentStock   // in_item.curstk
string  ReqdDate       // PO_PRL.reqddate
string  Machine        // mm_MACmas.Description
string  PlaceOfIssue   // PO_PRL.place
string  Remarks        // PO_PRL.remarks
bool    IsSample       // derived from PRSTATUS or dedicated field
```

#### `PrForCancellationDetailDto.cs`
```csharp
PrForCancellationHeaderDto         Header
IEnumerable<PrForCancellationLineDto> Lines
```

#### `PrCancelRequestDto.cs`
```csharp
[Required] int    PRNo
[Required] string PRDate    // for WHERE clause
[Required] string DepCode   // for WHERE clause
[Required][MaxLength(200)][RegularExpression(@"^[a-zA-Z0-9\s\.,\-]+$", ErrorMessage = "Alphanumeric characters only")]
           string CancelReason
```

#### `PrCancelledPrDto.cs`
```csharp
int    PRNo
string PRDate
string DepCode         // needed for undo WHERE clause
string Department
string RequestedBy
string CancelledOn     // PO_PRH.canceldt
string PrevStatus      // PO_PRH.pre_cancel_status — the exact status to restore (BR-UNDO-01)
```

#### `PrUndoRequestDto.cs`
```csharp
[Required] int    PRNo
[Required] string PRDate    // for WHERE clause
[Required] string DepCode   // for WHERE clause
```

---

## PHASE 4 — Repository Interfaces (Application Layer)

**Location:** `Development/Backend/Spinrise.Application/Areas/PurchaseOrder/PurchaseRequisition/`

### `IPrForeclosureRepository.cs`
```csharp
Task<IEnumerable<PrForeclosureLineDto>> GetOpenForForeclosureAsync(string divcode, string? prNoFilter);
Task<int> SaveForeclosureAsync(List<PrForeclosureLineKeyDto> lines, string divcode, int userId, string userName, string machineIp, string machineHost);
```

### `IPrCancellationRepository.cs`
```csharp
Task<IEnumerable<PrCancellablePrDto>> GetCancellablePRsAsync(string divcode, DateTime yfdate, DateTime yldate);
Task<PrForCancellationDetailDto> GetPRForCancellationAsync(int prNo, string prDate, string depCode, string divcode);
Task CancelPRAsync(PrCancelRequestDto request, string divcode, int userId, string userName, string machineIp, string machineHost);
Task<IEnumerable<PrCancelledPrDto>> GetCancelledPRsForUndoAsync(string divcode, DateTime yfdate, DateTime yldate);
Task UndoCancellationAsync(PrUndoRequestDto request, string divcode, int userId, string userName, string machineIp, string machineHost);
```

---

## PHASE 5 — Repository Implementations (Infrastructure Layer)

**Location:** `Development/Backend/Spinrise.Infrastructure/Areas/PurchaseOrder/PurchaseRequisition/`

### `PrForeclosureRepository.cs`

**`GetOpenForForeclosureAsync`:** Calls `ksp_PR_GetOpenForForeclosure` via Dapper with `@divcode`, `@prno_filter`.

**`SaveForeclosureAsync`:** Inline Dapper inside `BeginTransaction`. No SP. Per-row logic:

```
BeginTransaction

For each line in request:
  1. UPDATE PO_PRL
        SET PRSTATUS='Z', FClosed='Y', FCloseddt=GETDATE()
      WHERE divcode=@divcode AND prno=@prno AND prdate=@prdate
        AND prsno=@prsno AND itemcode=@itemcode

  2. SELECT depcode FROM In_dep
      WHERE depname=@depname AND divcode=@divcode
     (released after each row — no open cursors in loops)

  3. INSERT INTO LogDet_PO (
        divcode, prno, prdate, depcode,
        Trans_UserId=@userId, prsno, itemcode,
        quantity=@balance,          -- balance qty being foreclosed
        username=@userName,
        Trans_date=GETDATE(),
        Trans_Name='Purchase Requisition Foreclosure',
        Trans_Mod='ADD',
        Trans_IPADD=@machineIp, Trans_Host=@machineHost,
        moduleNo=<ModuleNo>
     )
  rowCount++

If rowCount = 0: throw exception "Select at least one item to complete the transaction"
CommitTransaction
Return rowCount
```

---

### `PrCancellationRepository.cs`

**`GetCancellablePRsAsync`:** Calls `ksp_PR_GetCancellablePRs` via Dapper with `@divcode`, `@yfdate`, `@yldate`.

**`GetPRForCancellationAsync`:** Inline Dapper `QueryMultipleAsync` — two result sets:
- RS1: `SELECT PO_PRH.*, In_dep.Depname FROM PO_PRH LEFT JOIN In_dep WHERE prno=@prno AND prdate=@prdate AND depcode=@depcode AND divcode=@divcode`
- RS2: `SELECT PO_PRL.*, in_item.Itemname, in_item.UOM, in_item.RATE, in_item.curstk, mm_MACmas.Description FROM PO_PRL ... LEFT JOIN mm_MACmas (MacFlag='M') WHERE prno=@prno AND prdate=@prdate AND divcode=@divcode`

**`CancelPRAsync`:** Inline Dapper `BeginTransaction`. Logic per VB6 `Command1_Click (Opt='cancl')`:

```
Capture current PRSTATUS:
  SELECT TOP 1 PRSTATUS FROM PO_PRL
   WHERE divcode=@divcode AND prno=@prno AND prdate=@prdate
   (this is pre_cancel_status — BR-UNDO-01)

BeginTransaction

  Step 1: UPDATE PO_PRH
    SET cancelflag='Y',
        canceldt=GETDATE(),
        canreason=UPPER(@cancelReason),
        pre_cancel_status=@capturedPrstatus   -- BR-UNDO-01: save before cancellation
   WHERE DIVCODE=@divcode AND prno=@prno AND prdate=@prdate AND depcode=@depCode

  Step 2: UPDATE PO_PRL
    SET PRSTATUS='X'
   WHERE DIVCODE=@divcode AND prno=@prno AND prdate=@prdate

  Step 3: INSERT INTO LogDet_PO (
    divcode, prno, prdate, depcode=@depCode,
    username=@userName, Trans_date=GETDATE(), Trans_UserId=@userId,
    Trans_Name='Purchase Requisition Cancellation',
    Trans_Mod='ADD',
    Trans_IPADD=@machineIp, Trans_Host=@machineHost,
    moduleNo=<ModuleNo>
  )

CommitTransaction
```

**`GetCancelledPRsForUndoAsync`:** Calls `ksp_PR_GetCancelledPRsForUndo` via Dapper.

**`UndoCancellationAsync`:** Inline Dapper `BeginTransaction`. Logic per VB6 `Command1_Click (Opt='undo')`:

```
BeginTransaction

  Step 1: UPDATE PO_PRH
    SET cancelflag=NULL, canceldt=NULL, canreason=NULL,
        pre_cancel_status=NULL            -- BR-UNDO-01: clear after restore
   WHERE DIVCODE=@divcode AND prno=@prno AND prdate=@prdate AND depcode=@depCode

  Step 2: UPDATE PO_PRL
    SET PRSTATUS = (
      SELECT pre_cancel_status FROM PO_PRH
       WHERE divcode=@divcode AND prno=@prno AND prdate=@prdate
    )                                    -- BR-UNDO-01: restore exact pre-cancel status
   WHERE DIVCODE=@divcode AND prno=@prno AND prdate=@prdate

  Step 3: INSERT INTO LogDet_PO (
    divcode, prno, prdate, depcode=@depCode,
    username=@userName, Trans_date=GETDATE(), Trans_UserId=@userId,
    Trans_Name='Purchase Requisition Cancellation',
    Trans_Mod='DELETE',                  -- 'DELETE' for undo (matches VB6 audit)
    Trans_IPADD=@machineIp, Trans_Host=@machineHost,
    moduleNo=<ModuleNo>
  )

CommitTransaction
```

> **BR-UNDO-01 Note:** Step 2 reads `pre_cancel_status` from `PO_PRH` inside the same transaction — the subquery runs after Step 1 has already set `pre_cancel_status=NULL`. Therefore, capture `pre_cancel_status` into a local variable BEFORE Step 1 executes, then use that variable in Step 2.  
> Implementation: `var preStatus = await conn.QuerySingleAsync<string?>(...)` before `BeginTransaction` or inside a savepoint.

---

## PHASE 6 — Application Services (Application Layer)

**Location:** `Development/Backend/Spinrise.Application/Areas/PurchaseOrder/PurchaseRequisition/`

### `IPrForeclosureService.cs` + `PrForeclosureService.cs`

```csharp
Task<ApiResponse<IEnumerable<PrForeclosureLineDto>>> GetOpenLinesAsync(string? prNoFilter);
Task<ApiResponse<int>> SaveForeclosureAsync(PrForeclosureSaveRequestDto request);
```

Service resolves `divcode`, `userId`, `userName`, `machineIp`, `machineHost` from session/HttpContext.  
Validation: `request.Lines.Count == 0` → return `ApiResponse` with 422 before calling repository.

### `IPrCancellationService.cs` + `PrCancellationService.cs`

```csharp
Task<ApiResponse<IEnumerable<PrCancellablePrDto>>> GetCancellablePRsAsync();
Task<ApiResponse<PrForCancellationDetailDto>>      GetPRForCancellationAsync(int prNo, string prDate, string depCode);
Task<ApiResponse>                                   CancelPRAsync(PrCancelRequestDto request);
Task<ApiResponse<IEnumerable<PrCancelledPrDto>>>   GetCancelledPRsForUndoAsync();
Task<ApiResponse>                                   UndoCancellationAsync(PrUndoRequestDto request);
```

Service resolves `divcode`, `yfdate`, `yldate`, `userId`, `userName`, `machineIp`, `machineHost` from session/HttpContext.  
`CancelPRAsync` validation: empty `CancelReason` → HTTP 422 before DB call.

---

## PHASE 7 — API Controllers

**Location:** `Development/Backend/Spinrise.API/Areas/PurchaseOrder/`

### `PrForeclosureController.cs`

Route prefix: `api/pr-foreclosure`. Inherits `BaseApiController`.

```
GET  /api/pr-foreclosure/open-lines?prNoFilter={optional}   → GetOpenLinesAsync
POST /api/pr-foreclosure/save                               → SaveForeclosureAsync
```

Error handling (per CD-01-F1 through CD-03-F1 spec):
- `GetOpenLinesAsync` → try-catch; HTTP 500 + Serilog on DB error
- `SaveForeclosureAsync` → try-catch; HTTP 500 + Serilog; rollback on exception (handled in repository)

---

### `PrCancellationController.cs`

Route prefix: `api/pr-cancellation`. Inherits `BaseApiController`.

```
GET  /api/pr-cancellation/cancellable                        → GetCancellablePRsAsync
GET  /api/pr-cancellation/detail?prNo=&prDate=&depCode=      → GetPRForCancellationAsync
POST /api/pr-cancellation/cancel                             → CancelPRAsync
GET  /api/pr-cancellation/cancelled-for-undo                 → GetCancelledPRsForUndoAsync
POST /api/pr-cancellation/undo                               → UndoCancellationAsync
```

Error handling (per CD-03-F2 spec — all subs previously had no error handler):
- `GetCancellablePRsAsync` (ScopeLookup) → try-catch; HTTP 500 + Serilog on DB error
- `GetPRForCancellationAsync` (bindcontls) → try-catch on all 3 joins; HTTP 500 + Serilog
- `GetCancelledPRsForUndoAsync` (undoLookup) → try-catch; HTTP 500 + Serilog
- `CancelPRAsync` / `UndoCancellationAsync` → try-catch; HTTP 500 + Serilog; rollback via repository
- **No silent failures anywhere** — React toast notification on any API error

---

### DI Registration — `Program.cs`

```csharp
builder.Services.AddScoped<IPrForeclosureRepository, PrForeclosureRepository>();
builder.Services.AddScoped<IPrForeclosureService, PrForeclosureService>();
builder.Services.AddScoped<IPrCancellationRepository, PrCancellationRepository>();
builder.Services.AddScoped<IPrCancellationService, PrCancellationService>();
```

---

## PHASE 8 — Frontend: TypeScript Types

**File:** `Development/spinrise-web/src/features/pr/types.ts`

Append (do not replace existing types):

```typescript
// ── PR Foreclosure ────────────────────────────────────────────────
export interface PrForeclosureLineDto {
  prNo: number;
  prDate: string;
  department: string;
  depCode: string;
  prSno: number;
  itemCode: string;
  itemName: string;
  uom: string;
  prQty: number;
  ordQty: number;
  balance: number;
  sccCode: string;
  prevStatus: string;
}

export interface PrForeclosureLineKey {
  prNo: number;
  prDate: string;      // required for UPDATE WHERE clause
  prSno: number;
  itemCode: string;    // required for UPDATE WHERE clause
  depCode: string;     // required for LogDet_PO audit
  balance: number;     // written to LogDet_PO.Quantity
}

// ── PR Cancellation ───────────────────────────────────────────────
export interface PrCancellablePrDto {
  prNo: number;
  prDate: string;
  depCode: string;     // needed for cancel API call
  department: string;
  requester: string;
  itemCount: number;
  refNo: string;
  prType: string;
  section: string;
  createdBy: string;
  status: string;
}

export interface PrForCancellationHeader {
  prNo: number;
  prDate: string;
  depCode: string;     // needed for cancel WHERE
  department: string;
  section: string;
  requestedBy: string;
  prType: string;
  refNo: string;
  createdBy: string;
  status: string;
}

export interface PrForCancellationLine {
  sno: number;
  itemCode: string;
  itemName: string;
  uom: string;
  qtyRequired: number;   // PO_PRL.QTYIND — original indent qty
  qtyApproved: number;   // PO_PRL.QTYREQD — approved qty
  qtyOrdered: number;    // PO_PRL.QTYord
  qtyReceived: number;   // PO_PRL.qtyrec
  currentStock: number;  // in_item.curstk
  rate: number;          // 4 dp
  approxCost: number;    // 2 dp
  reqdDate: string;
  machine: string;
  placeOfIssue: string;
  remarks: string;
  isSample: boolean;
}

export interface PrForCancellationDetail {
  header: PrForCancellationHeader;
  lines: PrForCancellationLine[];
}

export interface PrCancelledPrDto {
  prNo: number;
  prDate: string;
  depCode: string;       // needed for undo WHERE
  department: string;
  requestedBy: string;
  cancelledOn: string;
  prevStatus: string;    // PO_PRH.pre_cancel_status — BR-UNDO-01: exact status to restore
}
```

---

## PHASE 9 — Frontend: API Layer

### `prForeclosureApi.ts`

**File:** `Development/spinrise-web/src/features/pr/api/prForeclosureApi.ts`

```typescript
import apiClient from '@/shared/api/apiClient';
import type { PrForeclosureLineDto, PrForeclosureLineKey } from '../types';

export const prForeclosureApi = {
  getOpenLines: (prNoFilter?: string) =>
    apiClient.get<ApiResponse<PrForeclosureLineDto[]>>('/pr-foreclosure/open-lines',
      { params: { prNoFilter } }),
  saveForeclosure: (lines: PrForeclosureLineKey[]) =>
    apiClient.post<ApiResponse<number>>('/pr-foreclosure/save', { lines }),
};
```

### `prCancellationApi.ts`

**File:** `Development/spinrise-web/src/features/pr/api/prCancellationApi.ts`

```typescript
import apiClient from '@/shared/api/apiClient';
import type {
  PrCancellablePrDto, PrForCancellationDetail, PrCancelledPrDto
} from '../types';

export const prCancellationApi = {
  getCancellable: () =>
    apiClient.get<ApiResponse<PrCancellablePrDto[]>>('/pr-cancellation/cancellable'),
  getPRForCancellation: (prNo: number, prDate: string, depCode: string) =>
    apiClient.get<ApiResponse<PrForCancellationDetail>>('/pr-cancellation/detail',
      { params: { prNo, prDate, depCode } }),
  cancelPR: (prNo: number, prDate: string, depCode: string, cancelReason: string) =>
    apiClient.post<ApiResponse>('/pr-cancellation/cancel', { prNo, prDate, depCode, cancelReason }),
  getCancelledForUndo: () =>
    apiClient.get<ApiResponse<PrCancelledPrDto[]>>('/pr-cancellation/cancelled-for-undo'),
  undoCancellation: (prNo: number, prDate: string, depCode: string) =>
    apiClient.post<ApiResponse>('/pr-cancellation/undo', { prNo, prDate, depCode }),
};
```

---

## PHASE 10 — Frontend: PR Foreclosure Page

**Location:** `Development/spinrise-web/src/features/pr/`

### Files to create:
```
hooks/usePrForeclosure.ts
components/foreclosure/PrForeclosureGrid.tsx
pages/PrForeclosurePage.tsx
```

---

### `hooks/usePrForeclosure.ts`

Manages:
- `lines: PrForeclosureLineDto[]` — grid data from API
- `selected: Map<string, PrForeclosureLineKey>` — keyed `"prNo-prSno"` → full key (needed for save payload)
- `prNoFilter: string`
- `isLoading: boolean`
- `load()` — calls `prForeclosureApi.getOpenLines(prNoFilter)` on mount and after save
- `toggleRow(line: PrForeclosureLineDto)`, `selectAll()`, `clearAll()`
- `confirmForeclosure()` — Ant Design Modal.confirm → `prForeclosureApi.saveForeclosure(Array.from(selected.values()))` → reload
- Footer stats: `totalLines`, `selectedCount`, `totalBalance` (sum all), `selectedBalance` (sum selected)

---

### `components/foreclosure/PrForeclosureGrid.tsx`

**UI — exact match to HTML prototype:**

```
[Toolbar — height 44px, white bg, border-bottom]
  ☑ Select All | ☐ Clear Selection | ─ |
  ⚡ Confirm Foreclosure [Ctrl+S] (disabled until selection) | ─ |
  🖨 Print [Ctrl+P] (disabled — "Not implemented — UI/UX design only") |
  ✕ Cancel [Alt+X] | … | [N selected] badge (green when N>0)

[Info Banner — blue #e6f4ff]
  ℹ Shows PR lines with status Requested only — balance > 0 · FClosed ≠ 'Y' · CancelFlag = 'N'
    Cross-FY scope (ksp_PR_GetOpenForForeclosure). Select lines to force-close.
    This action cannot be undone — no undo-foreclosure exists.

[Grid — dark sticky header #1e293b]
  ☐ | # | PR No | PR Date | Department | Item Id | Item Name | Unit |
  Quantity | Ordered | Balance | Sub Cost Centre | Status

[Empty state when grid is empty]
  📭 No open PR lines found
     All lines have zero balance, are already force-closed, or are cancelled.

[Footer strip — border-top: 2px solid var(--blue)]
  Total Lines: N | Selected: N | Total Balance: N.NNN | Selected Balance: N.NNN
```

**Grid behaviour:**
- Row checkbox: toggle selection; selected row → `.sel` class (blue bg `#dbeafe` + blue left border)
- Master checkbox in `<th>`: three-state — all/none/indeterminate
- Status badge colours: Requested=green, Partial=amber, Enquired=blue, Ordered=purple, Z=grey (already closed)
- Balance column: green bold
- PR No: zero-padded 5 digits, JetBrains Mono font, blue
- `Confirm Foreclosure` disabled + `.disabled` (opacity 0.35) until ≥1 selected
- On confirm: Ant Design `Modal.confirm` — icon ⚡, show line count + total balance, warn irreversible → POST save
- On save success: reload grid via `load()`, toast "N lines force-closed. Audit written to LogDet_PO."

**Keyboard shortcuts (attached on page mount):**
- `Ctrl+S` → trigger `confirmForeclosure()`
- `Alt+X` → `clearAll()`
- `Escape` → dismiss Ant Design modal

---

### `pages/PrForeclosurePage.tsx`

```
<PRDocBand>   Purchase Order › PR Foreclosure Entry | Processing Date: {today formatted dd-MMM-yyyy}
<PrForeclosureGrid />
```

---

## PHASE 11 — Frontend: PR Cancellation Page

### Files to create:
```
hooks/usePrCancellation.ts
components/cancellation/CancelPickerModal.tsx
components/cancellation/UndoPickerModal.tsx
components/cancellation/CancelSubTab.tsx
components/cancellation/UndoSubTab.tsx
pages/PrCancellationPage.tsx
```

---

### `hooks/usePrCancellation.ts`

**Cancel tab state:**
- `cancellableList: PrCancellablePrDto[]` — loaded once on mount via `getCancellable()`
- `cancelModalOpen: boolean`
- `selectedCancelPr: PrForCancellationDetail | null`
- `cancelReason: string` — max 200 chars, alphanumeric only
- `cancelReasonError: string | null`
- `isCancelling: boolean`

Methods: `openCancelModal()`, `closeCancelModal()`, `selectPrToCancel(pr: PrCancellablePrDto)`, `doCancel()`

**Undo tab state:**
- `cancelledList: PrCancelledPrDto[]` — loaded on tab switch
- `undoModalOpen: boolean`
- `selectedUndoPr: PrCancelledPrDto | null`
- `isUndoing: boolean`

Methods: `openUndoModal()`, `closeUndoModal()`, `selectPrToUndo(pr: PrCancelledPrDto)`, `doUndo()`

**Shared:** `activeTab: 'cancel' | 'undo'`, `reset()` — clears all state both tabs

---

### `components/cancellation/CancelPickerModal.tsx`

**UI — exact match to HTML Cancel modal ("danger red" mode):**

```
Modal width: 820px
  Header: red gradient icon + "Select PR to Cancel"
          subtitle: "Purchase Requisition · (N records)"
  Search: "Search by PR number, department or requester…"
  Table:
    PR No | PR Date | Department | Requester | Items
  Footer:
    [selected info / red PR tag + dept]
    [Cancel button] [Select to Cancel → (red #dc2626, disabled until row selected, opacity .4)]
```

Row interaction: click = highlight with red outline `#dc2626`; double-click = select + auto-close  
Search: client-side filter across all visible fields

---

### `components/cancellation/UndoPickerModal.tsx`

**UI — exact match to HTML Undo modal ("amber" mode):**

```
Modal width: 820px
  Header: amber gradient icon + "Select Cancelled PR to Undo"
          subtitle: "Cancelled PRs · FY 2025–26 only · (N cancelled PRs)"
  Search input
  Table:
    PR No | PR Date | Department | Requested By | Cancelled On | Prev. Status (badge)
  Footer:
    [selected info / amber PR tag + dept]
    [Cancel button] [↩ Undo This PR → (amber #BA7517)]
```

`Prev. Status` badge uses `pre_cancel_status` from `PrCancelledPrDto.prevStatus` — this is the exact approval stage the PR will be restored to.

---

### `components/cancellation/CancelSubTab.tsx`

**Empty state (before PR selected):**
```
🔍 No PR selected for cancellation
   Click Find PR (F3) in the toolbar to select a PR eligible for cancellation.
```

**After PR selected — all sections shown:**

```
[del-banner — red #FCEBEB background]
  Cancel mode — PR-XXXXX · Enter a cancellation reason and click Cancel PR to proceed.
  Sets CANCELFLAG = 'Y' on PO_PRH and PRSTATUS = 'X' on all PO_PRL lines.

[PRHeaderV1 view mode — 6-column field grid (disabled)]
  PR Date | Department | Section | Requested By | Requisition Type | Reference No.
  PR No tag (mono blue font, top-right)
  Created By label (top-right)
  PR Date badge (calendar icon, top-left)

[Reason Strip — compact bar between header and items]
  Label: "Cancellation Reason *"
  Textarea: min-height 48px, max-height 72px, maxLength=200
            Alphanumeric only (ToAlphaNumber equivalent validation)
            Red border on focus, red border + bg #fff9f9 on invalid
  Char count: "N / 200" right-aligned below textarea
  Error: "⚠ Cancellation reason is required." — shown red on empty submit attempt

[PRLineItemsTable — view/read-only mode]
  Columns (from PrForCancellationLineDto):
    # | Item Id | Item Name | Unit | Qty Required | Qty Approved | Qty Ordered | Qty Received |
    Current Stock | Rate | ₹ Approx. Value | Required Date | Machine | Place Of Issue | Remarks
  Qty: 3 dp | Rate: 4 dp | Value: 2 dp

[KPI Strip — PRKPIStrip]
  Approval stage dots: Requested → L1 Approved → L2 Approved → Final
  KPI Cards: Total Lines (blue) | Total Qty (mono) | Approx. Budget (amber) | Days Open (color-coded)
  Days Open: <5 days = green | 5–14 days = amber | >14 days = red
```

---

### `components/cancellation/UndoSubTab.tsx`

**Empty state:**
```
↩ No cancelled PR selected
  Click Find Cancelled PR (F3) in the toolbar.
  Only cancelled PRs within FY 2025–26 are eligible for undo.
```

**After PR selected:**

```
[del-banner — amber #FAEEDA background, border #fcd34d, text #BA7517]
  Undo mode — PR-XXXXX · Click Undo Cancellation to restore this PR.
  Clears CANCELFLAG on PO_PRH. Lines restored to pre-cancel approval status. Current FY only.

[View header — amber styling — 4-column field grid]
  PR Date | Cancelled On (red text) | Department | Lines Restore To (coloured badge)
  PR No tag (amber/ochre bg `#fef3c7`, text `#92400e`, border `#fcd34d`)
  "Cancelled · Current FY only" pill badge (amber, top-left)
  "Requested by [name]" label (top-right)

[Cancellation Detail Card]
  Section: "Original Cancellation Reason"
    italic reason box (grey bg #F5F5F3, border #E2E2E2)
  Section: "Line Status After Undo"
    (restored to previous status — exact pre_cancel_status badge)
  Info box (blue #e6f4ff):
    "Undo clears CANCELFLAG on PO_PRH and restores PO_PRL.PRSTATUS to its pre-cancellation value
     (BR-UNDO-01). Inside a single BeginTransaction. Restricted to current FY 2025–26."
```

---

### `pages/PrCancellationPage.tsx`

```
<PRDocBand>
  Breadcrumb: Purchase Order › PR Cancellation
  Right: "Processing Date" / {selectedPRNo} (switches after PR selected)

<Toolbar — changes by active sub-tab>
  Cancel tab:
    [🔍 Find PR to Cancel F3] [─]
    [🚫 Cancel PR Ctrl+S] (disabled/opacity until PR selected) [─]
    [🖨 Print Ctrl+P] (disabled — no print logic) |
    [✕ Cancel Alt+X]

  Undo tab:
    [🔍 Find Cancelled PR F3] [─]
    [↩ Undo Cancellation Ctrl+S] (disabled until PR selected) [─]
    [🖨 Print Ctrl+P] (disabled) |
    [✕ Cancel Alt+X]

<Sub-tabs>   🚫 Cancel PR  |  ↩ Undo Cancellation

<Sub-tab bodies: CancelSubTab | UndoSubTab>

<CancelPickerModal />
<UndoPickerModal />
```

**Behaviour:**
- On mount: load `cancellableList` (auto-open cancel modal if list is non-empty, matching VB6 Form_Load ScopeLookup)
- Switching to Undo tab with no selection: auto-open undo modal
- `F3` → open picker for active sub-tab
- `Ctrl+S` → Cancel PR or Undo Cancellation per active sub-tab
- `Alt+X` → `reset()`
- `Escape` → close open modals / confirm dialogs

---

## PHASE 12 — Frontend: Routing

**File:** `Development/spinrise-web/src/App.tsx`

```typescript
const PrForeclosurePage  = lazy(() => import('./features/pr/pages/PrForeclosurePage'));
const PrCancellationPage = lazy(() => import('./features/pr/pages/PrCancellationPage'));

// Inside router:
<Route path="/purchase-requisition/foreclosure"  element={<PrForeclosurePage />} />
<Route path="/purchase-requisition/cancellation" element={<PrCancellationPage />} />
```

---

## PHASE 13 — Sidebar Navigation

Ensure sidebar "Purchase Order" group includes (matching HTML prototype nav order):

```
📋 Purchase Requisition       → /purchase-requisition
⚡ PR Foreclosure Entry       → /purchase-requisition/foreclosure
🚫 PR Cancellation            → /purchase-requisition/cancellation
✏️ PR Amendment               → /purchase-requisition/amendment
✅ PR First Level Approval    → /purchase-requisition/first-approval
```

---

## PHASE 14 — Testing

### Backend unit tests — `Spinrise.Tests`

**PrForeclosureServiceTests.cs:**
- `GetOpenLines_ReturnsAllLines_WhenNoPrNoFilter`
- `GetOpenLines_ReturnsFilteredLines_WhenPrNoFilterProvided`
- `SaveForeclosure_ThrowsValidation_WhenNoLinesProvided`
- `SaveForeclosure_ReturnsCount_WhenLinesSelected`
- `SaveForeclosure_WritesAuditToLogDetPO_PerRow`

**PrCancellationServiceTests.cs:**
- `GetCancellablePRs_ExcludesAlreadyCancelledPRs`
- `GetCancellablePRs_ExcludesEnquiredPRs`
- `GetCancellablePRs_ExcludesPRsWithPOORDRecord` ← OI-02-F2 rule
- `GetPRForCancellation_ReturnsHeaderAndLines`
- `CancelPR_ThrowsValidation_WhenReasonEmpty`
- `CancelPR_ThrowsValidation_WhenReasonNotAlphanumeric`
- `CancelPR_SavesPreCancelStatus_OnPOPRH` ← BR-UNDO-01
- `CancelPR_SetsPRSTATUSX_OnAllLines`
- `GetCancelledForUndo_ReturnsOnlyCurrentFY`
- `GetCancelledForUndo_ReturnsPrevStatusFromPreCancelStatus` ← BR-UNDO-01
- `UndoCancellation_RestoresToPreCancelStatus_NotNull` ← BR-UNDO-01
- `UndoCancellation_ThrowsError_WhenPRNotCancelled`

**Coverage target: 80%+ on services and repositories.**

---

## File Creation Checklist

### Database
- [ ] DB Migration SQL executed (after CEO sign-off): `pre_cancel_status`, `row_version` x2
- [ ] `ksp_PR_GetOpenForForeclosure.sql` (cross-FY, no yfdate filter)
- [ ] `ksp_PR_GetCancellablePRs.sql` (with APPFLG + PO_ORD check + @yfdate/@yldate)
- [ ] `ksp_PR_GetCancelledPRsForUndo.sql` (reads `pre_cancel_status` for PrevStatus)
- [ ] `merged.sql` — appended with all 3 SPs

### Backend Shared
- [ ] `StoredProcedures.cs` — 3 new constants (sp_ prefix)

### DTOs (Application)
- [ ] `PrForeclosureLineDto.cs` (includes depCode, prDate for audit/WHERE)
- [ ] `PrForeclosureSaveRequestDto.cs`
- [ ] `PrForeclosureLineKeyDto.cs` (prDate, itemCode, depCode, balance)
- [ ] `PrForCancellationDetailDto.cs`
- [ ] `PrForCancellationHeaderDto.cs` (includes depCode)
- [ ] `PrForCancellationLineDto.cs` (full VB6 column set)
- [ ] `PrCancellablePrDto.cs` (includes depCode, prDate)
- [ ] `PrCancelRequestDto.cs` (alphanumeric validation, depCode, prDate)
- [ ] `PrCancelledPrDto.cs` (prevStatus = pre_cancel_status)
- [ ] `PrUndoRequestDto.cs` (prDate, depCode)

### Interfaces (Application)
- [ ] `IPrForeclosureRepository.cs` (divcode param)
- [ ] `IPrForeclosureService.cs`
- [ ] `IPrCancellationRepository.cs` (divcode, yfdate, yldate params)
- [ ] `IPrCancellationService.cs`

### Implementations
- [ ] `PrForeclosureRepository.cs` — inline Dapper save (per-row loop, BeginTran)
- [ ] `PrForeclosureService.cs`
- [ ] `PrCancellationRepository.cs` — BR-UNDO-01 save+restore logic, inline Dapper
- [ ] `PrCancellationService.cs`

### API
- [ ] `PrForeclosureController.cs` (try-catch per CD-01-F1 spec)
- [ ] `PrCancellationController.cs` (try-catch per CD-03-F2 spec, all 5 methods)
- [ ] `Program.cs` — 4 DI registrations

### Frontend
- [ ] `types.ts` — 8 new interfaces (with depCode, prDate keys throughout)
- [ ] `api/prForeclosureApi.ts`
- [ ] `api/prCancellationApi.ts`
- [ ] `hooks/usePrForeclosure.ts`
- [ ] `hooks/usePrCancellation.ts`
- [ ] `components/foreclosure/PrForeclosureGrid.tsx`
- [ ] `components/cancellation/CancelPickerModal.tsx`
- [ ] `components/cancellation/UndoPickerModal.tsx`
- [ ] `components/cancellation/CancelSubTab.tsx`
- [ ] `components/cancellation/UndoSubTab.tsx`
- [ ] `pages/PrForeclosurePage.tsx`
- [ ] `pages/PrCancellationPage.tsx`
- [ ] `App.tsx` — 2 lazy routes + sidebar entries

### Tests
- [ ] `PrForeclosureServiceTests.cs` (5 tests)
- [ ] `PrCancellationServiceTests.cs` (12 tests)

---

## Business Rules Reference (FSD v1.1 Authoritative)

| Rule | FSD Source | Impact |
|---|---|---|
| **Foreclosure is irreversible** — no undo SP, no undo UI | OI-02-F1 CLOSED | No "Undo Foreclosure" anywhere in UI or backend |
| **Foreclosure cross-FY scope** — no yfdate/yldate filter | OI-01-F1 CLOSED by Sasi | ksp_PR_GetOpenForForeclosure has NO date range filter |
| **Foreclosure filter**: FClosed≠'Y', cancelflag='N', balance>0, **qtyord−qtyrec≥0** | Billdisplay VB6 query | Both balance conditions must be in SP WHERE |
| **Foreclosure sets**: PRSTATUS='Z', FClosed='Y', FCloseddt=GETDATE() per row | VB6 Save logic | All 3 columns updated per row in transaction |
| **Foreclosure WHERE per row**: divcode+prno+prdate+prsno+itemcode | VB6 FIX G4-1 | prdate and itemcode are part of the composite key |
| **Foreclosure depcode lookup**: SELECT In_dep per row, release after each row | VB6 FIX L2 (CD-03-F1) | No open cursors held in loops |
| **LogDet_PO quantity**: balance value of the foreclosed line | FSD LogDet_PO columns | `quantity=@balance` in INSERT |
| **SCCCODE column** in foreclosure grid — stores machine section code | CEO direction 26 May 2026 | Via mm_MACmas.SCCCODE LEFT JOIN MacFlag='M' |
| **BR-UNDO-01**: Undo restores `pre_cancel_status` (NOT NULL) | CEO confirmed 26 May 2026 | Schema: PO_PRH.pre_cancel_status; Capture on Cancel, Restore on Undo |
| **Cancel eligibility**: cancelflag IS NULL, APPFLG≠'Y', QTYORD=0, not in PO_ENQL, **not in PO_ORD**, within FY | OI-02-F2 CLOSED by CEO; OI-03-F2 CLOSED | 5 filter conditions in ksp_PR_GetCancellablePRs |
| **Cancel: PO_ORD block message**: "A Purchase Order has been raised against this PR. Cancel the PO first." | OI-02-F2 CLOSED | HTTP 422 + specific message from API |
| **Cancel reason**: mandatory, alphanumeric only, max 200 chars, stored UPPERCASE | FSD cancltxt spec | ToAlphaNumber equivalent + UPPER() in UPDATE |
| **Cancel sets**: CANCELFLAG='Y', CANCELDT=GETDATE(), CANREASON=UPPER() on PO_PRH | VB6 Command1_Click | WHERE: divcode+prno+prdate+depcode |
| **Cancel sets**: PRSTATUS='X' on ALL PO_PRL lines | VB6 Command1_Click | WHERE: divcode+prno+prdate |
| **LogDet_PO Trans_Mod**: 'ADD' for cancel, 'DELETE' for undo | VB6 audit entries | Must match exactly — no variations |
| **Undo restricted to current FY** | FSD undoLookup + undo modal | Applied in ksp_PR_GetCancelledPRsForUndo, enforced at SP level |
| **Undo clears**: CANCELFLAG=NULL, CANCELDT=NULL, CANREASON=NULL, pre_cancel_status=NULL | VB6 undo logic + BR-UNDO-01 | All 4 columns cleared on PO_PRH |
| **Undo restores PO_PRL.PRSTATUS** from pre_cancel_status (not NULL) | BR-UNDO-01 CEO 26 May 2026 | Read pre_cancel_status before clearing it |
| **All transactions**: BeginTran → DML → INSERT LogDet_PO → Commit; Rollback on any exception | G6 PASS both forms | Dapper `BeginTransaction` wrapping all DML + LogDet INSERT |
| **No print logic** — QuestPDF class not required | OI-04-F1, OI-04-F2 CLOSED | Print button exists in UI as disabled only — no SP, no controller action |
| **divcode scope**: all queries and updates | FSD architecture standards | Pass from session context at service level |
| **No SPs for save/cancel/undo** — inline Dapper only | FSD Key Stored Procedures section | Aligns with "no VB6 SPs" — only 3 new lookup SPs |
| Qty=3dp, Rate=4dp, Value=2dp | CLAUDE.md quality standards | Applied in frontend number formatting |
| Title Case labels throughout UI | CLAUDE.md quality standards | No ALL CAPS labels |

---

## Open Items to Track

| OI | Description | Status | Owner |
|---|---|---|---|
| OI-05-F2 | IST to confirm whether any active customer has raised a support call regarding PR cancellation restrictions | OPEN | Palanivel (TL-IST) |
| OI-06 | CEO Working Session not held before Stage 1 — confirm waived or schedule before sprint | OPEN | CEO T. Mani / Sasi |

---

## Deployment Checklist

```
DEPLOYMENT CHECKLIST — M01 PR Foreclosure & Cancellation — 28 May 2026
──────────────────────────────────────────────────────────────────────
[ ] CEO countersignature received (Stage 4 gate)
[ ] DB Migration executed (pre_cancel_status, row_version x2 ALTERs)
[ ] All 3 SPs verified on test DB (ksp_PR_ prefix, correct params)
[ ] merged.sql updated with DB migration + all 3 new SPs
[ ] APIs validated: 2 endpoints foreclosure, 5 endpoints cancellation
[ ] Foreclosure: cross-FY confirmed (no date filter in SP or UI)
[ ] Foreclosure: irreversibility confirmed (no undo button, no undo API)
[ ] Cancellation: PO_ORD block message fires correctly
[ ] Cancellation: reason alphanumeric validation fires on special chars
[ ] Cancellation: reason mandatory validation fires on empty submit
[ ] BR-UNDO-01: cancel saves pre_cancel_status to PO_PRH
[ ] BR-UNDO-01: undo restores PO_PRL.PRSTATUS from pre_cancel_status
[ ] UI tested against HTML prototypes (Foreclosure + Cancellation + Undo)
[ ] Unit tests pass — dotnet test (5 foreclosure + 12 cancellation)
[ ] Frontend: npm run build (no TS errors, no 'any' usage)
[ ] Stop IIS app pool before backend publish
[ ] Deploy: 172.16.16.40:5001 (API) / 172.16.16.40:3000 (UI)
[ ] Execute merged.sql in SSMS against SpinRiseSaranya
──────────────────────────────────────────────────────────────────────
```
