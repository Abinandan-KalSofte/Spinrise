# Claude Code Development Guide — M01 PR Foreclosure & Cancellation
**Purpose:** Step-by-step instructions for Claude Code to build these two sub-modules correctly in a future session.  
**Written:** 28 May 2026 — after post-build gap analysis  
**Prerequisite reading:** `GAPS_M01_PRForeclosure_Cancellation.md`

---

## Before Writing a Single Line of Code

### Step 1 — Extract the live column map from existing SPs

Run these in parallel before writing any SP or DTO:

```bash
# Read every SP that touches the tables used by this module
Read: Spinrise.DBScripts/Scripts/02-StoredProcedures/ksp_PR_GetById.sql
Read: Spinrise.DBScripts/Scripts/02-StoredProcedures/ksp_PR_GetMachineLookup.sql
Read: Spinrise.DBScripts/Scripts/02-StoredProcedures/ksp_PR_Save.sql
Read: Spinrise.DBScripts/Scripts/02-StoredProcedures/ksp_PR_Delete.sql
```

Build a personal column reference table before writing anything:

| Table | Column | SQL Type | C# Type | Notes |
|---|---|---|---|---|
| `PO_PRH` | `prno` | `numeric(6,0)` | `decimal` | Use `a.prno AS PrNo` alias |
| `PO_PRH` | `prdate` | `datetime` | `DateTime` | |
| `PO_PRH` | `divcode` | `varchar(2)` | `string` | Has divcode ✓ |
| `PO_PRH` | `depcode` | `varchar(3)` | `string` | |
| `PO_PRH` | `cancelflag` | `char(1) NULL` | `string?` | NULL = not cancelled, 'Y' = cancelled |
| `PO_PRH` | `canreason` | `varchar(250) NULL` | `string` | |
| `PO_PRH` | `canceldt` | `datetime NULL` | `DateTime?` | |
| `PO_PRL` | `prsno` | `numeric(4,0)` | `decimal` → `CAST AS INT` | |
| `PO_PRL` | `divcode` | `varchar(2)` | `string` | Has divcode ✓ |
| `PO_PRL` | `itemcode` | `varchar(10)` | `string` | |
| `PO_PRL` | `macno` | `varchar(...)` | `string` | PRL column is `macno` (lowercase) |
| `PO_PRL` | `QTYREQD` | `numeric(12,3)` | `decimal` | |
| `PO_PRL` | `QTYORD` | `numeric(12,3)` | `decimal` | |
| `PO_PRL` | `PRSTATUS` | `char(1) NULL` | `string` | |
| `PO_PRL` | `FClosed` | `char(1) NULL` | `string` | |
| `PO_PRL` | `FCloseddt` | `datetime NULL` | `DateTime?` | |
| `PO_PRL` | `sample` | `char(1) NULL` | — | Use `CAST(CASE WHEN...THEN 1 ELSE 0 END AS BIT)` |
| `in_item` | `itemcode` | `varchar(10)` | `string` | Join on itemcode ONLY — no divcode |
| `in_item` | `Itemname` | `varchar(...)` | `string` | Capital I |
| `in_item` | `UOM` | `varchar(...)` | `string` | |
| `in_item` | `RATE` | `numeric(15,5)` | `decimal` | |
| `in_item` | `curstk` | `decimal(20,3)` | `decimal` | |
| `In_dep` | `depcode` | `varchar(3)` | `string` | Has divcode ✓ |
| `In_dep` | `Depname` | `varchar(...)` | `string` | Capital D |
| `MM_MACMAS` | `MAC_NO` | `varchar(...)` | `string` | **Uppercase with underscore** |
| `MM_MACMAS` | `MACFLAG` | `char(1)` | `string` | **Uppercase, no space** |
| `MM_MACMAS` | `DIVCODE` | `varchar(2)` | `string` | **Uppercase** |
| `MM_MACMAS` | `DEPCODE` | `varchar(3)` | `string` | **Uppercase** |
| `MM_MACMAS` | `DESCRIPTION` | `varchar(...)` | `string` | |
| `PO_INDENTTYPE` | `itype` | `char(1)` | `string` | |
| `PO_INDENTTYPE` | `idesc` | `varchar(...)` | `string` | |
| `PO_ENQL` | `prno` | `numeric` | `decimal` | Used in NOT EXISTS check |

### Step 2 — Check the existing shared component interfaces

Before using any shared component, read its props interface:

```bash
Read: spinrise-web/src/features/pr/components/pr-form/PRToolbar.tsx
```

Do not pass props that aren't in the interface. If the interface doesn't fit, extend it first.

### Step 3 — Verify new schema columns exist

For any new column the module depends on (e.g. `pre_cancel_status`), confirm it exists:

```sql
-- Run in SSMS before writing any code that references it
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'PO_PRH'
ORDER BY ORDINAL_POSITION;
```

If it doesn't exist, the ALTER TABLE must be in merged.sql BEFORE the SP that references it, with an `IF NOT EXISTS` guard:

```sql
IF NOT EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.PO_PRH')
                 AND name = N'pre_cancel_status')
BEGIN
    ALTER TABLE dbo.PO_PRH ADD pre_cancel_status char(1) NULL;
END;
GO
```

### Step 4 — Confirm unknown table names

If the FSD references a table name you haven't seen in existing SPs, verify it first:

```sql
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME LIKE 'PO_%'
ORDER BY TABLE_NAME;
```

Never write a SP with an assumed table name that isn't confirmed in an existing SP.

---

## SP Writing Rules

### Always alias every column with the exact DTO parameter name

```sql
-- WRONG — prsno returns as 'prsno' (lowercase), Dapper matches case-insensitively
-- but the type mismatch will still fail
b.prsno

-- CORRECT — explicit alias + type cast
CAST(b.prsno AS INT) AS PrSno
```

### Type-casting rules for Dapper positional records

| Scenario | SP fix |
|---|---|
| numeric → int | `CAST(b.prsno AS INT) AS PrSno` |
| CASE 0/1 → bool | `CAST(CASE WHEN ... END AS BIT) AS IsSample` |
| datetime display | `CONVERT(varchar(12), a.prdate, 106) AS PRDate` |
| nullable string | `RTRIM(ISNULL(a.depcode, '')) AS DepCode` |
| numeric for decimal | No cast needed — `a.prno AS PrNo` maps to `decimal` ✓ |

### MM_MACMAS join pattern (copy exactly)

```sql
LEFT JOIN MM_MACMAS e ON e.MACFLAG = 'M'
                      AND e.DIVCODE = b.divcode
                      AND e.DEPCODE = b.depcode
                      AND e.MAC_NO  = b.macno
```

### in_item join pattern (no divcode)

```sql
INNER JOIN in_item d ON d.itemcode = b.itemcode
-- DO NOT add: AND d.divcode = b.divcode  ← in_item has no divcode
```

---

## DTO Writing Rules

### Use class with properties, not positional records, for Dapper mapping

Positional records require exact constructor parameter name + type match.  
A class with auto-properties is safer because Dapper maps by property name with type conversion:

```csharp
// SAFER for Dapper — use when there are bool, int (from numeric) fields
public class PrForeclosureLineDto
{
    public decimal PrNo       { get; set; }
    public string  PRDate     { get; set; } = string.Empty;
    public int     PrSno      { get; set; }  // Dapper converts numeric → int when property setter allows it
    public bool    IsSample   { get; set; }  // Dapper converts BIT → bool ✓
    // ...
}
```

OR keep records but always add the SP CAST to match the C# type exactly.

---

## Repository Writing Rules

### Always read shared component SQL before writing inline SQL

Before writing any inline Dapper SQL in a repository, check what the existing SPs do:
- Are there existing joins on the same tables? Use the exact same join pattern.
- What aliases do they use? Use the same aliases.

### Transaction pattern (copy exactly from existing UoW)

```csharp
await _uow.BeginTransactionAsync();
try
{
    await _uow.Connection.ExecuteAsync(sql, params, _uow.Transaction);
    // ... more DML ...
    await _uow.CommitAsync();
}
catch
{
    await _uow.RollbackAsync();
    throw;
}
```

### BR-UNDO-01 implementation pattern

```csharp
// MUST read pre_cancel_status BEFORE the transaction clears it
var preStatus = await _uow.Connection.QueryFirstOrDefaultAsync<string>(
    "SELECT ISNULL(pre_cancel_status,'') FROM PO_PRH WHERE ...",
    new { ... }) ?? string.Empty;

await _uow.BeginTransactionAsync();
// Step 1: UPDATE PO_PRH SET pre_cancel_status = NULL (clears it)
// Step 2: UPDATE PO_PRL SET PRSTATUS = @preStatus (uses the captured variable)
// Step 3: INSERT LogDet_PO
await _uow.CommitAsync();
```

---

## Frontend Writing Rules

### Before using a shared component — read its props interface

```typescript
// Read the component file. Look for the interface/props type.
// Then check your usage matches.
```

For `PRDocBand` specifically — it currently accepts only `{ savedPrNo, prStatus }`.  
For new pages, either extend it or build a `PRDocBandGeneric` that accepts:

```typescript
interface PRDocBandGenericProps {
  breadcrumb: string[]   // e.g. ['Purchase Order', 'PR Foreclosure Entry']
  subLabel:   string     // e.g. 'Processing Date'
  subValue:   string     // e.g. '28 May 2026'
}
```

### Use `TbBtn` for toolbar buttons, not raw `<button>` with className

```tsx
// WRONG — tb-btn CSS class does not exist
<button className="tb-btn tb-btn-primary" onClick={...}>

// CORRECT — use the existing TbBtn component
import { TbBtn, TbSep } from '../components/pr-form/PRToolbar'

<TbBtn icon={<SearchOutlined />} label="Find PR to Cancel" kbd="F3"
       variant="primary" onClick={openCancelModal} />
```

### Auto-open modal pattern (matching VB6 Form_Load + HTML prototype)

```typescript
// In hook — load data AND auto-open modal on mount
useEffect(() => {
  loadCancellable().then(() => {
    setCancelModalOpen(true)  // auto-open, per VB6 ScopeLookup on Form_Load
  })
}, [])
```

### Wrap async functions in useCallback for stable keyboard handler references

```typescript
const doCancel = useCallback(async () => {
  // ...
}, [selectedCancelPr, cancelReason, modal, message, loadCancellable])

// Then in the keyboard handler useEffect:
useEffect(() => {
  const handler = (e: KeyboardEvent) => {
    if (e.ctrlKey && e.key === 's') { e.preventDefault(); void doCancel() }
  }
  window.addEventListener('keydown', handler)
  return () => window.removeEventListener('keydown', handler)
}, [doCancel])  // now stable — only re-registers when doCancel actually changes
```

### Never wrap `<App>` per page

```tsx
// WRONG
export default function PrForeclosurePage() {
  return (
    <App>
      <div>...</div>
    </App>
  )
}

// CORRECT — App context provided once at router level in main.tsx
export default function PrForeclosurePage() {
  return (
    <div>...</div>
  )
}
```

### UndoSubTab — correct 4-column header grid pattern

```tsx
const header4 = [
  { label: 'PR Date',          render: () => <div>{pr.pRDate}</div> },
  { label: 'Cancelled On',     render: () => <div style={{ color:'#A32D2D', fontWeight:600 }}>{pr.cancelledOn}</div> },
  { label: 'Department',       render: () => <div>{pr.department}</div> },
  { label: 'Lines Restore To', render: () => (
    <span style={{ ...badge, color: badge.color, background: badge.bg, border: `1px solid ${badge.border}` }}>
      {STATUS_LABEL[pr.prevStatus] ?? pr.prevStatus}
    </span>
  )},
]

// Render:
<div style={{ display:'grid', gridTemplateColumns:'2fr 2fr 4fr 2fr', gap:'6px 10px' }}>
  {header4.map(({ label, render }) => (
    <div key={label}>
      <div style={{ fontSize:11, fontWeight:600, color:'#475569', marginBottom:2 }}>{label}</div>
      {render()}
    </div>
  ))}
</div>
// NO second grid below this. One grid only.
```

---

## Checklist Before Declaring a Module "Done"

```
SP LAYER
[ ] Every column alias in the SP matches the exact DTO property name
[ ] Every numeric prsno/prsno-like column has CAST(... AS INT)
[ ] Every CASE 0/1 column has CAST(... AS BIT)
[ ] MM_MACMAS join uses MACFLAG, DIVCODE, DEPCODE, MAC_NO (uppercase)
[ ] in_item join has NO divcode condition
[ ] New schema columns verified in INFORMATION_SCHEMA before use
[ ] Unknown table names verified before use (no guessing)

BACKEND
[ ] DTO types match SQL types exactly (verify Dapper mapping table above)
[ ] UserName extracted from SpinriseClaims.UserName for LogDet_PO.username
[ ] All IntelliSense / build errors resolved

FRONTEND
[ ] Shared component props interface read before use
[ ] TbBtn used for toolbar buttons (not raw <button className="tb-btn">)
[ ] PRDocBand receives correct props for this page type
[ ] Auto-open modal on page load implemented (matching VB6 Form_Load)
[ ] useCallback on all functions referenced in useEffect dependency arrays
[ ] No <App> wrapper on page components
[ ] `tsc --noEmit` passes with zero errors
[ ] `dotnet build` passes with zero errors
```
