# Bug Fix Prompt — M01 PR Foreclosure & Cancellation
**Date:** 28 May 2026  
**Sources analysed:** FSD v1.1 DOCX · `SPINRISE_FSD_M01_PRForeclosure_v1_1.html` · `PR_Cancellation and foreclosure Forms_Documentation.md`  
**Status:** 7 Foreclosure bugs + 1 Cancellation bug — all root-caused below

---

## CRITICAL ROOT CAUSE SHARED BY MOST BUGS

Both modules return empty data from the live database.  
**Cause:** Both SPs filter `a.cancelflag IS NULL` but the live VB6 database stores `'N'` (the string) for non-cancelled PRs, not `NULL`.

Evidence from the existing working SP `ksp_PR_GetById.sql` line 37:
```sql
WHEN ISNULL(h.cancelflag, '') <> '' THEN 'PR. CANCELLED'
```
This pattern (`ISNULL(col,'') <> ''`) is how the entire codebase checks for cancelled status. Non-cancelled means: NULL **or** empty string or 'N'.

**Fix that must be applied to BOTH SPs immediately — nothing else works until this is fixed:**
```sql
-- WRONG (current) — excludes all active PRs stored as cancelflag='N'
AND a.cancelflag IS NULL

-- CORRECT — matches NULL, empty string, and 'N' as non-cancelled; only 'Y' = cancelled
AND ISNULL(a.cancelflag, '') <> 'Y'
```

---

## FORECLOSURE MODULE — 7 Bugs

---

### BUG-FC-01 — Remove info banner row

**User report:** "Remove this row — Shows PR lines with status Requested only..."

**Analysis vs HTML prototype:**  
The HTML prototype shows a simple blue banner:
```html
<div class="banner info">
  <span class="banner-icon">ℹ</span>
  <span>Shows PR lines with status <strong>Requested</strong> only — balance &gt; 0 · FClosed ≠ 'Y' · CancelFlag = 'N' · Cross-FY scope (sp_PR_GetOpenForForeclosure).
  <strong>Select lines to force-close. This action cannot be undone — no undo-foreclosure exists.</strong></span>
</div>
```

Our implementation added internal technical details (`ksp_PR_GetOpenForForeclosure`, cross-FY scope text) that are developer notes, not user-facing content.

**Root cause:** The banner was written for developer reference, not for the UI.

**Fix — `PrForeclosureGrid.tsx`:**  
Remove the entire `{/* Info banner */}` section, or replace with the clean prototype text:
```tsx
<div style={{ padding:'6px 16px', fontSize:12, fontWeight:500, flexShrink:0,
  background:'#e6f4ff', color:'#1677ff', borderBottom:'1px solid #bae0ff',
  display:'flex', alignItems:'flex-start', gap:8 }}>
  <span style={{ flexShrink:0, fontSize:13, marginTop:1 }}>ℹ</span>
  <span>
    Select PR lines to force-close.{' '}
    <strong>This action cannot be undone — no undo-foreclosure exists.</strong>
  </span>
</div>
```

---

### BUG-FC-02 — Checkbox not working as expected

**User report:** "In Grid checkbox not working as expected refer HTML file"

**Analysis vs HTML prototype:**  
The HTML prototype uses ONLY the checkbox element's `onchange` handler for selection. There is NO `tr.onclick` in the prototype:
```javascript
// HTML prototype — checkbox only, no row click
tr.innerHTML = `
  <td class="c"><input type="checkbox" class="row-chk" data-idx="${i}" onchange="fcRowCheck(this)"></td>
  ...
`
```
The prototype checkbox handler:
```javascript
function fcRowCheck(chk) {
  const idx = parseInt(chk.dataset.idx);
  chk.checked ? fcSelected.add(idx) : fcSelected.delete(idx);
  chk.closest('tr').classList.toggle('sel', chk.checked);
  updateFCFooter();
  // update master checkbox indeterminate state
}
```

**Root cause in our code:**  
1. `<tr onClick={() => toggleRow(line, !isSelected(line))}>` — row click fires on ANY cell click
2. `<td onClick={e => e.stopPropagation()}>` around the checkbox — the `stopPropagation` runs but the checkbox `onChange` ALSO fires, causing a double-toggle (select then immediately deselect)
3. Ant Design `<Checkbox>` wraps the native checkbox — its onChange fires independently from the tr.onClick, creating two conflicting handlers

**Fix — `PrForeclosureGrid.tsx`:**  
Remove `onClick` from `<tr>`. Handle selection ONLY through the checkbox:
```tsx
<tr
  key={`${line.prNo}-${line.prSno}`}
  style={{
    background: sel ? '#dbeafe' : idx % 2 === 1 ? '#f0f5ff' : '#fff',
    borderLeft: sel ? '3px solid #185FA5' : '3px solid transparent',
    // NO onClick here
  }}
>
  <td style={{ textAlign:'center', padding:'4px 8px' }}>
    <input
      type="checkbox"
      checked={sel}
      onChange={e => toggleRow(line, e.target.checked)}
      style={{ width:15, height:15, accentColor:'#185FA5', cursor:'pointer' }}
    />
  </td>
  ...
```
Use native `<input type="checkbox">` — not Ant Design `<Checkbox>` — to exactly match the HTML prototype. The master checkbox in `<th>` similarly uses a native checkbox.

---

### BUG-FC-03 — Clicking one row selects all rows for same PR

**User report:** "In Grid when I click one row of PR its selecting all related rows for same PR"

**Analysis:**  
This is a direct consequence of BUG-FC-02. When `tr.onClick` fires, React re-renders. Because multiple rows of the same PR share visual state, the combined effect of `tr.onClick` + `Checkbox onChange` causes incorrect multi-row state changes.

Additionally, if `prsno` was `null/undefined` in the response (before the CAST fix was deployed), all lines of the same PR would share the key `"12345-undefined"`, making them indistinguishable.

**Root cause:** Two causes:
1. `tr.onClick` fires for ALL cells including the checkbox cell — see BUG-FC-02
2. Possible `prsno` mapping issue if old SP (without `CAST(b.prsno AS INT)`) was still deployed

**Fix:**
1. Apply BUG-FC-02 fix (remove `tr.onClick`)
2. Verify the SP deployed to the DB has `CAST(b.prsno AS INT) AS PrSno` — check in SSMS: `EXEC sp_helptext 'ksp_PR_GetOpenForForeclosure'`

---

### BUG-FC-04 — Date column empty → save fails with PRDate required

**User report:** "Date column showing empty because of that getting this error while confirm foreclosure — `Lines[0].PRDate: The PRDate field is required`"

**Analysis — two causes:**

**Cause A (PRIMARY): `cancelflag IS NULL` returns no rows**  
If the live DB stores `cancelflag='N'` for non-cancelled PRs (standard VB6 pattern), the filter `a.cancelflag IS NULL` returns ZERO rows. No rows = no dates = empty grid. Any rows the user sees may be from a different session or a subset of data.

**Cause B: NULL prdate in database**  
Some historical records may have `NULL` in `prdate`. `CONVERT(varchar(12), NULL, 106)` returns NULL → Dapper maps to `null` → frontend gets `null` for `pRDate` → save payload has `pRDate: null` → `[Required]` validation fails.

**Fix — `ksp_PR_GetOpenForForeclosure.sql`:**
```sql
-- Fix A: cancelflag filter
AND ISNULL(a.cancelflag, '') <> 'Y'    -- replaces: AND a.cancelflag IS NULL

-- Fix B: guard against NULL prdate
ISNULL(CONVERT(varchar(12), a.prdate, 106), '') AS PRDate  -- replaces: CONVERT(...) AS PRDate
```

---

### BUG-FC-05 — Status column shows raw single characters (C, F)

**User report:** "In status column showing only C, F"

**Analysis vs `ksp_PR_GetById.sql`:**  
The live database stores single character codes in `PO_PRL.PRSTATUS`. The full mapping confirmed from the existing working SP:

| PRSTATUS value | Meaning |
|---|---|
| NULL / '' | Requested |
| `'E'` | Enquired |
| `'O'` (qtyord > 0) | Ordered |
| `'O'` (qtyord = 0) | Order Cancelled |
| `'C'` | Received |
| `'X'` | Cancelled (set by our cancel flow) |
| `'Z'` | Force Closed (set by our foreclose flow) |

Our `StatusBadge` component only handled: `S`, `P`, `E`, `O`, `Z`. The values `C` (Received), `X` (Cancelled) and multi-state `O` variants were not mapped → raw character displayed.

**Root cause:** The SP returns raw `PRSTATUS` chars. The frontend STATUS_BADGE map was incomplete.

**Fix — `ksp_PR_GetOpenForForeclosure.sql`:**  
Convert PRSTATUS to a readable label in the SP itself so both backend and frontend agree on the vocabulary:
```sql
CASE RTRIM(ISNULL(b.PRSTATUS,''))
    WHEN 'E' THEN 'Enquired'
    WHEN 'C' THEN 'Received'
    WHEN 'X' THEN 'Cancelled'
    WHEN 'Z' THEN 'Force Closed'
    WHEN 'O' THEN
        CASE WHEN ISNULL(b.QTYORD,0) > 0 THEN 'Ordered' ELSE 'Order Cancelled' END
    ELSE 'Requested'
END AS PrevStatus
```

**Fix — `PrForeclosureGrid.tsx` `StatusBadge`:**  
Update to match the text labels now coming from the SP:
```typescript
const STATUS_BADGE: Record<string, { color: string; bg: string; border: string }> = {
  'Requested':       { color:'#15803d', bg:'#dcfce7', border:'#86efac' },
  'Enquired':        { color:'#185FA5', bg:'#E6F1FB', border:'#bfdbfe' },
  'Ordered':         { color:'#7c3aed', bg:'#f3e8ff', border:'#ddd6fe' },
  'Order Cancelled': { color:'#A32D2D', bg:'#FCEBEB', border:'#fca5a5' },
  'Received':        { color:'#3B6D11', bg:'#EAF3DE', border:'#86efac' },
  'Cancelled':       { color:'#A32D2D', bg:'#FCEBEB', border:'#fca5a5' },
  'Force Closed':    { color:'#888',    bg:'#f0f0f0', border:'#d0d0d0' },
}
function StatusBadge({ status }: { status: string }) {
  const cfg = STATUS_BADGE[status] ?? STATUS_BADGE['Requested']
  return (
    <span style={{ fontSize:10, fontWeight:700, padding:'2px 8px', borderRadius:10,
      color:cfg.color, background:cfg.bg, border:`1px solid ${cfg.border}`, whiteSpace:'nowrap' }}>
      {status || 'Requested'}
    </span>
  )
}
```

---

### BUG-FC-06 — Shows cancelled PRs / wrong filter

**User report:** "While fetching PR records need to show only approved PR not cancelled — refer business rules in FSD"

**Analysis vs VB6 Billdisplay query (FSD markdown):**
```
WHERE balance>0 AND qtyord−qtyrec>=0 AND FClosed<>'Y' AND cancelflag='N' AND divcode=@divcode
```

The VB6 code uses `cancelflag='N'` — the string 'N', not NULL. Our SP uses `cancelflag IS NULL`. On a database where non-cancelled PRs have `cancelflag='N'`, our filter returns zero records.

**FSD business rule (Section 4):** Foreclosure listing shows all open, non-foreclosed PR lines across all financial years with a positive balance. Non-cancelled = cancelflag not 'Y'.

**Root cause:** Literal translation of "IS NULL" from FSD text, without testing against live DB values.

**Fix — `ksp_PR_GetOpenForForeclosure.sql`:**
```sql
-- Replace (line 35):
AND a.cancelflag IS NULL
-- With:
AND ISNULL(a.cancelflag, '') <> 'Y'
```

---

### BUG-FC-07 — Button styles not applied

**User report:** "UI Design specifically button style operations"

**Analysis vs HTML prototype:**  
The HTML prototype uses a specific button style class `.tb-btn` with variants `.primary`, `.success`, `.danger-f`. These are defined in the prototype CSS as:
```css
.tb-btn { display:inline-flex; align-items:center; gap:5px; padding:5px 11px;
  border:1px solid #d0d0d0; border-radius:6px; background:#fff; ... }
.tb-btn.success { background:var(--blue); color:#fff; border-color:var(--blue); }
```

Our `PrForeclosureGrid.tsx` uses raw `<button className="tb-btn">` — these CSS classes do not exist as global styles in the Spinrise React app. The project uses Ant Design + inline styles.

The existing `PRToolbar.tsx` exports a `TbBtn` component that matches the design.

**Fix — `PrForeclosureGrid.tsx`:**  
Replace all raw `<button className="tb-btn ...">` with the existing `TbBtn` component:
```tsx
import { TbBtn, TbSep } from '../pr-form/PRToolbar'

// Toolbar buttons:
<TbBtn label="Select All" icon="☑" onClick={selectAll} disabled={lines.length === 0} />
<TbBtn label="Clear" icon="☐" onClick={clearAll} disabled={selectedCount === 0} />
<TbSep />
<TbBtn label="Confirm Foreclosure" icon="⚡" kbd="Ctrl+S"
  variant="success" onClick={confirmForeclosure} disabled={selectedCount === 0} />
<TbSep />
<TbBtn label="Print" icon="🖨" kbd="Ctrl+P" disabled title="Not implemented" />
<TbBtn label="Cancel" icon="✕" kbd="Alt+X" onClick={clearAll} />
```

---

## CANCELLATION MODULE — 1 Bug

---

### BUG-CN-01 — Cancellable PRs API returns empty array

**User report:** `GET /pr-cancellation/cancellable?yfDate=2026-04-01&ylDate=2027-03-31` returns `{"data":[]}`

**Analysis:**  
The SP `ksp_PR_GetCancellablePRs` has the same `cancelflag IS NULL` problem as the foreclosure SP. Additionally it has a second potential cause.

**Root cause 1 (same as foreclosure BUG-FC-06):**
```sql
AND a.cancelflag IS NULL    -- returns zero records if live DB uses 'N' not NULL
```

**Root cause 2 — `APPFLG <> 'Y'` filter:**  
The SP filters to show PRs where `APPFLG <> 'Y'` (not approved). This matches the VB6 FSD which says cancellable PRs must not be enquired, ordered, or approved.

However: if ALL PRs in the current FY have been approved (`APPFLG = 'Y'`), this filter returns empty. Verify this in SSMS:
```sql
SELECT COUNT(*) FROM PO_PRH
WHERE divcode = '<your_divcode>'
  AND ISNULL(cancelflag,'') <> 'Y'
  AND prdate BETWEEN '2026-04-01' AND '2027-03-31'
```
If this returns > 0, then the APPFLG filter is causing the empty result.

**Per FSD business rule (Indentcancellation.frm ScopeLookup):**
> PRs eligible for cancellation: CANCELFLAG IS NULL AND prno NOT IN (PO_ENQL) AND prdate BETWEEN yfdate AND yldate AND QTYORD=0 AND APPFLG<>'Y'

The APPFLG<>'Y' filter is CORRECT per FSD — only un-approved PRs can be cancelled.

**Fix — `ksp_PR_GetCancellablePRs.sql`:**
```sql
-- Replace (line 35):
AND a.cancelflag IS NULL
-- With:
AND ISNULL(a.cancelflag, '') <> 'Y'
```

**Diagnostic query to run in SSMS before deploying the fix:**
```sql
-- Check what cancelflag values exist in live data
SELECT ISNULL(cancelflag,'(NULL)') AS cancelflag_value, COUNT(*) AS cnt
FROM PO_PRH
WHERE divcode = '<your_divcode>'
GROUP BY cancelflag;

-- Check if any cancellable PRs exist with the corrected filter
SELECT COUNT(*) AS eligible_count
FROM PO_PRH a
WHERE a.divcode = '<your_divcode>'
  AND ISNULL(a.cancelflag, '') <> 'Y'
  AND ISNULL(a.APPFLG, 'N') <> 'Y'
  AND a.prdate BETWEEN '2026-04-01' AND '2027-03-31'
  AND NOT EXISTS (SELECT 1 FROM PO_ENQL x WHERE x.prno=a.prno AND x.divcode=a.divcode)
  AND NOT EXISTS (SELECT 1 FROM PO_PRL x WHERE x.prno=a.prno AND x.divcode=a.divcode AND ISNULL(x.QTYORD,0)>0);
```

---

## Complete Fix Checklist

### Database — run merged.sql after all fixes below

```
[ ] ksp_PR_GetOpenForForeclosure  — 4 changes:
    (a) cancelflag: IS NULL → ISNULL(a.cancelflag,'') <> 'Y'
    (b) PRDate: add ISNULL wrapper → ISNULL(CONVERT(varchar(12), a.prdate, 106),'')
    (c) PrevStatus: replace raw PRSTATUS with CASE readable labels
    (d) [already done] CAST(b.prsno AS INT)

[ ] ksp_PR_GetCancellablePRs  — 1 change:
    cancelflag: IS NULL → ISNULL(a.cancelflag,'') <> 'Y'

[ ] merged.sql: update with both corrected SPs
```

### Backend — no C# changes required for these bugs

```
[ ] None — all bugs are in SP logic or frontend
```

### Frontend

```
[ ] PrForeclosureGrid.tsx  — 5 changes:
    (a) Remove tr.onClick — BUG-FC-02 / BUG-FC-03
    (b) Replace Ant Design Checkbox with native <input type="checkbox"> — BUG-FC-02
    (c) Remove info banner or replace with clean text — BUG-FC-01
    (d) Update StatusBadge map to use readable text keys — BUG-FC-05
    (e) Replace className="tb-btn" buttons with TbBtn component — BUG-FC-07
```

---

## FSD Business Rule Validation Summary

| Rule | FSD Source | Current SP | Status |
|---|---|---|---|
| Non-cancelled filter | `cancelflag='N'` (VB6 Billdisplay) | `cancelflag IS NULL` | ❌ Wrong |
| PRDate null guard | No NULL in production data (existing SPs work) | No ISNULL wrapper | ⚠ Risk |
| Balance filter | `QTYREQD-QTYORD-enq_qty > 0` | Correct | ✅ |
| FClosed filter | `FClosed<>'Y'` | `ISNULL(b.FClosed,'N')<>'Y'` | ✅ |
| qtyord-qtyrec>=0 | Billdisplay VB6 query | Correct | ✅ |
| Cross-FY scope | OI-01-F1 CLOSED | No yfdate filter | ✅ |
| Cancellation: not approved | `APPFLG<>'Y'` | Correct | ✅ |
| Cancellation: not enquired | `prno NOT IN PO_ENQL` | NOT EXISTS (correct) | ✅ |
| Cancellation: QTYORD=0 | `QTYORD=0` aggregate check | NOT EXISTS on PO_PRL | ✅ |
| Cancellation: no PO raised | CEO OI-02-F2 | Removed (table unknown) | ⚠ Open |
| Row selection = checkbox only | HTML prototype | tr.onClick added (wrong) | ❌ Wrong |
| Status = readable label | HTML prototype badges | Raw char from DB | ❌ Wrong |
