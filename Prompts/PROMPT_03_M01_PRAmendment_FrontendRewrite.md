# SPINRISE — FRONTEND REWRITE PROMPT
## Module: M01 PR Amendment Entry — Frontend Alignment to HTML Design
## Version: v1.0 | 28 May 2026
## FSD: v2.3 CEO-countersigned 23-May-2026
## Design Source: `Docs/UI_UX Designs/SPINRISE_FSD_M01_PRAmendment_v2_3/SPINRISE_FSD_M01_PRAmendment_v2_3.html`

---

> **CRITICAL RULE:** All UI decisions are locked in the HTML file above.
> Do not invent, simplify, or deviate from the HTML design.
> The API layer (prAmendmentApi.ts) and types (types.ts) are CORRECT — do not change them.
> The backend is NOT part of this task.

---

# ROLE

You are a Senior Frontend Engineer rebuilding the PR Amendment frontend for SPINRISE ERP.
The existing implementation is functionally mostly correct at the API/hook level but diverges significantly from the approved HTML design in terms of toolbar, mode management, header layout, grid columns, and page structure.

Your task: **rewrite the 4 frontend files listed below so the result is pixel-accurate to the approved HTML design, with all operations wired to the existing API.**

---

# SOURCE OF TRUTH

HTML design file (read this before writing any code):
`D:\SpinriseV2\Docs\UI_UX Designs\SPINRISE_FSD_M01_PRAmendment_v2_3\SPINRISE_FSD_M01_PRAmendment_v2_3.html`

Key sections to study in the HTML:
- IST state buttons at top: `setAMDState('add-sel')`, `setAMDState('find-view')`, `setAMDState('mod-loaded')`, `setAMDState('del-loaded')` — these define the 4 live states
- `updateToolbar()` function — defines button enable/disable per mode
- `renderGrid(readOnly)` — defines when grid is editable vs read-only
- `enableNewModeFields()`, `enableModifyModeFields()`, `enableDeleteModeFields()` — field editability per mode
- The delete banner element `#del-banner`
- The footer cards `#form-footer`

---

# FILES TO REWRITE

| File | What changes |
|---|---|
| `src/features/pr/hooks/usePrAmendmentForm.ts` | Mode management rewrite |
| `src/features/pr/pages/PrAmendmentPage.tsx` | Full page rewrite (toolbar + layout) |
| `src/features/pr/components/amendment/PrAmendmentHeader.tsx` | Header fields rewrite |
| `src/features/pr/components/amendment/PrAmendmentLineGrid.tsx` | Grid columns + readonly/edit modes |
| `src/features/pr/components/amendment/PrAmendmentListModal.tsx` | Column fixes |
| `src/features/pr/components/amendment/PrPickerForAmendModal.tsx` | Column fixes |

**DO NOT change:**
- `src/features/pr/api/prAmendmentApi.ts`
- `src/features/pr/types.ts`
- Any backend files
- Any other frontend files not in the list above

---

# GAP REGISTER (all must be resolved)

## GAP-01: TOOLBAR — Missing buttons and navigation

**Current:** New | List | [sep] | Save | Cancel | [sep] | Print

**Required (HTML design):**
```
New (F3)  |  Modify  |  Delete  |  Find  |  [sep]  |  «  ‹  ›  »  |  [sep]  |  Save (Ctrl+S)  |  Print  |  Cancel (Alt+X)
```

Rules:
- "New" button has `kbd` shortcut hint "F3"
- "Delete" button has `danger` outline style (red text, red border)
- "Find" button — standard style, shows active-mode highlight when currently in view mode
- Nav buttons `«  ‹  ›  »` — icon-only, grouped, 28×28px
- "Save" button — blue fill normally; **RED fill** in delete mode
- "Save" label text = "Save" always (not "Confirm Delete")
- "Cancel" has `kbd` hint "Alt+X"
- Keyboard shortcuts: F3=New, Ctrl+S=Save, Alt+X=Cancel (add `useEffect` with `keydown` handler)

## GAP-02: MODE MANAGEMENT — Only 2 modes exist, need 5

**Current modes:** `'new' | 'edit'`

**Required modes:**

```typescript
export type AmendMode = 'none' | 'new' | 'view' | 'modify' | 'delete'
```

Mode descriptions:
| Mode | How entered | What's editable | Save action |
|---|---|---|---|
| `none` | Page load (no records) | Nothing | N/A |
| `new` | Click New → PR picker → PR selected | RefNo, AmendReason, grid lines | POST add amendment |
| `view` | Page load (last record shown), or Find/Nav | Nothing — all read-only | N/A |
| `modify` | Click Modify → Amendment picker → record loaded | RefNo, AmendReason, grid qty/rate/date/machine/cc/remarks | PUT modify |
| `delete` | Click Delete → Amendment picker → record loaded | Nothing — all read-only | DELETE (after confirm dialog) |

**Toolbar button states per mode** (from `updateToolbar()` in HTML):
```
none:    New=on  Modify=off Delete=off Find=on  Nav=off Save=off Cancel=off Print=off
new:     New=off Modify=off Delete=off Find=off Nav=off Save=on  Cancel=on  Print=off
view:    New=on  Modify=on  Delete=on  Find=on  Nav=on  Save=off Cancel=off Print=on
modify:  New=off Modify=on* Delete=off Find=off Nav=off Save=on  Cancel=on  Print=off
delete:  New=off Modify=off Delete=on* Find=off Nav=off Save=on  Cancel=on  Print=off
```
`*` = button is enabled but shows `active-mode` CSS highlight (blue tint background)

**Hook method changes needed:**
- `enterNew()` — reset form, set mode='new', open PR picker
- `enterModify()` — reset form, set mode='modify', open Amendment picker
- `enterDelete()` — reset form, set mode='delete', open Amendment picker
- `enterFind()` — same as view, open Amendment picker, set mode='view'
- `doSave()` — if mode='delete' → show confirm dialog then call `api.deleteAmendment()`, else validate+save
- `doCancel()` — if has loaded record → reload it and switch to view mode; else → resetForm to none
- `navFirst()`, `navPrev()`, `navNext()`, `navLast()` — navigate AMEND_DATA array by index

**Navigation state needed:**
```typescript
const [navList, setNavList] = useState<AmendmentSummary[]>([])  // fetched list for nav
const [navIdx,  setNavIdx]  = useState(-1)
```
On page load, fetch list and show last record in view mode. Nav buttons step through `navList`.

## GAP-03: HEADER — Wrong layout, wrong field types, missing section header

**Required layout (3 rows, from HTML):**

```
Section header: "📅 Amendment Details"  [date pill: "25 May 2026"]    Created by: KALSOFTE
─────────────────────────────────────────────────────────────────────
Row 1: [Amendment No. 128px] [Amendment Date 148px] [PR No. * 175px + Find btn] [PR Date 148px]
Row 2: [Department flex] [PR Type 128px] [Requester Name flex] [Section 148px]
Row 3: [Reference No. 148px] [Amendment Reason * flex xl]
─────────────────────────────────────────────────────────────────────
Hint: Tab — move between fields  |  Ctrl+S — save
```

**Field types (all are plain `<input>` with `disabled` prop, NOT Ant Design Form items except editable ones):**

| Field | Type | Editable in mode | Notes |
|---|---|---|---|
| Amendment No. | text input, disabled always | never | Monospace font, placeholder "Auto-generated" |
| Amendment Date | text input, disabled always | never | Shows value from record, placeholder today's date |
| PR No. | text input + Find button | new mode only | Blue text color when has value; Find button opens PR picker |
| PR Date | text input, disabled always | never | — |
| Department | text input, disabled always | never | Shows "CODE – NAME" format |
| PR Type | text input, disabled always | never | — |
| Requester Name | text input, disabled always | never | Shows "CODE – NAME" format |
| Section | text input, disabled always | never | — |
| Reference No. | text input | new + modify modes | maxLength=30 |
| Amendment Reason | text input | new + modify modes | required (*), maxLength=200, placeholder "Enter amendment reason…" |

**Style spec from HTML:**
- Section header background: `#fff`, border-bottom: `1px solid #e2e2e2`
- Section header padding: `9px 16px`, height `auto`
- Date pill: `background:#E6F1FB; color:#185FA5; font-size:11px; font-weight:600; padding:2px 9px; border-radius:20px`
- Form fields area padding: `12px 16px 8px`
- Field label: `font-size:11px; font-weight:500; color:#888888`
- Field control height: `30px`, `border:1px solid #e2e2e2`, `border-radius:4px`, `font-size:12px`
- Disabled field background: `#F5F5F3`
- Find button: `height:30px; padding:0 10px; color:#185FA5; font-size:11px; font-weight:700; border:1px solid #e2e2e2; border-radius:4px`
- Find button disabled: `opacity:0.38`

**Do NOT use:** `<DatePicker>`, `<Form>`, `<Form.Item>`, `<Col>`, `<Row>` from Ant Design for these fields. Use plain native `<input>` elements styled to match the HTML design. Only use Ant Design `<Input>` for the editable fields (RefNo, AmendReason) if preferred for controlled input behavior.

## GAP-04: GRID — Missing columns

**HTML Design column order:**
```
# | Item Id | Item Name | Unit | Curr. Stock | Qty Required * | Rate | ₹ Approx. Value | Qty Approved | Qty Ordered | Qty Received | Required Date | Machine | Sub Cost Centre | Remarks | PR Status | [×]
```

**Currently missing columns that must be added:**
1. **Curr. Stock** — read-only, after Unit, 3dp right-aligned monospace. Source: `row.curStock`
2. **Qty Approved** — read-only, after ₹ Approx. Value, 3dp right-aligned. Source: `row.qtyApproved`. Show `—` if 0.
3. **Qty Ordered** — read-only, after Qty Approved, 3dp right-aligned. Source: `row.qtyOrdered`. Show `—` if 0.
4. **Qty Received** — read-only, after Qty Ordered, 3dp right-aligned. Source: `row.qtyReceived`. Show `—` if 0.
5. **PR Status** — read-only, after Remarks, shows colored badge. Source: `row.lineStatus`

**Badge colors for PR Status:**
- `'Requested'` → blue background (`#E6F1FB`, text `#185FA5`)
- `'Approved'` → green background (`#EAF3DE`, text `#3B6D11`)
- `'Ordered'` → orange background (`#FAEEDA`, text `#BA7517`)
- other → grey

**Column name fixes:**
- Change "Item Description" → "Item Name"
- Change "Required Quantity" → "Qty Required"

**Delete button per row:**
- HTML design shows a single `✕` button, styled `.cell-del`: `width:26px; height:26px; border:none; background:none; cursor:pointer; color:#888`
- Hover: `background:#FCEBEB; color:#A32D2D`
- Disabled (in readonly mode): `opacity:0; cursor:default`
- **Remove** the Eye icon/View drawer — not in HTML design. The extra details (rateSource, justification, catCode, bgrpCode, place) are secondary and should be removed from grid area since they're not in the HTML design.

**Grid read-only vs editable per mode:**
- `view`: entire grid read-only (no editable inputs, no delete button visible)
- `none`: grid hidden, show empty state
- `new`: editable (Qty Required, Rate, Required Date, Machine, Sub Cost Centre, Remarks are editable per row; delete button enabled)
- `modify`: same as new
- `delete`: entire grid read-only (no editable inputs, delete button disabled)

**Remove click-to-edit row concept.** In edit modes (new/modify), ALL rows are simultaneously editable — no click-to-activate editing. Editable cells use inline inputs directly like the HTML design.

**Inline cell input styles (from HTML):**
```css
height: 26px; border: 1px solid #e2e2e2; border-radius: 3px; padding: 0 6px;
font-size: 11px; font-family: monospace; color: #1a1a1a; background: #fff;
outline: none;
```
Focus: `border-color: #185FA5; background: #f8fbff`
Disabled: `background: #F5F5F3; color: #888; border-color: transparent`

## GAP-05: DELETE BANNER — Missing

Add a red banner below the toolbar, visible only in `delete` mode:
```
⚠ Delete mode — Amendment <strong>AMD-0001</strong> · All fields are read-only. Click Save to confirm deletion.
```
Style: `background:#FCEBEB; border-bottom:2px solid #A32D2D; padding:8px 16px; font-size:12px; color:#A32D2D; font-weight:500`

## GAP-06: FOOTER — Missing

Add a footer bar below the grid, visible when grid is showing:
```
[ Total Lines ]  [ Total Quantity ]
[ count ]        [ Nos: X.XXX   ]
[ Items in this ][ By Unit of   ]
[ amendment     ][ Measure      ]
```
Style (each card): `flex:1; padding:10px 20px; border-right:1px solid #e2e2e2`
Value: `font-size:18px; font-weight:700; color:#1a1a1a`
Label: `font-size:10px; font-weight:600; color:#888; text-transform:uppercase; letter-spacing:.05em`
Sub: `font-size:10px; color:#888; margin-top:1px`

Total Quantity shows sum of `qtyInd` across all lines with `Nos: X.XXX` format.

## GAP-07: EMPTY STATE — Mode-aware

Show empty state in grid section when no record loaded:
- `none` mode: icon ✏️, title "No amendment loaded", sub: `Click <strong>New</strong> (F3) to create a new amendment, or <strong>Modify</strong> / <strong>Delete</strong> to load an existing one.`
- `new` mode (before PR selected): icon ✏️, title "No PR selected", sub: "Select a PR from the popup to create a new amendment."
- `modify` mode (before record selected): same pattern
- `delete` mode (before record selected): same pattern

## GAP-08: DOC BAND — Format fix

Current: `AMEND-${header.amendNo}`
Required: `AMD-${String(header.amendNo).padStart(4, '0')}`

When no record: show `Auto-generated on save`

## GAP-09: FIND PR MODAL COLUMNS — Fix

**Required columns (HTML design):**
```
PR No. | PR Date | Department | Requester | PR Type | Lines | Prior Amendments
```

**Fix `PrPickerForAmendModal.tsx`:**
- Rename "Type" → "PR Type"
- Remove "Status" column
- Add "Lines" column — source: `prSummary.totalLines` (check type, add if missing)
- Add "Prior Amendments" column — source: `prSummary.priorAmendments` (check type, add if missing; show "None" if 0)
- Note: If `totalLines` and `priorAmendments` are not in `PrSummary` type, they may not come from API yet. Add them to the type only if the API already returns them; otherwise show `—` placeholder.

## GAP-10: FIND AMENDMENT MODAL COLUMNS — Fix

**Required columns (HTML design):**
```
Amend No. | PR No. | Amend Date | Department | Reason | Lines
```

**Fix `PrAmendmentListModal.tsx`:**
- Column order: Amend No. first, then PR No., Amend Date, Department, Reason, Lines
- Remove "Requester", "PR Date" columns
- Add "Lines" column — source: `AmendmentSummary.totalLines`
- Double-click on row = select immediately (same as single click, but add onRow with onDoubleClick)
- Add a "Load →" button in the modal footer (enabled when a row is selected)

---

# IMPLEMENTATION RULES

## Styling approach
Use inline styles only — no new CSS classes. Match the HTML design's color tokens:
```typescript
const C = {
  blue:     '#185FA5',
  blueDark: '#0C447C',
  blue100:  '#E6F1FB',
  bg:       '#F5F5F3',
  border:   '#E2E2E2',
  text900:  '#1A1A1A',
  text600:  '#4A4A4A',
  text400:  '#888888',
  error:    '#A32D2D',
  errorL:   '#FCEBEB',
  success:  '#3B6D11',
  successL: '#EAF3DE',
  warning:  '#BA7517',
  warningL: '#FAEEDA',
}
```

## Component architecture
Keep the same file structure. Do not create new files.

## No Ant Design Form/DatePicker for header fields
Header fields are plain `<input>` elements. Use Ant Design `<Input>` only where the HTML uses an editable free-text field (Reference No., Amendment Reason). Do NOT use `<DatePicker>` for Amendment Date — it's always disabled, just show the date string.

## Grid implementation
Do NOT use AG Grid. Use native `<table>` with inline inputs (as in the HTML design). The existing implementation already uses native table — keep this approach and add the missing columns.

## Confirm dialog for delete
Use Ant Design `Modal.confirm()` when Save is clicked in delete mode:
```typescript
Modal.confirm({
  icon: null,
  title: 'Confirm Delete',
  content: `This will permanently delete Amendment ${amendLabel} and all its line items. This cannot be undone.`,
  okText: 'Confirm Delete',
  okButtonProps: { danger: true },
  onOk: async () => { await doDeleteAmend() }
})
```

## Loading states
Show Ant Design `<Spin>` spinner over the header form when `loading=true`.

## Nav list management
```typescript
// In usePrAmendmentForm hook:
// navList = full list from getAmendmentList, loaded on mount and after each save/delete
// navIdx  = index in navList of currently displayed record
// navTo(idx) = load record at navList[idx]
```

---

# EXACT TOOLBAR LAYOUT (copy this pattern)

```tsx
// Toolbar JSX structure
<div style={{ display:'flex', alignItems:'center', gap:4, padding:'6px 16px', background:'#fff', borderBottom:'1px solid #e2e2e2', flexShrink:0 }}>
  {/* New */}
  <button style={tbBtn} disabled={!canNew} onClick={handleNew}>
    + <span>New</span><kbd style={kbdStyle}>F3</kbd>
  </button>
  {/* Modify */}
  <button style={mode==='modify' ? {...tbBtn, ...activeModeStyle} : tbBtn} disabled={!canModify} onClick={handleModify}>
    ✎ <span>Modify</span>
  </button>
  {/* Delete */}
  <button style={{...tbBtn, ...dangerOutlineStyle}} disabled={!canDelete} onClick={handleDelete}>
    🗑 <span>Delete</span>
  </button>
  {/* Find */}
  <button style={mode==='view' ? {...tbBtn, ...activeModeStyle} : tbBtn} disabled={!canFind} onClick={handleFind}>
    ≡ <span>Find</span>
  </button>
  <div style={tbSep} />
  {/* Nav group */}
  <div style={{ display:'flex' }}>
    <button style={navBtn} disabled={!canNav || navIdx<=0} onClick={handleNavFirst} title="First">«</button>
    <button style={{...navBtn, borderLeft:'none'}} disabled={!canNav || navIdx<=0} onClick={handleNavPrev} title="Previous">‹</button>
    <button style={{...navBtn, borderLeft:'none'}} disabled={!canNav || navIdx>=navList.length-1} onClick={handleNavNext} title="Next">›</button>
    <button style={{...navBtn, borderLeft:'none'}} disabled={!canNav || navIdx>=navList.length-1} onClick={handleNavLast} title="Last">»</button>
  </div>
  <div style={tbSep} />
  {/* Save */}
  <button
    style={mode==='delete' ? {...tbBtn, ...saveDangerStyle} : {...tbBtn, ...savePrimaryStyle}}
    disabled={!canSave}
    onClick={handleSave}
  >
    ✓ <span>Save</span><kbd style={kbdStyle}>Ctrl+S</kbd>
  </button>
  {/* Print */}
  <button style={tbBtn} disabled={!canPrint} onClick={handlePrint}>
    🖨 <span>Print</span>
  </button>
  {/* Cancel */}
  <button style={tbBtn} disabled={!canCancel} onClick={handleCancel}>
    ✕ <span>Cancel</span><kbd style={kbdStyle}>Alt+X</kbd>
  </button>
</div>
```

Toolbar button style tokens:
```typescript
const tbBtn: React.CSSProperties = {
  display: 'inline-flex', alignItems: 'center', gap: 5, padding: '5px 12px',
  borderRadius: 5, border: '1px solid #e2e2e2', background: '#fff',
  fontSize: 12, fontWeight: 500, cursor: 'pointer', color: '#4A4A4A',
  whiteSpace: 'nowrap', fontFamily: 'inherit',
}
const dangerOutlineStyle: React.CSSProperties = { color: '#A32D2D', borderColor: '#A32D2D' }
const activeModeStyle: React.CSSProperties = { background: '#E6F1FB', color: '#185FA5', borderColor: '#a8c8ea', fontWeight: 600 }
const savePrimaryStyle: React.CSSProperties = { background: '#185FA5', color: '#fff', borderColor: '#185FA5' }
const saveDangerStyle:  React.CSSProperties = { background: '#A32D2D', color: '#fff', borderColor: '#A32D2D' }
const kbdStyle: React.CSSProperties = {
  fontFamily: 'monospace', fontSize: 9, fontWeight: 700,
  background: 'rgba(0,0,0,.07)', padding: '1px 4px', borderRadius: 3,
}
const navBtn: React.CSSProperties = {
  display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
  width: 28, height: 28, border: '1px solid #e2e2e2', background: '#fff',
  cursor: 'pointer', color: '#4A4A4A', fontSize: 13, fontFamily: 'inherit',
}
```

---

# EXACT HEADER LAYOUT (copy this pattern)

```tsx
// Form section
<div style={{ background:'#fff', borderBottom:'1px solid #e2e2e2', flexShrink:0 }}>
  {/* Section header */}
  <div style={{ display:'flex', alignItems:'center', justifyContent:'space-between', padding:'9px 16px', borderBottom:'1px solid #e2e2e2' }}>
    <div style={{ display:'flex', alignItems:'center', gap:8 }}>
      <span style={{ fontSize:14 }}>📅</span>
      <span style={{ fontSize:13, fontWeight:600, color:'#1A1A1A' }}>Amendment Details</span>
      <span style={{ background:'#E6F1FB', color:'#185FA5', fontSize:11, fontWeight:600, padding:'2px 9px', borderRadius:20 }}>
        {todayDisplay}  {/* e.g. "28 May 2026" */}
      </span>
    </div>
    <span style={{ fontSize:11, color:'#888' }}>
      Created by <strong style={{ color:'#4A4A4A' }}>{header?.createdBy || user?.username || '—'}</strong>
    </span>
  </div>
  
  {/* Fields */}
  <div style={{ padding:'12px 16px 8px' }}>
    {/* Row 1 */}
    <div style={{ display:'flex', gap:14, flexWrap:'wrap', marginBottom:8 }}>
      <FieldGroup label="Amendment No." width={128}>
        <input style={{...fieldCtrl, fontFamily:'monospace', fontWeight:600}} value={header ? `AMD-${String(header.amendNo).padStart(4,'0')}` : ''} disabled placeholder="Auto-generated" readOnly />
      </FieldGroup>
      <FieldGroup label="Amendment Date" width={148}>
        <input style={fieldCtrl} value={header?.amendDate || processingDateDisplay} disabled readOnly />
      </FieldGroup>
      <FieldGroup label="PR No." required width={175}>
        <div style={{ display:'flex', gap:3 }}>
          <input style={{...fieldCtrl, flex:1, color: header?.prNo ? '#185FA5' : undefined, fontFamily:'monospace', fontWeight:600}} value={header?.prNo ? String(header.prNo) : ''} disabled readOnly placeholder="PR number" />
          <button style={findBtn} disabled={mode !== 'new'} onClick={() => setPrPickerOpen(true)}>Find</button>
        </div>
      </FieldGroup>
      <FieldGroup label="PR Date" width={148}>
        <input style={fieldCtrl} value={header?.prDate || ''} disabled readOnly placeholder="—" />
      </FieldGroup>
    </div>
    
    {/* Row 2 */}
    <div style={{ display:'flex', gap:14, flexWrap:'wrap', marginBottom:8 }}>
      <FieldGroup label="Department" flex>
        <input style={fieldCtrl} value={header ? `${header.depCode} – ${header.depName}` : ''} disabled readOnly placeholder="—" />
      </FieldGroup>
      <FieldGroup label="PR Type" width={128}>
        <input style={fieldCtrl} value={header?.iDesc || header?.iType || ''} disabled readOnly placeholder="—" />
      </FieldGroup>
      <FieldGroup label="Requester Name" flex>
        <input style={fieldCtrl} value={header ? `${header.depCode} – ${header.reqEmpName || header.reqName}` : ''} disabled readOnly placeholder="—" />
      </FieldGroup>
      <FieldGroup label="Section" width={148}>
        <input style={fieldCtrl} value={header?.section || ''} disabled readOnly placeholder="—" />
      </FieldGroup>
    </div>
    
    {/* Row 3 */}
    <div style={{ display:'flex', gap:14, flexWrap:'wrap' }}>
      <FieldGroup label="Reference No." width={148}>
        <input style={fieldCtrl} value={refNo} disabled={!canEditHeaderFields} maxLength={30} placeholder="Optional" onChange={e => setRefNo(e.target.value)} />
      </FieldGroup>
      <FieldGroup label="Amendment Reason" required flex xl>
        <input style={{...fieldCtrl, ...(reasonError ? {borderColor:'#A32D2D'} : {})}} value={amendReason} disabled={!canEditHeaderFields} maxLength={200} placeholder="Enter amendment reason…" onChange={e => setAmendReason(e.target.value)} />
      </FieldGroup>
    </div>
    
    <div style={{ fontSize:10, color:'#888', marginTop:4 }}>
      <span style={{ marginRight:12 }}>Tab — move between fields</span>
      <span>Ctrl+S — save</span>
    </div>
  </div>
</div>
```

For the `FieldGroup` helper component:
```tsx
function FieldGroup({ label, required, width, flex, xl, children }: {
  label: string; required?: boolean; width?: number; flex?: boolean; xl?: boolean; children: React.ReactNode
}) {
  const style: React.CSSProperties = flex
    ? xl ? { flex: '2 1 260px', minWidth: 0 } : { flex: '1 1 190px', minWidth: 0 }
    : { flex: `0 0 ${width}px` }
  return (
    <div style={{ display:'flex', flexDirection:'column', gap:3, ...style }}>
      <span style={{ fontSize:11, fontWeight:500, color:'#888', lineHeight:1 }}>
        {label}{required && <span style={{ color:'#A32D2D', marginLeft:1 }}>*</span>}
      </span>
      {children}
    </div>
  )
}
```

Field control style:
```typescript
const fieldCtrl: React.CSSProperties = {
  height: 30, border: '1px solid #e2e2e2', borderRadius: 4, padding: '0 8px',
  fontSize: 12, fontFamily: 'inherit', color: '#1A1A1A', background: '#fff',
  width: '100%', outline: 'none',
}
// For disabled: add background: '#F5F5F3', color: '#4A4A4A'
// Apply disabled background when the field's disabled prop is true
```

Find button:
```typescript
const findBtn: React.CSSProperties = {
  height: 30, padding: '0 10px', border: '1px solid #e2e2e2', borderRadius: 4,
  background: '#fff', color: '#185FA5', fontSize: 11, fontWeight: 700,
  cursor: 'pointer', whiteSpace: 'nowrap', fontFamily: 'inherit', flexShrink: 0,
}
// disabled: { opacity: 0.38, cursor: 'not-allowed' }
```

---

# AMENDMENT HEADER STATE IN PAGE

Since the header fields (RefNo, AmendReason) are now managed as local state in `PrAmendmentPage.tsx` (not Ant Design Form), manage them as `useState`:

```typescript
const [refNo,       setRefNo]       = useState('')
const [amendReason, setAmendReason] = useState('')
const [reasonError, setReasonError] = useState(false)
```

Populate from hook's `header` when a record loads:
```typescript
useEffect(() => {
  if (header) {
    setRefNo(header.refNo ?? '')
    setAmendReason(header.amendmentReason ?? '')
    setReasonError(false)
  } else {
    setRefNo('')
    setAmendReason('')
  }
}, [header])
```

Pass `refNo` and `amendReason` to `doSave()` as parameters (update the hook signature accordingly).

`canEditHeaderFields = mode === 'new' || mode === 'modify'`

---

# HOOK SIGNATURE CHANGES

Update `usePrAmendmentForm` to:

```typescript
// 1. Export 5-mode type
export type AmendMode = 'none' | 'new' | 'view' | 'modify' | 'delete'

// 2. Add nav state
const [navList, setNavList] = useState<AmendmentSummary[]>([])
const [navIdx,  setNavIdx]  = useState(-1)

// 3. Remove Form usage — header fields managed in Page
// Remove: const [form] = Form.useForm()

// 4. doSave signature change
const doSave = async (refNo: string, amendReason: string): Promise<boolean>

// 5. New methods
const enterNew    = () => { resetForm(); setMode('new') }
const enterModify = () => { resetForm(); setMode('modify') }  // caller opens picker
const enterDelete = () => { resetForm(); setMode('delete') }  // caller opens picker
const enterFind   = () => { resetForm(); setMode('view') }    // caller opens picker
const navTo       = async (idx: number) => { /* load navList[idx] */ }
const navFirst    = async () => navTo(0)
const navPrev     = async () => navTo(navIdx - 1)
const navNext     = async () => navTo(navIdx + 1)
const navLast     = async () => navTo(navList.length - 1)

// 6. doDelete (called by page after user confirms)
const doDelete = async (): Promise<boolean>

// 7. loadForNew now sets mode='new'
// 8. loadById now sets mode='view' (page switches to modify/delete after picker closes)
```

---

# GRID COLUMN WIDTHS (from HTML)

```
# = 36px | Item Id = 88px | Item Name = min 175px | Unit = 48px (center)
Curr. Stock = 82px (right) | Qty Required = 100px (right) | Rate = 88px (right)
₹ Approx. Value = 95px (right) | Qty Approved = 88px (right) | Qty Ordered = 88px (right)
Qty Received = 88px (right) | Required Date = 112px | Machine = min 115px
Sub Cost Centre = min 135px | Remarks = min 105px | PR Status = 88px (center)
[delete] = 32px
```

---

# STAGE 1 SELF-CHECK (run mentally before declaring done)

```
TOOLBAR:
  [ ] New / Modify / Delete / Find buttons present and correctly styled
  [ ] Nav buttons «‹›» present and grouped
  [ ] Save is blue fill normally, RED fill in delete mode
  [ ] Delete button is red outline (danger style)
  [ ] Find button shows active-mode tint in view mode
  [ ] All buttons disabled correctly per mode (see GAP-02 table)
  [ ] F3 = New, Ctrl+S = Save, Alt+X = Cancel keyboard shortcuts work

MODES:
  [ ] none — blank state, toolbar shows New + Find enabled only
  [ ] new — PR picker opens, then PR loads, grid editable, refNo+reason editable
  [ ] view — all read-only, print enabled, nav enabled
  [ ] modify — Amendment picker opens, then record loads, grid+header fields editable
  [ ] delete — Amendment picker opens, then record loads, all read-only, banner shown, save=red
  [ ] Cancel in new (no record): clears to none state
  [ ] Cancel with record loaded: reloads record → view mode

HEADER:
  [ ] Section header "📅 Amendment Details" + date pill + "Created by" present
  [ ] Row 1: Amendment No | Amendment Date | PR No + Find btn | PR Date
  [ ] Row 2: Department | PR Type | Requester | Section
  [ ] Row 3: Reference No | Amendment Reason
  [ ] Field heights 30px, labels 11px
  [ ] Disabled fields show grey background (#F5F5F3)
  [ ] Find button only active in new mode
  [ ] Amendment No shows AMD-XXXX format

GRID:
  [ ] All 17 columns present in correct order
  [ ] Curr. Stock visible in grid (not just drawer)
  [ ] Qty Approved / Ordered / Received visible (show — when 0)
  [ ] PR Status badge visible with correct colors
  [ ] In view/delete: all cells are plain text (no inputs visible)
  [ ] In new/modify: Qty Required, Rate, Date, Machine, CC, Remarks are editable inputs
  [ ] Row delete × button visible in new/modify, hidden/disabled in view/delete
  [ ] No click-to-edit row concept — all rows editable simultaneously in edit modes
  [ ] Add-row row shown in new/modify at bottom

DELETE BANNER:
  [ ] Red banner shown in delete mode with amendment number

FOOTER:
  [ ] Total Lines count card shown when grid has data
  [ ] Total Quantity (sum of qtyInd) shown

DOC BAND:
  [ ] Shows AMD-XXXX format (zero padded)
  [ ] Shows "Auto-generated on save" when no record

MODALS:
  [ ] Find PR modal shows: PR No. | PR Date | Department | Requester | PR Type | Lines | Prior Amendments
  [ ] Find Amendment modal shows: Amend No. | PR No. | Amend Date | Department | Reason | Lines
  [ ] Both modals have a "Load →" / "Select →" footer button

NAVIGATION:
  [ ] First/Prev/Next/Last navigate through navList
  [ ] Nav buttons disabled when at boundaries or in edit mode
```

---

# EXECUTION ORDER

Execute files in this order (each must compile before proceeding):

1. `usePrAmendmentForm.ts` — mode management + nav + doSave signature change
2. `PrAmendmentPage.tsx` — full rewrite (toolbar, layout, mode orchestration)
3. `PrAmendmentHeader.tsx` — header rewrite (plain inputs, 3-row layout)
4. `PrAmendmentLineGrid.tsx` — add missing columns, remove click-to-edit, add footer
5. `PrPickerForAmendModal.tsx` — column fixes
6. `PrAmendmentListModal.tsx` — column fixes

After each file, run TypeScript type-check mentally. The types in `types.ts` are final — adapt to them, do not change them.
