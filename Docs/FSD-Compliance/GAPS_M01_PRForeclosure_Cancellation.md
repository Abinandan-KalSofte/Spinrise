# GAPS — M01: PR Foreclosure & Cancellation
**Date:** 28 May 2026 (updated 29 May 2026)  
**Status:** 4 of 5 BLOCKERs resolved — 1 BLOCKER + 8 WRONG/MISSING items open  
**Modules affected:** `/pr-foreclosure` · `/pr-cancellation`

---

## How to read this file

Each gap has a severity rating:

| Level | Meaning |
|---|---|
| **BLOCKER** | Endpoint throws exception or page crashes |
| **WRONG** | Feature works but produces incorrect output or behaviour |
| **MISSING** | Feature specified in FSD/prototype but not built |
| **COSMETIC** | Visual inconsistency vs prototype |

Fix each BLOCKER before testing anything else. Fix WRONG gaps before UAT.

---

## Backend Gaps

---

### GAP-BE-01 — ✅ FIXED 29 May — `IsSample` SQL INT → C# bool type mismatch

**File:** `PrCancellationRepository.cs` (line 66, linesSql)  
**Symptom:** `GET /api/v1/pr-cancellation/detail` throws Dapper materialization error when loading PR lines for cancellation.

**Root cause:**
```sql
-- Current (wrong) — returns SQL INT (0 or 1)
CASE WHEN ISNULL(b.sample,'N')='Y' THEN 1 ELSE 0 END AS IsSample

-- Required — returns SQL BIT which Dapper maps to C# bool
CAST(CASE WHEN ISNULL(b.sample,'N')='Y' THEN 1 ELSE 0 END AS BIT) AS IsSample
```
Dapper's positional record constructor binding requires exact type matches. SQL `INT` ≠ C# `bool`.

**Fix:** Change the CASE expression in `linesSql` to use `CAST(... AS BIT)`.

---

### GAP-BE-02 — ✅ FIXED 29 May — `Sno` (`prsno`) SQL numeric → C# int type mismatch

**File:** `PrCancellationRepository.cs` (line 51, linesSql)  
**Symptom:** Same `GET /api/v1/pr-cancellation/detail` materialization error — `PO_PRL.prsno` is `numeric` in SQL, maps to `System.Decimal` in Dapper, but `PrForCancellationLineDto.Sno` is `int`.

**Fix:**
```sql
-- Current
b.prsno AS Sno

-- Required
CAST(b.prsno AS INT) AS Sno
```

---

### GAP-BE-03 — WRONG — `canreason` not returned from `ksp_PR_GetCancelledPRsForUndo`

**File:** `ksp_PR_GetCancelledPRsForUndo.sql`  
**Impact:** The undo view shows the cancel DATE as the reason text (see GAP-FE-03). The actual `PO_PRH.canreason` column is never returned.

**Fix — SP:** Add `RTRIM(ISNULL(a.canreason, '')) AS CancelReason` to the SELECT.

**Fix — DTO:** Add `string CancelReason` to `PrCancelledPrDto` (both the C# record and TypeScript interface).

**Fix — FE:** `UndoSubTab` should render `pr.cancelReason` in the reason box, not `pr.cancelledOn`.

---

### GAP-BE-04 — MISSING — PO_ORD guard not implemented (CEO-mandated)

**File:** `ksp_PR_GetCancellablePRs.sql` (commented out)  
**Impact:** PRs that already have a Purchase Order raised against them appear in the "Select PR to Cancel" modal — users can cancel them when they shouldn't be able to.

**Root cause:** `PO_ORD` was the assumed table name; actual PO header table name was not verified. The CEO directed this check (OI-02-F2 CLOSED).

**Action required:** Confirm the correct PO header table name with DBA (`PO_ORDH`? `PO_ORH`?), then restore the NOT EXISTS check:
```sql
AND NOT EXISTS (
    SELECT 1 FROM <correct_po_table> x
     WHERE x.prno = a.prno AND x.divcode = a.divcode)
```
Also add the user-facing error message: *"A Purchase Order has been raised against this PR. Cancel the PO before cancelling the PR."*

---

### GAP-BE-05 — WRONG — `username` column gets userId value, not user name

**Files:** `PrForeclosureRepository.cs` · `PrCancellationRepository.cs` (all LogDet_PO INSERTs)  
**Impact:** `LogDet_PO.username` stores the user ID string instead of the user's display name.

**Root cause:** The repositories receive `userId` (the claims principal ID) but not a separate `userName` string. The controller extracts `SpinriseClaims.UserId` only; it should also extract `SpinriseClaims.UserName`.

**Fix:** In both controllers, extract `UserName` claim and pass it through:
```csharp
var userName = User.FindFirstValue(SpinriseClaims.UserName) ?? userId;
```
Update repository method signatures and all LogDet_PO INSERTs to use the correct value.

---

## Frontend Gaps

---

### GAP-FE-01 — ✅ FIXED 29 May — `PRDocBand` called with wrong props signature

**Files:** `PrForeclosurePage.tsx` · `PrCancellationPage.tsx`  
**Symptom:** The doc band renders hardcoded "Purchase Requisition" and "Auto-generated on save" on both new pages. The dynamic breadcrumb and subLabel/subValue are silently ignored because the component interface doesn't accept those props.

**Root cause:** The existing `PRDocBand` component interface is:
```typescript
interface PRDocBandProps {
  savedPrNo: number | null
  prStatus:  string | null
}
```
The new pages passed `title`, `breadcrumb`, `subLabel`, `subValue` — none of which exist in the interface.

**Fix options (pick one):**
- **Option A (recommended):** Extend `PRDocBandProps` with optional override fields so all pages use the same component.
- **Option B:** Build a new `PRDocBandGeneric` component for non-PR-form pages that accepts breadcrumb array + right-side label/value.

---

### GAP-FE-02 — BLOCKER — `UndoSubTab` header grid — badge renders wrong text

**File:** `UndoSubTab.tsx` line 72  
**Symptom:** The "Lines Restore To" cell shows the string *"Lines Restore To"* instead of the status badge (e.g. "Requested").

**Root cause (line 72):**
```tsx
// Current — evaluates to the string "Lines Restore To" every time
{label === 'Lines Restore To' ? label === 'Lines Restore To' && label : label}

// Required
{label}   // where label = STATUS_LABEL[pr.prevStatus] = "Requested" / "Partial" etc.
```

**Second bug (lines 81–91):** A second `gridTemplateColumns` block was appended to "fix" the badge but creates a duplicate empty row below the header fields. This entire second grid block must be removed.

**Fix:** Replace the entire 4-column header grid with clean logic:
```tsx
<div style={{ display: 'grid', gridTemplateColumns: '2fr 2fr 4fr 2fr', gap: '6px 10px' }}>
  <div>
    <div className="view-lbl">PR Date</div>
    <div>{pr.pRDate}</div>
  </div>
  <div>
    <div className="view-lbl">Cancelled On</div>
    <div style={{ color: '#A32D2D', fontWeight: 600 }}>{pr.cancelledOn}</div>
  </div>
  <div>
    <div className="view-lbl">Department</div>
    <div>{pr.department}</div>
  </div>
  <div>
    <div className="view-lbl">Lines Restore To</div>
    <span style={{ ...badge styles... }}>{STATUS_LABEL[pr.prevStatus] ?? pr.prevStatus}</span>
  </div>
</div>
```

---

### GAP-FE-03 — WRONG — `UndoSubTab` cancellation reason box shows date not reason

**File:** `UndoSubTab.tsx` line 101  
**Symptom:** The "Original Cancellation Reason" section shows *"Cancelled on 05-Apr-2026"* instead of the actual reason text the user typed when cancelling.

**Root cause:** `PrCancelledPrDto` has no `cancelReason` field (see GAP-BE-03). The code fell back to `pr.cancelledOn`:
```tsx
// Current — wrong
{pr.cancelledOn ? `Cancelled on ${pr.cancelledOn}` : '(No reason recorded)'}

// Required — after GAP-BE-03 fix
{pr.cancelReason || '(No reason recorded)'}
```

**Depends on:** GAP-BE-03 must be fixed first.

---

### GAP-FE-04 — MISSING — Cancel modal does not auto-open on page load

**File:** `usePrCancellation.ts`  
**Symptom:** User lands on `/pr-cancellation` and sees an empty screen with the "Find PR to Cancel" button. Must click manually.

**Expected behaviour (from HTML prototype line 1278):**
```javascript
window.addEventListener('DOMContentLoaded', () => {
  setTimeout(() => openCancelModal(), 150)   // auto-open on load
})
```
**Expected behaviour (from VB6 FSD):** `Form_Load` calls `ScopeLookup()` immediately.

**Fix:** In `usePrCancellation.ts`, after `loadCancellable()` resolves on mount, auto-open the cancel modal if the list is non-empty:
```typescript
useEffect(() => {
  loadCancellable().then(data => {
    if (data.length > 0) setCancelModalOpen(true)
  })
}, [])
```

---

### GAP-FE-05 — MISSING — Undo modal does not auto-open when switching to Undo tab

**File:** `usePrCancellation.ts` → `switchTab()`  
**Symptom:** Switching to "↩ Undo Cancellation" tab shows empty state; user must click "Find Cancelled PR" manually.

**Expected behaviour (from HTML prototype `switchSubTab` function):**
```javascript
if (tab === 'undo' && !selectedUndoPR) setTimeout(() => openUndoModal(), 120)
```

**Fix:** The `switchTab` function already has this logic but it may not fire because `loadCancelled()` is not called before the modal opens. Ensure `cancelledList` is loaded before the modal renders, or load inside `openUndoModal()` only on first open.

---

### GAP-FE-06 — ✅ FIXED 29 May — `tb-btn` CSS class does not exist — buttons are unstyled

**Files:** `PrForeclosureGrid.tsx` · `PrCancellationPage.tsx`  
**Symptom:** Toolbar buttons render as plain browser-default buttons with no Spinrise styling.

**Root cause:** The components use `className="tb-btn"` and `className="tb-btn tb-btn-primary"` on raw `<button>` elements. These CSS class names do not exist as global stylesheets — the project uses Ant Design components + inline styles throughout.

**Fix:** Replace raw `<button className="tb-btn ...">` with the existing `<TbBtn>` component from `PRToolbar.tsx`, or convert buttons to Ant Design `<Button>` components with `type="primary"` / `danger` / `default`.

---

### GAP-FE-07 — COSMETIC — `App` wrapper per page is inconsistent

**Files:** `PrForeclosurePage.tsx` · `PrCancellationPage.tsx`  
**Symptom:** `<App>` is wrapped per page. All other pages (`PurchaseRequisitionPage`, `PrAmendmentPage`) do not do this — they rely on the app-level `<App>` provider in `main.tsx` or `App.tsx`.

**Fix:** Remove `<App>` wrapper from both page components. Ensure the top-level `App.tsx` or router wraps with `<App>`.

---

### GAP-FE-08 — WRONG — Keyboard handler has stale closure risk

**File:** `PrCancellationPage.tsx`  
**Symptom:** `F3`, `Ctrl+S`, `Alt+X` may call stale versions of `doCancel`, `doUndo`, etc. after state updates.

**Root cause:** `useEffect` dependency array lists `doCancel`, `doUndo`, `openCancelModal`, `openUndoModal`, `reset` but none are wrapped in `useCallback` inside the hook — they are recreated on every render.

**Fix:** Wrap `doCancel`, `doUndo`, `openCancelModal`, `openUndoModal`, `reset` in `useCallback` inside `usePrCancellation`, with correct dependency arrays.

---

## Process Gaps (Why These Happened)

---

### GAP-PROC-01 — Column names assumed from FSD, not verified from existing SPs

**What happened:** SPs were written using column names from the FSD description text (`mm_MACmas.SCCCODE`, `mm_MACmas.divcode`, `mm_MACmas.macno`, `in_item.divcode`) without first reading the existing working SPs.

**What should happen:** Before writing any new SP, read ALL existing SPs that touch the same tables to extract the definitive column name and type map.

**Key differences found:**

| Table | FSD-assumed column | Actual column | Source confirmed from |
|---|---|---|---|
| `MM_MACMAS` | `macno` | `MAC_NO` | `ksp_PR_GetMachineLookup.sql` |
| `MM_MACMAS` | `MacFlag` | `MACFLAG` | `ksp_PR_GetMachineLookup.sql` |
| `MM_MACMAS` | `SCCCODE` | **does not exist** | Not in any existing SP |
| `in_item` | `divcode` | **does not exist** | `ksp_PR_GetById.sql` joins on itemcode only |
| `PO_PRH` | implied to have `pre_cancel_status` | **did not exist** — required ALTER TABLE | `sys.columns` check needed |

---

### GAP-PROC-02 — Dapper type mapping not verified before writing DTOs

**What happened:** DTOs used `int PrSno` and `bool IsSample` without checking what SQL types Dapper would see. Three separate materialization errors resulted.

**Rule for future sessions:**

| SQL type | C# type in Dapper positional record |
|---|---|
| `NUMERIC(x,0)` | `decimal` (not `int`) unless `CAST(col AS INT)` in SP |
| `CASE WHEN ... THEN 1 ELSE 0 END` | `int` (not `bool`) unless `CAST(... AS BIT)` |
| `CAST(col AS INT)` | `int` ✓ |
| `CAST(... AS BIT)` | `bool` ✓ |
| `VARCHAR(n)` | `string` ✓ |
| `DATETIME` | `DateTime` ✓ |

Always add `CAST` in the SP to enforce the expected C# type. Do not rely on Dapper auto-conversion in positional record constructors.

---

### GAP-PROC-03 — Existing shared component interfaces not read before use

**What happened:** `PRDocBand` was imported and used on two new pages with invented props that don't exist in the component. The existing interface was never read.

**Rule:** Before importing any existing shared component, read its props interface. If the interface doesn't fit the new use case, extend it or create a variant — never pass props that aren't in the interface.

---

### GAP-PROC-04 — `PO_ORD` table name assumed from FSD, not verified

**What happened:** The CEO-mandated PO guard was written using `PO_ORD` from the FSD text, which threw "Invalid object name 'PO_ORD'" in SSMS. The check was removed rather than the table name verified.

**Action:** Query the database:
```sql
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME LIKE 'PO_%' ORDER BY TABLE_NAME
```
Identify the correct PO header/order table and restore the check.

---

## Fix Priority Order (updated 29 May)

```
FIXED (29 May session):
  ✅ GAP-BE-01  IsSample BIT cast
  ✅ GAP-BE-02  Sno INT cast
  ✅ GAP-FE-01  PRDocBand props extended
  ✅ GAP-FE-06  tb-btn class — replaced with TbBtn component

IMMEDIATE (1 BLOCKER remaining):
  GAP-FE-02  UndoSubTab badge bug — renders "Lines Restore To" string

BEFORE UAT:
  GAP-BE-03  + GAP-FE-03  cancelReason field (SP → DTO → types.ts → UndoSubTab — together)
  GAP-FE-04  Auto-open cancel modal on load
  GAP-FE-05  Auto-open undo modal on tab switch
  GAP-FE-08  useCallback for keyboard handlers
  GAP-BE-05  UserName in audit log
  GAP-FE-07  App wrapper cleanup

AFTER TABLE NAME CONFIRMED:
  GAP-BE-04  PO_ORD guard restore — confirm table name with DBA
```
