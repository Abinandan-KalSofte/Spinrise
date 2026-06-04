# SPINRISE — FULLSTACK MODULE DEVELOPMENT PROMPT
## Template Version: 1.0 | 26 May 2026
## Based on: Sprint 1 M01 Audit — spinrise_dev_os_v1.md
## Input: Approved UI/UX Design (PROMPT_01 output) + CEO-countersigned FSD

---

> **CRITICAL:** This prompt executes code generation only after ALL gates are passed.
> Mandatory sequence: Gap Register closed → DB migration → API contract → Backend → Frontend → QuestPDF → Stage 1
> Skipping any step is a process violation.

---

# ROLE

Act as Senior Fullstack Developer for SPINRISE ERP.

You are implementing a SPINRISE module from:
1. An approved UI/UX design specification (output of PROMPT_01)
2. A CEO-countersigned FSD
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

# INPUTS — FILL ALL BEFORE RUNNING

```
MODULE:                
SUBMODULE:             
FSD VERSION:           
UIUX DESIGN REF:       
BLUEPRINT:             
VB6 SOURCE FORM:       
VB6 LINE COUNT:        
DB NAME:               [SpinRiseSaranya for M01 / JAT for M02 — never blank]
API BASE URL:          [http://172.16.16.40:5001/api/]
FRONTEND URL:          [http://172.16.16.40:3000/]
JIRA EPIC:             
DEVELOPER:             
SPRINT:                
IMPLEMENTATION DATE:   
```

> **COMBINED FSD NOTE:** If the FSD covers more than one VB6 form (e.g. FrmPRForeclosure + Indentcancellation in a single v1.1 document), run PROMPT_02 separately for each form. Share the DB migration step across both runs — execute the migration only once. Fill in a separate INPUTS block per form.

---

# GATE 0 — PRE-DEVELOPMENT VERIFICATION

**Every item must be CONFIRMED before any code is generated.**
If any item is BLOCKED or UNKNOWN: stop. Report to Abinandan. Do not proceed.

```
GATE 0 CHECKLIST

FSD:
  [ ] FSD version: v___ CEO-countersigned: ___-May-2026 CONFIRMED
  [ ] CEO countersignature date confirmed on document (not just "Stage 4 submitted" or "awaited")
  [ ] FSD is current version (no later countersigned version exists)
  [ ] All IST Q resolutions for this module reviewed and applied
  [ ] FSD/Blueprint conflicts: all resolved (Blueprint wins) — list resolved items
  [ ] OI-06 CEO Working Session gate: waived by CEO or Working Session held
      (Required only if FSD notes CEO Working Session was not held before Stage 1 writing)

UI/UX Design:
  [ ] UI/UX design spec approved (sign-off by: _________)
  [ ] All gaps in Gap Register = CLOSED or NOT-BLOCKING
  [ ] No Critical gap open

Domain Gaps:
  [ ] Gap register from PROMPT_01: all Critical gaps CLOSED
  [ ] All High gaps: owner confirmed + resolution received
  [ ] RATE_JUSTIFICATION mandatory/optional: confirmed as [mandatory/optional]
  [ ] Any "code and confirm later" gap: DOES NOT EXIST (hard rule)

DB/Backend:
  [ ] All SP names confirmed in DB (not assumed)
  [ ] All new DB columns listed with type, nullable, default
  [ ] Migration script path confirmed: D:\SpinriseV2\Development\DB\Migrations\

VB6 Migration:
  [ ] Stage 0 sign-off received: ___-May-2026 by [Sasi/Mohan Babu]
  [ ] VB6 Migration Assumption Checklist complete (Step 1 below)

GATE 0 APPROVED BY: _________________ DATE: _________
```

---

# STEP 1 — VB6 MIGRATION ASSUMPTION CHECKLIST

Before reading a single line of VB6 source, complete this checklist.
For every item checked YES: document the VB6 pattern and the SPINRISE replacement.

| # | VB6 Pattern | Present? | SPINRISE Replacement | Risk if missed |
|---|---|---|---|---|
| 1 | MAX(n)+1 auto-number | Y/N | DB SEQUENCE | Race condition — duplicate keys |
| 2 | Delete-all-lines Modify-save | Y/N | Delta-update (update changed, insert new, soft-delete removed) | Destroys partial approval data |
| 3 | Boolean flag with VB6 True/False | Y/N | Validate each one — `if (!Records)` pattern (CD-01) | Grid wiped on successful load |
| 4 | Hardcoded CustID / DivCode / UserID | Y/N | Parameterized — @param always | Wrong data for other tenants |
| 5 | String concatenation in SQL | Y/N | Parameterized Dapper queries | SQL injection |
| 6 | CommitTrans boundary | Y/N | Verify all DML inside transaction | Partial saves, orphaned data |
| 7 | Secondary update outside CommitTrans | Y/N | Move inside transaction or document the risk | PO_PAH-style data link lost |
| 8 | App-terminating on modal condition | Y/N | Dismissable modal (KSP_INDEDNT_CHECK precedent) | App crash in browser context |
| 9 | ig_param reference | Y/N | Confirm: not applicable to M01 | Unused reference, dead code |
| 10 | prstatus='C' usage | Y/N | prstatus='C' = RECEIVED. Cancelled = cancelflag='Y'. FClosed='Y' = Foreclosed (separate flag on PO_PRL). Never conflate these three statuses | Wrong status display |
| 11 | EmpCommon flag branch | Y/N | PO_Para.EmpMasterComm='Y' = company-wide lookup | Employee lookup returns wrong scope |
| 12 | Form-level global variables | Y/N | Map to React state / Zustand store / API params | State bleed between sessions |
| 13 | F1 key handler | Y/N | Remove — browser-reserved. Replace with Alt+↓ / Ctrl+Space | Breaks in all browsers |
| 14 | Single-instance form assumption | Y/N | Design for concurrent users | Race conditions, stale data |
| 15 | FClosed='Y' flag (Foreclosure) | Y/N | FClosed='Y' on PO_PRL = Foreclosed (not Cancelled). FCloseddt = foreclosure datetime. No undo path exists in VB6 — SPINRISE must not add one unless CEO directs | Wrong status, phantom undo |
| 16 | CANCELFLAG vs APPFLG (Cancellation) | Y/N | CANCELFLAG='Y' = Cancelled (PO_PRH + PO_PRL). APPFLG='Y' = Approved. A PR with APPFLG='Y' cannot be cancelled — check this guard explicitly before any cancel operation | Cancel applied to approved PR |
| 17 | rowversion concurrency column | Y/N | New ROWVERSION column on PO_APRH / PO_PRH / PO_PRL. Read on load, pass in save request, validate in SP (optimistic concurrency). Special SQL Server type — cannot use standard column default pattern | Lost updates on concurrent saves |

---

# STEP 2 — DB MIGRATION SCRIPT

**Write migration script BEFORE any SP code or API code.**
Migration must be reviewed and executed on DB before backend development begins.

```sql
-- ============================================================
-- SPINRISE MIGRATION — [Module] [Submodule]
-- FSD: v[X.X] CEO-countersigned [date]
-- Author: [developer]
-- Date: [date]
-- DB: [SpinRiseSaranya / JAT]
-- ============================================================

-- New columns (add only if not exists):
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = '[table]' AND COLUMN_NAME = '[column]')
BEGIN
    ALTER TABLE [table] ADD [column] [type] [nullable] [default];
END

-- New sequences (replace MAX+1 patterns):
IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE name = '[sequence_name]')
BEGIN
    CREATE SEQUENCE [sequence_name] START WITH [n] INCREMENT BY 1;
END

-- New indexes:
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = '[index_name]')
BEGIN
    CREATE [UNIQUE] INDEX [index_name] ON [table] ([columns]);
END

-- rowversion concurrency column (SPECIAL — cannot use column default, no value supplied):
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = '[table]' AND COLUMN_NAME = 'rowversion')
BEGIN
    ALTER TABLE [table] ADD [rowversion] ROWVERSION;
    -- rowversion auto-populates on every INSERT/UPDATE — no DEFAULT clause
END

-- CONSOLIDATION RULE:
-- If this migration touches PO_PRH or PO_PRL, consolidate with
-- existing M01 PR Form migration scripts. Do NOT execute independently.
-- Verify with DBA before running on live database.

-- Verification queries (run after migration):
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = '[table]'
ORDER BY ORDINAL_POSITION;
```

New columns required (from FSD + UI/UX design):
| Column | Table | Type | Nullable | Default | Reason |
|---|---|---|---|---|---|
| RATE_SOURCE | PO_PRL | varchar(10) | Y | 'LPO' | FSD v2.3 — rate selection |
| RATE_JUSTIFICATION | PO_PRL | varchar(200) | Y | NULL | FSD v2.3 — manual rate justification |
| [column] | [table] | [type] | [Y/N] | [default] | [FSD section] |

---

# STEP 3 — API CONTRACT

**Write full API contract BEFORE backend implementation.**
Developer and architect must agree on contract before a single controller line is written.

## Endpoint: [METHOD] /api/[path]

### Request

```typescript
interface [RequestType] {
  // Header fields
  [fieldName]: [type];           // FSD Section 3 — [rule]
  [fieldName]?: [type];          // Optional — [condition]

  // Line items (if applicable)
  lineItems: Array<{
    [fieldName]: [type];
    [fieldName]?: [type];
  }>;
}
```

### Response — Success

```typescript
// HTTP [201 for POST-create / 200 for GET, PUT, DELETE]
interface [ResponseType] {
  [fieldName]: [type];
  lineItems?: Array<{...}>;
}
```

### Response — Validation Error

```typescript
// HTTP 422
interface ValidationErrorResponse {
  errors: Array<{
    field: string;     // exact field name from request
    code: string;      // e.g., "REQUIRED", "FY_GUARD", "DUPLICATE_ITEM"
    message: string;   // user-readable, matches FSD error text
  }>;
}
```

### Response — Business Rule Error

```typescript
// HTTP 400
interface BusinessErrorResponse {
  code: string;        // e.g., "PO_EXISTS", "ALREADY_CANCELLED"
  message: string;     // user-readable
  data?: object;       // additional context (e.g., PO number for PO_EXISTS)
}
```

### Status-Update Endpoint Pattern (Foreclosure, Cancellation — no new resource created)

```typescript
// PATCH → 200 for status-update operations (never 201)
// Use when: updating existing record status flags, no new document number generated

// GET /api/[module]/eligible — returns records available for action (picker step)
interface EligibleResponse {
  items: Array<{
    prNo: string;
    prDate: string;
    // ... display fields only — no mutation here
  }>;
}

// PATCH /api/[module]/[action] — applies action to selected records
interface StatusUpdateRequest {
  divCode: string;
  items: Array<{ prNo: string; prDate: string; prsNo?: number }>;
}
// Response: HTTP 200 — array of updated record IDs + new status
// Response: HTTP 400 — blocking guard code (e.g., "PO_ORDER_EXISTS", "ALREADY_APPROVED")
```

> **Lookup-then-act rule:** Define two endpoints — `GET /eligible` (returns selectable records) and `PATCH /[action]` (applies action to selected IDs). Never combine selection query and mutation in one call.

### Decimal Precision (non-negotiable project constants):
- Quantity: 3 decimal places (always — API response and DB)
- Rate: 4 decimal places (always — API response and DB)
- Value/Cost: 2 decimal places (always — API response and DB)

---

# STEP 4 — STORED PROCEDURE IMPLEMENTATION

Write SPs AFTER migration script. Reference confirmed SP name from DB.

```sql
-- ============================================================
-- SP: [confirmed SP name from DB]
-- Purpose: [description]
-- FSD Section: [5.X]
-- Author: [developer] | Date: [date]
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[ksp_xxx]
    @Param1     [type],
    @Param2     [type],
    -- ... all params
    @Result     int OUTPUT        -- 0=success, 1=validation error, 2=business error
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Validation (before any DML)
        -- FY Guard (PP_Year table — not calendar year):
        IF NOT EXISTS (
            SELECT 1 FROM PP_Year
            WHERE yfdate <= @PRDate AND yldate >= @PRDate AND status = 'O'
        )
        BEGIN
            SET @Result = 1;
            RAISERROR('PR Date is outside the open financial year.', 16, 1);
            RETURN;
        END

        -- 2. Business rules
        -- [rule from FSD Section 5]

        -- 3. Main DML — ALL inside transaction
        -- [INSERT / UPDATE / DELETE]

        -- 4. Audit record (LogDet_po or equivalent)
        INSERT INTO LogDet_po ([fields]) VALUES ([values]);

        -- 5. SEQUENCE-based ID (never MAX+1)
        DECLARE @NewID int = NEXT VALUE FOR [sequence_name];

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

SP rules:
- All inputs are parameters — no string concatenation, no hardcoded values
- SEQUENCE for all auto-increment — never MAX+1
- All DML inside BEGIN TRANSACTION / COMMIT TRANSACTION
- No DML between COMMIT and END (PO_PAH pattern — move inside transaction)
- Audit record written inside transaction
- OUTPUT parameter for result code (not exceptions for business rules)
- No SELECT * in any SP

**FY Guard — module-specific:**
```sql
-- FY Guard APPLICABLE (standard — most modules):
IF NOT EXISTS (SELECT 1 FROM PP_Year WHERE yfdate <= @Date AND yldate >= @Date AND status = 'O')
    SET @Result = 1; RAISERROR(...); RETURN;

-- FY Guard NOT APPLICABLE (document in SP header comment if skipped):
-- FY Guard: NOT REQUIRED — [reason from FSD OI resolution]
-- Example: Foreclosure operates across all financial years by design
--          (FSD OI-01-F1 closed by Sasi 20-May-2026)
```

**SP naming rule:** Use SP names EXACTLY as confirmed by Sasi in the FSD review chain.
Do NOT apply the `ksp_` prefix to SPs that already have a confirmed name (e.g. `usp_GetNextAmendNo`, `sp_PR_GetOpenForForeclosure`). The FSD confirmed name is the authoritative name — check Section 6 DB Migration table.

**Lookup SP pattern** (read-only, returns result set for user selection — no @Result OUTPUT needed):
```sql
CREATE OR ALTER PROCEDURE [dbo].[sp_PR_GetEligibleRecords]
    @DivCode    varchar(10),
    @YFDate     datetime = NULL,   -- NULL when no FY scope required
    @YLDate     datetime = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT [explicit column list]
    FROM   [tables with JOINs]
    WHERE  [eligibility conditions per FSD]
    ORDER BY [sort per FSD];
END
```

---

# STEP 5 — BACKEND IMPLEMENTATION (ASP.NET Core 8 / C#)

### Controller Pattern

```csharp
// [Module][Submodule]Controller.cs
// FSD: v[X.X] | UX Design: [ref]

[ApiController]
[Route("api/[controller]")]
public class [Name]Controller : ControllerBase
{
    // POST → 201 for create operations (never 200)
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateRequest request)
    {
        // 1. Model validation (FluentValidation or DataAnnotations)
        if (!ModelState.IsValid)
            return UnprocessableEntity(ModelState);

        // 2. Service call
        var result = await _service.CreateAsync(request);

        // 3. Response
        return result.IsSuccess
            ? StatusCode(201, result.Data)
            : BadRequest(result.Error);
    }

    // PUT → 200 for updates
    // DELETE → 200 with deleted record ID
    // GET → 200 with data, 404 if not found
}
```

### Service Pattern

```csharp
public class [Name]Service
{
    // Transaction: ALL DB operations inside one unit of work
    // Dapper: parameterized queries only
    // Decimal precision enforced in DTO mapping:
    //   qty.ToString("F3") for Quantity
    //   rate.ToString("F4") for Rate
    //   value.ToString("F2") for Value/Cost
}
```

### Validation Rules (server-side — mandatory even with client-side)

For each validation from FSD Section 4:

| Rule | Server-side implementation | HTTP code on fail |
|---|---|---|
| [field] mandatory | Check null/empty in service layer | 422 |
| FY guard | Query PP_Year table in SP | 422 |
| Duplicate item | Unique check in SP before insert | 422 |
| [rule] | [implementation] | [code] |

---

# STEP 6 — FRONTEND IMPLEMENTATION (React 18 + TypeScript)

### File Structure

```
src/
├── pages/
│   └── [Module]/
│       └── [Submodule]/
│           ├── [SubmodulePage].tsx       ← page component
│           ├── [SubmodulePage].types.ts  ← TypeScript interfaces
│           ├── [SubmodulePage].store.ts  ← Zustand store
│           └── components/
│               ├── [Header]Form.tsx
│               ├── [Line]Grid.tsx
│               └── [Lookup]Modal.tsx
└── api/
    └── [submodule].api.ts               ← API calls (axios)
```

### Zustand Store Pattern

```typescript
// [SubmodulePage].store.ts
interface [Submodule]State {
  mode: 'add' | 'modify' | 'delete' | 'find' | 'view';
  record: [RecordType] | null;
  lineItems: [LineItemType][];
  loading: boolean;
  errors: Record<string, string>;   // field-level validation errors

  // Actions
  setMode: (mode: Mode) => void;
  setRecord: (record: [RecordType]) => void;
  addLineItem: (item: [LineItemType]) => void;
  updateLineItem: (index: number, item: Partial<[LineItemType]>) => void;
  removeLineItem: (index: number) => void;  // immediate — no ghost records
  clearErrors: () => void;
}
```

### State Management Rules (non-negotiable)

```typescript
// Add: append with server-returned ID (never re-fetch all)
const handleAddSuccess = (serverResponse: CreateResponse) => {
  addToList(serverResponse);          // append
  setMode('view');
};

// Modify: update specific record (surgical — not full reload)
const handleModifySuccess = (serverResponse: UpdateResponse) => {
  updateInList(serverResponse.id, serverResponse);  // update one
  setMode('view');
};

// Delete: remove immediately on 200 (no ghost record)
const handleDeleteSuccess = (deletedId: number) => {
  removeFromList(deletedId);          // remove immediately
  setMode('view');
};

// Error: rollback state to pre-mutation
const handleError = () => {
  restorePreMutationState();          // rollback
};
```

### Toolbar Component

```typescript
// Toolbar renders all buttons — disabled state changes, never hidden
// toolbar state is derived from current mode
const toolbarConfig = {
  add:    { add: false, modify: true,  delete: true,  find: true,  save: false, cancel: false, print: false },
  modify: { add: true,  modify: false, delete: true,  find: true,  save: true,  cancel: true,  print: false },
  delete: { add: true,  modify: true,  delete: false, find: false, save: false, cancel: false, print: false },
  find:   { add: true,  modify: true,  delete: false, find: false, save: false, cancel: false, print: true  },
  view:   { add: true,  modify: true,  delete: true,  find: true,  save: false, cancel: false, print: true  },
};
// false = disabled | true = enabled
// Find DISABLED in delete mode — CR-PR-01 permanent fix
```

### Validation Pattern

```typescript
// Focus-out validation (text inputs, number inputs only):
const handleBlur = (fieldName: string, value: string) => {
  const error = validateField(fieldName, value);
  if (error) {
    setFieldError(fieldName, error);        // red border + inline message
  } else {
    clearFieldError(fieldName);
  }
};

// Ant Design Select — validate on Save only (HF-19a — tab-out unreliable):
// Do NOT attach onBlur to any Select component

// Form-level save validation:
const handleSave = async () => {
  const errors = validateAll(formState);
  if (Object.keys(errors).length > 0) {
    setErrors(errors);                      // show all inline errors
    return;                                 // do not submit
  }
  // submit...
};
```

### Decimal Precision (project constants — reference, never hardcode)

```typescript
// src/constants/precision.ts
export const DECIMAL_PRECISION = {
  QUANTITY: 3,    // Qty fields — always 3dp
  RATE: 4,        // Rate fields — always 4dp
  VALUE: 2,       // Value, Cost fields — always 2dp
} as const;

// Usage in InputNumber:
<InputNumber precision={DECIMAL_PRECISION.QUANTITY} ... />

// Usage in display:
value.toFixed(DECIMAL_PRECISION.VALUE)
```

### Blueprint Design Tokens (reference, never raw hex)

```typescript
// src/constants/tokens.ts
export const COLOR = {
  PRIMARY_BLUE:  'var(--color-primary-blue)',   // #185FA5
  DARK_BLUE:     'var(--color-dark-blue)',       // #0C447C
  BLUE_100:      'var(--color-blue-100)',        // #E6F1FB — selected row
  BACKGROUND:    'var(--color-background)',      // #F5F5F3
  BORDER:        'var(--color-border)',          // #E2E2E2
  TEXT_900:      'var(--color-text-900)',        // #1A1A1A
  SUCCESS:       'var(--color-success)',         // #3B6D11
  WARNING:       'var(--color-warning)',         // #BA7517
  ERROR:         'var(--color-error)',           // #A32D2D
  PURPLE:        'var(--color-purple)',          // #722ED1
} as const;

// NO component may use a raw hex string. Always reference COLOR.xxx
```

### Toolbar — Status-Update Module Override

```typescript
// For status-update modules (Foreclosure, Cancellation) that do NOT use Add/Modify/Delete/Find:
// Replace standard toolbarConfig with a module-specific action bar.
// Standard 5-mode config does NOT apply to these modules.

const statusUpdateActionBar = {
  // load:     always enabled — reloads eligible records
  // act:      enabled only when >= 1 row is selected in the grid
  // cancel:   always enabled — clears selection / resets form
};

// Dual-action modules (e.g. Cancel + Undo in same form):
// Implement as a tab or toggle — one action visible at a time.
// Do NOT render both action grids simultaneously.
```

### Irreversible Action — Confirmation Modal (mandatory)

```typescript
// Required before any action that cannot be undone (Foreclosure is permanent):
Modal.confirm({
  title: 'Confirm [Action Name]',
  content: `[n] items selected. This action cannot be undone.`,
  okText: 'Confirm',
  cancelText: 'Cancel',
  onOk: () => submitAction(),
});
// Never submit directly — always confirm first for irreversible operations.
```

### Multi-Select Checkbox Grid

```typescript
// For forms where user selects rows before acting (e.g. Foreclosure):
const colDefs: ColDef[] = [
  {
    checkboxSelection: true,
    headerCheckboxSelection: true,  // select-all
    width: 40,
    pinned: 'left',
  },
  // ... data columns
];
const gridOptions = {
  rowSelection: 'multiple',         // multi-select
  suppressRowClickSelection: true,  // checkbox only — no row-click select
  // ...
};
// Track selectedRows in component state; enable action button only when selectedRows.length > 0
```

### AG Grid Configuration

```typescript
// AG Grid Community only (no Enterprise features)
const gridOptions = {
  rowHeight: 32,                    // Blueprint spec — non-negotiable
  headerHeight: 36,
  suppressRowClickSelection: false,
  rowSelection: 'single',
  // Tab navigation:
  tabToNextCell: customTabOrder,    // implement Blueprint tab sequence
  // No Enterprise: rowGrouping, pivoting, server-side row model
};
```

---

# STEP 7 — QUESTPDF PRINT TEMPLATE (if applicable)

> **If no print output:** Mark this step NOT APPLICABLE and state the reason (e.g. "FSD Section 7 confirms no print output for this module"). Omitting this declaration is a process violation — the reviewer cannot distinguish intentional skip from accidental omission.
>
> Example: `STEP 7: NOT APPLICABLE — FSD v1.1 Section 7 confirms no print output for PR Foreclosure (OI-04-F1).`

**Complete field mapping table BEFORE writing QuestPDF code.**
Every FSD Section 3 field must appear in the mapping table.
Missing field = process violation.

### Field Mapping Table (mandatory — fill before coding)

| FSD Field | DB Column / API Field | Precision | Report Region | Position | Notes |
|---|---|---|---|---|---|
| PR Date | PO_PRH.prdate | DD/MM/YYYY | Header | Left | |
| PR Number | PO_PRH.prno | 6-digit padded | Header | Left | |
| ERP Username | PO_PRH.createdby | — | Header | Right | NOT session username |
| Requester Name | PR_EMP.ENAME | — | Header | Right | Separate from code |
| Department | PO_PRH.DEPCODE | — | Header | Left | |
| Print Date/Time | System.DateTime.Now | dd/MM/yyyy hh:mm tt | Footer | Left | 12-hour AM/PM — Footer not header (CEO 21 May) |
| Total Value | Sum(PO_PRL.value) | 2dp | Footer | Right | |
| Item Code | PO_PRL.itemcode | — | Grid | Col 1 | |
| Item Description | IN_ITEM.itemname | — | Grid | Col 2 | |
| Quantity | PO_PRL.qtyreq | 3dp | Grid | Col 3 | Right-aligned |
| Rate | PO_PRL.rate | 4dp | Grid | Col 4 | Right-aligned |
| Value | PO_PRL.value | 2dp | Grid | Col 5 | Right-aligned |
| Drawing No. | PO_PRL.drawno | — | Grid | Col 6 | Always include (Defect 28 fix) |
| Catalogue No. | PO_PRL.catno | — | Grid | Col 7 | Always include (Defect 28 fix) |
| [field] | [column] | [precision] | [region] | [position] | |

### JOIN filter requirement:

```csharp
// DEPCODE filter MANDATORY on all machine-related joins
// Prevents duplicate rows (Defect 19)
// SQL pattern:
WHERE PO_PRL.prno = @PRNo
  AND PO_PRL.prdate = @PRDate
  AND (MM_MACMAS.macno IS NULL OR MM_MACMAS.depcode = PO_PRH.DEPCODE)
```

### Multiple Report Variants (when a module has more than one template)

If a module generates different report layouts based on a condition (e.g. line count):
- Create a **separate field mapping table for each variant**
- Document the switching condition clearly
- Both variants must be tested in Stage 1 self-check

```csharp
// Example: Amendment compact vs full
IDocument report = lineItems.Count < 5
    ? new PrAmendmentReport(data)       // compact layout
    : new PrAmendmentFullReport(data);  // full layout
```

### Re-Print Control Pattern (when module logs print events)

```csharp
// On first print: insert to PO_PRINT_LOG, set REPRINT_FLG = false
// On re-print:   insert to PO_PRINT_LOG, set REPRINT_FLG = true
// Frontend: show "Reprint" label on button after first print
// DB table: PO_PRINT_LOG (divcode, documentno, documentdate, printed_by, printed_on, reprint_flag)
```

### QuestPDF structure:

```csharp
// [ReportName]Document.cs
public class [ReportName]Document : IDocument
{
    // Header section → all header fields from mapping table
    // Grid section → all line item columns from mapping table
    // Footer section → Print date (12-hr AM/PM) + Total Value 2dp
    // Footer is CEO-mandated position (21 May 2026 decision — non-negotiable)
}
```

---

# STEP 8 — STAGE 1 SELF-CHECK

Developer must complete before any IST submission. Attach results to IST email.

```
STAGE 1 SELF-CHECK — [Module] [Submodule] [Date]
Developer: [name] | CR Version: [version]

HAPPY PATH:
  [ ] Add new record — Save — record appears in list
  [ ] Modify existing record — Save — change reflected immediately
  [ ] Delete record — record removed immediately (no ghost)
  [ ] Print — all fields present, decimals correct, no duplicate rows
  [ ] Find — filter works correctly

MANDATORY FIELD VALIDATION:
  [ ] Each mandatory field: empty → correct error shown
  [ ] Each mandatory field: valid value → error cleared
  [ ] FY guard: date outside FY → blocked with message
  [ ] FY guard: date inside FY → accepted

DECIMAL PRECISION:
  [ ] Quantity fields: 3 decimal places displayed
  [ ] Rate fields: 4 decimal places displayed
  [ ] Value/Cost fields: 2 decimal places displayed
  [ ] Print template: all decimal precisions correct

TOOLBAR STATE:
  [ ] Add mode: correct buttons enabled/disabled
  [ ] Modify mode: correct buttons enabled/disabled
  [ ] Delete mode: correct buttons enabled/disabled (Find disabled)
  [ ] Find mode: correct buttons enabled/disabled
  [ ] View mode: correct buttons enabled/disabled

REACT STATE:
  [ ] After Add → new record in list with correct ID from server
  [ ] After Modify → only changed record updated in list
  [ ] After Delete → record removed immediately, no ghost
  [ ] After API error → form state rolled back, user notified

BLUEPRINT COMPLIANCE:
  [ ] No raw hex in any component — Blueprint tokens only
  [ ] Spacing: all gaps are multiples of 4px
  [ ] Field height: 32px all controls
  [ ] Grid row height: 32px
  [ ] Status badges: pill style, correct colors per status
  [ ] Tab sequence: matches approved UI/UX design spec

VB6 PATTERN CHECKS:
  [ ] No MAX+1 used anywhere — DB SEQUENCE confirmed
  [ ] No delete-all-lines Modify-save — delta-update confirmed
  [ ] No hardcoded CustID/DivCode — parameterized confirmed
  [ ] prstatus='C' treated as RECEIVED (not Cancelled) — confirmed

STATUS UPDATE VERIFICATION (Foreclosure/Cancellation modules only):
  [ ] After Foreclosure: PO_PRL.FClosed = 'Y' and FCloseddt populated — confirmed in DB
  [ ] After Cancellation: PO_PRH.CANCELFLAG = 'Y' and PO_PRL.CANCELFLAG = 'Y' — confirmed in DB
  [ ] After Undo-Cancellation: PO_PRH.CANCELFLAG = 'N' and PO_PRL.CANCELFLAG = 'N' — confirmed in DB
  [ ] LogDet_PO record inserted atomically in all above paths — confirmed

BLOCKING GUARD VALIDATION (Cancellation modules only):
  [ ] PO_ORD guard: PR with a linked PO record → blocked, correct user message shown
  [ ] APPFLG guard: PR with APPFLG='Y' (approved) → blocked with correct message
  [ ] QTYORD guard: PR with non-zero qty ordered → blocked with correct message
  [ ] PO_ENQL guard: PR in enquiry → blocked with correct message

PRINT STEP DECLARATION:
  [ ] If print applicable: Step 7 completed, both report variants tested (if >1 variant)
  [ ] If print NOT applicable: Step 7 marked NOT APPLICABLE with FSD reference — confirmed

ALL ITEMS PASS? [ ] YES → proceed to IST
                [ ] NO  → fix before IST submission
```

---

# STEP 9 — FSD COMPLIANCE REPORT

Prepare before IST submission. Attach to IST handover email.

```
FSD COMPLIANCE REPORT
Module: [name] | FSD: v[X.X] CEO-approved [date]
UI/UX Design: [ref] | CR Deployed: v[version] | Date: [date]

1. DESIGN POINTS CONFIRMED COMPLIANT:
   [numbered list — each FSD Section 3/4/5 rule confirmed implemented]
   1. PR Date: FY guard via PP_Year table — confirmed
   2. Rate: 4dp precision — confirmed
   ...

2. GAPS (resolved before code generation):
   G-01: [description] — Resolution: [what was decided] — Owner: [name]
   G-02: [description] — Resolution: [what was decided] — Owner: [name]

3. DOMAIN QUESTIONS RESOLVED:
   Q-01: [question] — Answer: [from Mariyaiya/Palanivel] — Date: [date]

4. OPEN CEO DECISIONS (if any):
   [If none: "None — all items resolved before development"]
   [If any: list with decision-required-by date]

5. DEFERRED ITEMS (CEO-approved):
   [If none: "None"]
   [If any: item + CEO approval reference]
```

---

# DEPLOYMENT NOTICE FORMAT

Every deployment email to CEO must use this exact format:

```
Subject: [Module] [Submodule] — Build v[X.X] Deployed — [Date]

This build implements:
  Module:    [Module name]
  FSD:       v[X.X], CEO-approved [date]
  UI/UX:     [Design ref], approved [date]
  Deployed:  [URL] at [time]
  CR Version: v[X.X]

Changes in this build:
  [numbered list of what was implemented — per FSD section reference]

Test environment:
  Frontend: http://172.16.16.40:3000/[path]
  Backend:  http://172.16.16.40:5001/api/[path]

IST Test Checklist: [attached / see [filename]]
FSD Compliance Report: [attached]
Stage 1 Self-Check: COMPLETE — all items PASS

Next step: IST review by [Muthuvel / Seenivasan] | TL-IST gate: Palanivel
```

---

# IMPLEMENTATION SEQUENCE — ENFORCED ORDER

```
1. Gate 0 verification — ALL items confirmed
2. VB6 migration assumption checklist — complete
3. DB migration script — written and executed on DB
4. API contract — written and agreed
5. Stored procedures — all parameterized, transaction-safe
6. Backend controllers + services
7. Frontend (Zustand store → API layer → components → grid)
8. QuestPDF template (field mapping table first, then code)
9. Stage 1 self-check — all items PASS
10. FSD Compliance Report — complete
11. IST handover package — deployed + checklist + compliance report
```

**No step may be skipped. No step may be reordered.**
Skipping or reordering is a process violation requiring TL-Dev (Sasi) sign-off.
