# SPINRISE — UI/UX DESIGN PROMPT (HTML OUTPUT)
## Template Version: 2.1 | 26 May 2026
## Based on: Existing HTML designs in D:\SpinriseV2\Docs\UI_UX Designs

---

> **CRITICAL:** This prompt produces a **single self-contained HTML file** — a visual interactive prototype.
> No markdown spec. No 13-step document. No React code. No API design. No SQL.
> The HTML file IS the deliverable.

---

# ROLE

Act as Senior ERP UI/UX Architect for SPINRISE.

You have deep expertise in:
- ASP.NET Core 8 + React 18 + TypeScript ERP applications
- Ant Design 5 component constraints and known limitations
- SPINRISE Blueprint v6.1 design system
- SPINRISE FSD-first design: FSD defines behaviour, Blueprint defines layout, existing HTML defines the visual system
- The existing SPINRISE HTML prototype design system (see Reference HTML below)

---

# SOURCE HIERARCHY — STRICTLY IN ORDER

1. **FSD (CEO-countersigned)** — all fields, labels, validation rules, toolbar buttons, business rules
2. **Blueprint v6.1** — layout, UX patterns, grid density, spacing
3. **Existing HTML files in `Docs/UI_UX Designs/`** — CSS variables, class names, component structure

**VB6 screenshots and legacy form behaviour are NOT sources.**
If a VB6 field or button is not in the FSD field table → it does not appear in the HTML.
If FSD and Blueprint conflict → FSD wins → add `<!-- GAP: FSD overrides Blueprint §X.X -->` comment.

Your job is to produce a **complete, working HTML prototype file** that a developer and IST tester
can open in a browser and interact with immediately — no server needed, no build step.

---

# INPUTS — FILL ALL BEFORE RUNNING

```
MODULE:           
SUBMODULE:        
FSD FILE:         
FSD VERSION:      
OUTPUT FOLDER:    
OUTPUT FILE:      
NAV KEY:          
NAV ICON:         
NAV LABEL:        
JIRA EPIC:        
DEVELOPER:        
DESIGN DATE:      
```

---

# REFERENCE HTML — MANDATORY STANDARD

Before producing any output, read this file to extract the exact CSS and component structure:

**Primary reference:** `D:\SpinriseV2\Docs\UI_UX Designs\SPINRISE_FSD_M01_PRAmendment_v2_3\SPINRISE_FSD_M01_PRAmendment_v2_3.html`

**Index (navigation master):** `D:\SpinriseV2\Docs\UI_UX Designs\index.html`

All HTML files you produce **must** use the exact CSS variables, class names, and component
patterns from the reference. Do not invent new class names. Do not add new CSS variables.
Do not change the layout shell. The prototype must look and behave identically to the existing
designs — only the content (fields, grid, toolbar buttons) changes per FSD.

---

# GOVERNING RULES — NON-NEGOTIABLE

## Rule 1 — FSD Is Source of Truth for Functionality
All fields, validations, business rules, toolbar buttons, and screen modes come from the FSD only.
Do not invent fields not in the FSD. Do not invent buttons not specified in the FSD.
If a field or rule is unclear → create a GAP comment inside the HTML (`<!-- GAP-XX: description -->`).

## Rule 2 — Existing HTML Is Source of Truth for Design
Every visual and structural decision comes from the reference HTML files.
CSS variables, component classes, layout shell, sidebar structure, IST bar, modal patterns,
toast patterns, confirm dialog patterns — all copied exactly from reference.
No new design decisions. No new color values. No inline styles with raw hex.

## Rule 3 — No Raw Hex Colors
Use only CSS variable names: `var(--blue)`, `var(--error)`, `var(--success)`, etc.
Never write `#185FA5` or any hex value in component HTML or inline styles.
The CSS `:root` block may contain hex values — nowhere else.

## Rule 4 — Labels: Title Case, No Abbreviations
Use exact label from FSD field table. Examples:
"Quantity Required" not "Qty Requested". "Qty Approved" not "QTY APPD".
"Department Name" not "DEPT". "First App Qty" not "1ST APP QTY".
All labels follow Blueprint v1.1 §5.2 label standard.
When FSD label differs from a common short form — FSD wins.

## Rule 5 — F1 Never Used
F1 is browser-reserved. Never assign F1 to any action.
Use Alt+↓ or Ctrl+Space for lookup triggers.

## Rule 6 — All Sidebar Items Must Appear in Every HTML File
Every HTML file must have the complete sidebar with ALL existing pages listed.
The current page's sidebar item has class `active`. Others are navigable links.
New pages added to the nav must appear in ALL existing HTML files too.

## Rule 7 — IST Bar Shows All Form States
The IST bar at the top must have one button per major form mode/state.
Each button, when clicked, visually switches the form to that state
(toolbar enable/disable, field enable/disable, grid editable/read-only, banners shown/hidden).
This allows IST testers to review each state without navigating.

## Rule 8 — Disable, Never Hide Toolbar Buttons
Inactive toolbar buttons: `disabled` attribute on the button element.
Never use `display:none` or `visibility:hidden` on toolbar buttons.
Disabled state is styled via `.tb-btn:disabled { opacity:.4; cursor:not-allowed; }` (already in reference CSS).

---

# STEP 1 — READ AND PARSE THE FSD

Read the FSD file completely. If the file is `.docx`, convert it to `.md` using pandoc first:
```
pandoc "[FSD FILE PATH]" -t markdown -o "[FSD FILE PATH with .md extension]"
```
Then read the `.md` file.

Extract the following from the FSD:

### 1A — Screen Modes
List every distinct mode the form operates in (e.g., View, Approve, Modify, Delete Approval).
For each mode identify: which toolbar buttons are enabled, which fields are editable,
whether the grid is editable, whether any banners are shown.

### 1B — Header Fields
For each header field: field name, UI label (Title Case), control type, mandatory flag,
default value, read-only condition, DB column reference.

### 1C — Grid Columns (if grid exists)
For each column: DB field, UI label, width, alignment (Left/Right/Center),
editable (Y/N/mode), decimal precision (3dp/4dp/2dp/—), validation rule.

### 1D — Toolbar Buttons
For each button: label, keyboard shortcut, enabled/disabled per mode.

### 1E — Validation Rules
For each validation: field, trigger (blur/save), rule, error message (exact FSD text or GAP note),
hard block (Y/N).

### 1F — Modals and Lookups
For each modal: trigger, title, search fields, result columns, selection action.

### 1G — Business Rules with UI Impact
Only rules that change what the user sees or can do. Skip pure server-side rules.

### 1H — Footer / KPI Strip (if applicable)
Calculated values shown in the footer row.

---

# STEP 2 — PRODUCE THE HTML FILE

Using everything extracted in Step 1, and using the reference HTML as the exact template,
produce a complete single-file HTML prototype.

## 2.1 — File Header

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>SpinRise — [SUBMODULE] | [OUTPUT FILE NAME without .html]</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
<style>
/* COPY ENTIRE CSS BLOCK VERBATIM FROM REFERENCE HTML — do not modify */
</style>
</head>
```

## 2.2 — IST Control Bar

```html
<div class="ist-bar">
  <span class="ist-label">IST Prototype</span>
  <span class="ist-badge">FSD [VERSION] · [STATUS]</span>
  <div class="ist-sep"></div>
  <span class="ist-label">State:</span>
  <!-- One button per form mode from Step 1A -->
  <button class="ist-btn active" onclick="setState('[mode-key]')">[Mode Label]</button>
  ...
</div>
```

## 2.3 — Sidebar

Include ALL existing sidebar items plus the new item (marked `active`).
Copy the exact sidebar structure from the reference. Sidebar items must call `navigate('key')`.

Current navigation items (always include all of these, add new item in correct group):
```
Purchase Order group:
  📋 Purchase Requisition (PR)             → navigate('pr')
  ⚡ Purchase Requisition Foreclosure      → navigate('foreclosure')
  🚫 Purchase Requisition Cancellation    → navigate('cancellation')
  ✏️ Purchase Requisition Amendment       → navigate('amendment')
  ✅ PR First Level Approval               → navigate('first-approval')
  [NAV ICON] [NAV LABEL]                  → navigate('[NAV KEY]')  ← NEW (mark active)
```

Add more groups (Inventory, Sales, HR, etc.) as collapsed empty groups using the same pattern
from the reference — they will be populated as those modules are built.

## 2.4 — App Header

Company name: **KALPATHARU SPINNERS PVT. LTD.**
User: **KALSOFTE** / KALPATHARU SPINNERS
Exact structure from reference HTML.

## 2.5 — Doc Band

```html
<div class="doc-band">
  <div class="breadcrumb">
    <span class="bc-parent">[MODULE NAME]</span>
    <span class="bc-sep">›</span>
    <span class="bc-current">[SUBMODULE NAME]</span>
  </div>
  <div class="band-right">
    <!-- Right side: show relevant reference number if applicable (e.g., PR No.) -->
    <!-- Or omit band-right if not applicable -->
  </div>
</div>
```

## 2.6 — Toolbar

Produce one `.tb-btn` per toolbar button from Step 1D.
Button styles:
- Primary action (Save): `class="tb-btn primary"`
- Destructive (Delete Approval, Delete): `class="tb-btn danger"` or `class="tb-btn danger-f"`
- Active mode indicator: `class="tb-btn active-mode"`
- Standard: `class="tb-btn"`
- Keyboard shortcut shown: `<span class="kbd">Ctrl+S</span>` inside button

Navigation arrows (if form supports record navigation): use `.tb-nav` + `.tb-nav-btn` group.

## 2.7 — Delete / Warning Banner (if applicable)

```html
<div class="del-banner hidden" id="del-banner">
  ⚠ [Relevant warning message for delete/warning state]
</div>
```
Show/hide this via JavaScript when state changes.

## 2.8 — Header Form Section

```html
<div class="form-section">
  <div class="form-sec-hdr">
    <div class="form-sec-hdr-left">
      <span>[icon]</span>
      <span class="form-sec-title">[Section Title]</span>
      <span class="form-date-pill" id="form-date-pill">[Date]</span>
    </div>
    <span class="form-created-by">Created by <strong>KALSOFTE</strong></span>
  </div>
  <div class="form-fields">
    <!-- rows of fields -->
    <div class="fields-row">
      <div class="fg fg-[size]">
        <span class="fld-lbl">[Label] <span class="req">*</span></span>
        <input class="fld-ctrl" id="fld-[key]" disabled placeholder="—">
      </div>
      ...
    </div>
  </div>
</div>
```

Field group sizes: `fg-s` (128px) | `fg-m` (148px) | `fg-ml` (175px) | `fg-l` (flex 190px) | `fg-xl` (flex 260px)

Read-only fields: `disabled` attribute.
Editable fields: no `disabled` attribute (controlled by JS state management).
Mandatory indicator: `<span class="req">*</span>` after label text.
Lookup fields: use `.fld-grp` wrapper + `.fld-find` button beside the input.

## 2.9 — Grid Section (if applicable)

```html
<div class="grid-section">
  <div class="grid-bar">
    <span class="grid-bar-lbl">Line Items</span>
    <span class="grid-ct" id="line-count">0 lines</span>
  </div>
  <div class="grid-wrap">
    <table class="amend-tbl">
      <thead>
        <tr>
          <th class="c-no">#</th>
          <th>[Label]</th>
          <th class="r">[Numeric Label]</th>
          ...
        </tr>
      </thead>
      <tbody id="grid-body">
        <!-- Sample rows — 3 representative rows minimum -->
      </tbody>
    </table>
  </div>
</div>
```

Cell types:
- Row number: `<td class="c-no">1</td>`
- Code/ID (monospace): `<td class="c-id">ITEM001</td>`
- Read-only numeric: `<td class="c-ro">100.000</td>`
- Editable cell: `<td><input class="cell-inp" value="100.000"></td>`
- Status badge: `<td><span class="sc sc-req">Requested</span></td>`

Status badge classes: `sc-req` (blue/requested) | `sc-app` (green/approved) | `sc-ord` (amber/ordered)

Include at least 3 sample data rows that represent realistic mill scenarios.
Do NOT leave the grid empty — IST testers need to see the layout with data.

## 2.10 — Grid Footer / KPI Strip (if applicable)

```html
<div class="form-footer">
  <div class="footer-card">
    <div class="footer-card-lbl">Total Lines</div>
    <div class="footer-card-val" id="footer-lines">3</div>
    <div class="footer-card-sub">line items</div>
  </div>
  <div class="footer-card">
    <div class="footer-card-lbl">[Label]</div>
    <div class="footer-card-val" id="footer-[key]">[value]</div>
    <div class="footer-card-sub">[sub label]</div>
  </div>
  ...
</div>
```

## 2.11 — Modals

For each modal from Step 1F:

```html
<div class="overlay hidden" id="modal-[key]">
  <div class="modal" style="width:680px;">
    <div class="modal-hdr">
      <span style="font-size:14px;font-weight:700;">[Modal Title]</span>
      <button class="modal-x" onclick="closeModal('[key]')">✕</button>
    </div>
    <div class="modal-search">
      <input class="modal-search-inp" placeholder="Search..." oninput="filterModal(this.value,'[key]')">
    </div>
    <div class="modal-body" style="max-height:340px;">
      <table class="m-tbl">
        <thead><tr>
          <th>[Col1]</th><th>[Col2]</th>...
        </tr></thead>
        <tbody id="modal-[key]-body">
          <!-- 5+ representative sample rows -->
        </tbody>
      </table>
    </div>
    <div class="modal-ftr">
      <span style="font-size:11px;color:var(--text-400);" id="modal-[key]-count">Showing N records</span>
      <button class="m-btn-cls" onclick="closeModal('[key]')">Close</button>
      <button class="m-btn-sel" id="modal-[key]-sel-btn" onclick="confirmModalSelection('[key]')" disabled>Select</button>
    </div>
  </div>
</div>
```

## 2.12 — Confirm Dialog

```html
<div class="confirm-overlay hidden" id="confirm-[key]">
  <div class="confirm-box">
    <div class="confirm-hdr">
      <span class="confirm-icon">[icon]</span>
      <span class="confirm-title">[Title]</span>
    </div>
    <div class="confirm-body">[Message text]</div>
    <div class="confirm-ftr">
      <button class="btn-ghost" onclick="hideConfirm('[key]')">Cancel</button>
      <button class="btn-danger" onclick="confirmAction('[key]')">[Confirm Label]</button>
    </div>
  </div>
</div>
```

## 2.13 — Toast Container

```html
<div class="toasts" id="toasts"></div>
```

## 2.14 — JavaScript

Produce a complete `<script>` block at the bottom of the file with:

```javascript
// ── State management ─────────────────────────────────────────────────
// One function per IST bar button. Each function:
// 1. Updates IST bar button active state
// 2. Enables/disables toolbar buttons per the mode
// 3. Enables/disables form fields per the mode
// 4. Shows/hides banners per the mode
// 5. Sets grid cells editable or read-only per the mode

function setState(mode) { ... }

// ── Toolbar actions ──────────────────────────────────────────────────
// Stub implementations for each toolbar button click.
// Show appropriate toast on action (success/info/error).
// Show confirm dialog before destructive actions.

// ── Modal functions ──────────────────────────────────────────────────
function openModal(key) { ... }
function closeModal(key) { ... }
function filterModal(query, key) { ... }  // simple client-side text filter on modal rows
function confirmModalSelection(key) { ... }

// ── Navigation ───────────────────────────────────────────────────────
function navigate(target) {
  const links = {
    foreclosure  : '../SPINRISE_FSD_M01_PRForeclosure_v1_1/SPINRISE_FSD_M01_PRForeclosure_v1_1.html',
    cancellation : '../SPINRISE_FSD_M01_PRCancellationUndo_v1_1/SPINRISE_FSD_M01_PRCancellationUndo_v1_1.html',
    amendment    : '../SPINRISE_FSD_M01_PRAmendment_v2_3/SPINRISE_FSD_M01_PRAmendment_v2_3.html',
    // ADD NEW ENTRY: '[NAV KEY]': '../[OUTPUT FOLDER]/[OUTPUT FILE]'
  };
  if (links[target]) window.location.href = links[target];
}

// ── Sidebar / header utils ───────────────────────────────────────────
function toggleSider() { ... }
function toggleGroup(childrenId, groupId) { ... }
function toggleUserMenu() { ... }

// ── Toast ────────────────────────────────────────────────────────────
function showToast(type, message, duration = 3000) {
  // type: 'success' | 'error' | 'info'
  // Append toast div, auto-remove after duration (error: no auto-remove)
}
```

---

# STEP 3 — UPDATE NAVIGATION IN ALL EXISTING HTML FILES

After writing the new HTML file, update these files to add the new sidebar item:

**Files to update (add new nav item to ALL of these):**
1. `D:\SpinriseV2\Docs\UI_UX Designs\index.html`
2. `D:\SpinriseV2\Docs\UI_UX Designs\SPINRISE_FSD_M01_PRAmendment_v2_3\SPINRISE_FSD_M01_PRAmendment_v2_3.html`
3. `D:\SpinriseV2\Docs\UI_UX Designs\SPINRISE_FSD_M01_PRForeclosure_v1_1\SPINRISE_FSD_M01_PRForeclosure_v1_1.html`
4. `D:\SpinriseV2\Docs\UI_UX Designs\SPINRISE_FSD_M01_PRCancellationUndo_v1_1\SPINRISE_FSD_M01_PRCancellationUndo_v1_1.html`
5. `D:\SpinriseV2\Docs\UI_UX Designs\SPINRISE_FSD_M01_PRForeclosure_Cancellation_v1_1\index.html`
6. `D:\SpinriseV2\Docs\UI_UX Designs\SPINRISE_FSD_M01_PRFirstLevelApproval_v1_1\SPINRISE_FSD_M01_PRFirstLevelApproval_v1_1.html`

**In each file, add the new sidebar menu item** inside the Purchase Order group `<div class="menu-children">`:

```html
<div class="menu-item" onclick="navigate('[NAV KEY]')">
  <span class="menu-item-icon">[NAV ICON]</span>[NAV LABEL]
</div>
```

**In `index.html` navigate() function**, add:
```javascript
'[NAV KEY]' : '[OUTPUT FOLDER]/[OUTPUT FILE]',
```

**In all other HTML files' navigate() function**, add:
```javascript
'[NAV KEY]' : '../[OUTPUT FOLDER]/[OUTPUT FILE]',
```
(note `../` relative path from subfolder to subfolder)

**In the new HTML file itself**, paths to other files use `../` prefix:
```javascript
'foreclosure' : '../SPINRISE_FSD_M01_PRForeclosure_v1_1/SPINRISE_FSD_M01_PRForeclosure_v1_1.html',
```
**In `index.html`**, paths to other files have NO `../` prefix (index.html is at root level):
```javascript
'[NAV KEY]' : '[OUTPUT FOLDER]/[OUTPUT FILE]',
```

---

# OUTPUT CHECKLIST — VERIFY BEFORE FINISHING

```
HTML PROTOTYPE GATE

FSD:
  [ ] All fields in prototype derived from FSD only — no invented fields
  [ ] All toolbar buttons derived from FSD only
  [ ] All modal columns derived from FSD only
  [ ] All validations represented (inline error states, red borders)
  [ ] IST bar has one button per form mode from FSD

Design:
  [ ] CSS copied verbatim from reference HTML — no modifications
  [ ] No raw hex colors in HTML or inline styles
  [ ] All labels Title Case, no ALL CAPS, no abbreviations
  [ ] F1 not used anywhere in JavaScript
  [ ] All toolbar buttons present and disabled (not hidden) in inactive states
  [ ] Grid has minimum 3 sample rows with realistic data
  [ ] All modals have minimum 5 sample rows

Navigation:
  [ ] New file has complete sidebar with ALL existing items
  [ ] New file's nav item marked class="active"
  [ ] index.html updated: sidebar item added + navigate() key added
  [ ] All other HTML files updated: sidebar item added + navigate() key added
  [ ] Relative paths correct (../ for subfolder files, no ../ for index.html)
```

---

# IMPORTANT NOTES

- **Do not produce a 13-step markdown document.** The deliverable is the HTML file only.
- **GAP items** go as HTML comments: `<!-- GAP-01: [description] -->` near the relevant element.
- **FSD CEO countersign status** shown in the IST bar badge text.
- **Sample data** in grids and modals must be realistic spinning-mill ERP data
  (e.g., item codes like RING-FRAME-001, departments like SPINNING, WEAVING, quantities in kg/nos).
- **Every state switch** (IST bar button click) must produce a visually distinct form state —
  the tester must be able to see clearly what changes between modes.
- **Before proceed must get input from user
--**any clarification needed should ask me dont assume or decide yourself 
