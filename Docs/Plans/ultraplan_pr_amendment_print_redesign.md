# ULTRAPLAN — PR Amendment QuestPDF Print Redesign
**Date:** 28 May 2026  
**Module:** M01 — Purchase Requisition Amendment  
**Source of Truth:** Crystal Report PDF — `Docs/Crystal report/amendmentreppo.pdf`  
**File to modify:** `Spinrise.API/Areas/PurchaseOrder/Print/PrAmendmentPrintDocument.cs`

---

## 1. Executive Summary

The existing `PrAmendmentPrintDocument.cs` was scaffolded by copying the 10-column PR print layout. The Crystal Report reference PDF shows the Amendment print must be a **simpler 6-column document** — no rate, no value, no machine, no totals row. The info section and signature labels also differ. This plan covers every delta between the current QuestPDF output and the Crystal Report, with precise column widths and field mappings.

---

## 2. Gap Analysis — Crystal Report vs Current QuestPDF

| Area | Crystal Report (target) | Current QuestPDF (as-is) | Action |
|---|---|---|---|
| **Table columns** | 6: S.NO / ITEM ID / ITEM DESCRIPTION / UOM / PR. Quantity / Amendment Reason | 10: S.No / Item Code / Item Name / Unit / Qty Indented / Req Date / Rate / Value / Machine No. / Remarks | **Full column redesign** |
| **Grand Total row** | Not present | Present (sum of Value) | **Remove** |
| **Info section** | 2 rows × 2 cols: Amend No + Amend Date / PR No + PR Date | 4+4 rows: PR No, PR Date, Amend No, Amend Date (left) + Dept, Requester, Reason, Ref No (right) | **Restructure to 2×2** |
| **Info — fields shown** | Only 4 fields (Amendment No, Amendment Date, PR No, PR Date) | 8 fields | **Reduce to 4 core fields** |
| **Signature — Block 1** | "Prepared By" | "Requested By" | **Label change** |
| **Signature — Block 2** | "Approved By" | "Checked By" | **Label change** |
| **Signature — Block 3** | "Authorised Signatory" | "Authorised Signatory" | No change |
| **Header** | Logo left, company name centred, GSTIN/CIN/Email/Web/Phone right | Logo left, company name + address centred | Out of scope (DTO + template engine change; affects all documents) |
| **Table header colour** | Teal/blue highlight on headers | Grey `#F2F2F2` background | Inherited from template engine — no change needed; template uses `#F2F2F2` which is close enough |

---

## 3. Field Mapping

### 3.1 DTO → Column Mapping

The SP (`ksp_PR_GetAmendmentPrint`) already returns all needed fields. **No SP or DTO changes required.**

| Crystal Report Column | DTO Field | Format |
|---|---|---|
| S.NO | Row index (1-based) | Integer |
| ITEM ID | `line.ItemCode` | Left, Courier New |
| ITEM DESCRIPTION | `line.ItemName` | Left |
| UOM | `line.Uom` | Centre |
| PR. Quantity | `line.QtyInd` | Right, N3 (3 decimal places) |
| Amendment Reason | `line.Remarks` | Left |

**Note:** `line.Remarks` in the Amendment context stores the per-line amendment reason (e.g., "Quantity change"). This is confirmed from the SP — `ISNULL(l.remarks, '') AS remarks` from `PO_APRL`.

### 3.2 Info Section Fields

| Position | Label | DTO Field |
|---|---|---|
| Left Row 1 | "Amendment No." | `_dto.AmendNo.ToString()` |
| Left Row 2 | "PR. No." | `((long)_dto.PrNo).ToString()` |
| Right Row 1 | "Amendment Date" | `_dto.AmendDate` |
| Right Row 2 | "PR. Date." | `_dto.PrDate` |

---

## 4. Precise Column Widths

**Usable table width calculation:**
```
A4 Landscape = 297 mm wide
Horizontal margins = 2 × 6.3 = 12.6 mm
Table inset = 2 × 2.2 = 4.4 mm
Usable = 297 - 12.6 - 4.4 = 280.0 mm
```

| Col | Header | Width (mm) | Align | Notes |
|---|---|---|---|---|
| 0 | S.NO | 10.0 | Centre | Narrow — integers only |
| 1 | ITEM ID | 22.0 | Left | Monospace (Courier New) |
| 2 | ITEM DESCRIPTION | 100.0 | Left | Widest column |
| 3 | UOM | 15.0 | Centre | Short codes |
| 4 | PR. Quantity | 28.0 | Right | N3 format |
| 5 | Amendment Reason | 105.0 | Left | Remainder — free text |
| **Σ** | | **280.0** | | ✓ Exact |

---

## 5. Info Section Redesign

**Target layout (matching Crystal Report):**
```
┌──────────────────────────────────────────────────────────────┐
│                PURCHASE REQUISITION AMENDMENT                 │
├──────────────────────────────┬───────────────────────────────┤
│  Amendment No.  :  1         │  Amendment Date  :  28/05/26  │
│  PR. No.        :  3         │  PR. Date.       :  25/05/26  │
└──────────────────────────────┴───────────────────────────────┘
```

**Implementation:**  
Use the existing `InfoSectionConfig` — set `LeftPanel` to 2 rows, `RightPanel` to 2 rows. No template engine changes needed.

**Panel widths:**
- `LeftPanelW` = 141.5 mm (keep as-is — already half the page)
- Right panel = `RelativeItem()` (fills remainder)
- Label width in left panel: 30 mm (fits "Amendment No.")
- Label width in right panel: 32 mm (fits "Amendment Date")

---

## 6. Table Header Design

Single-row headers (no merged/spanning rows — 6 simple columns).

| Column | Header Text | RowSpan |
|---|---|---|
| S.NO | "S.No" | 1 |
| ITEM ID | "Item ID" | 1 |
| ITEM DESCRIPTION | "Item Description" | 1 |
| UOM | "Unit" | 1 |
| PR. Quantity | "PR. Quantity" | 1 |
| Amendment Reason | "Amendment Reason" | 1 |

All headers: `topBd: true`, font = Calibri 10pt Bold.

---

## 7. Totals Row

**Remove entirely.** Amendment print does not aggregate quantities or values. Delete `BuildTable(decimal totalValue)` parameter and the `TotalsRowConfig` block. Set `TotalsRow: null` in `TableConfig` (the engine already handles null).

---

## 8. Signature Section

| Block | Label (current) | Label (target) | Name field |
|---|---|---|---|
| 1 | "Requested By" | **"Prepared By"** | `_dto.ReqName` |
| 2 | "Checked By" | **"Approved By"** | `null` |
| 3 | "Authorised Signatory" | "Authorised Signatory" | `null` |

No structural change — same 3-block layout, border positions unchanged.

---

## 9. Child Rows (Drawing No / Catalogue No / Machine)

The Crystal Report does not show child rows. However, removing them would be a functional decision (data loss). **Retain child rows** as they are — they appear only when data is present and do not affect the clean single-line cases shown in the reference PDF.

---

## 10. Files Changed

| File | Change | Risk |
|---|---|---|
| `Spinrise.API/Areas/PurchaseOrder/Print/PrAmendmentPrintDocument.cs` | Full redesign of `Cols[]`, `BuildTable()`, `BuildInfo()`, `BuildSignature()`, `BuildTableHeader()`, `Compose()` | Medium — isolated to this file |
| `Spinrise.DBScripts/Scripts/02-StoredProcedures/ksp_PR_GetAmendmentPrint.sql` | No change | None |
| `Spinrise.Application/.../PrAmendmentPrintDto.cs` | No change | None |
| `QuestPdfTemplateEngine.cs` | No change | None |
| `ReportTemplateModels.cs` | No change | None |

---

## 11. Implementation Steps (Ordered)

```
Step 1 — Update Cols[] array
   Replace 10-element float[] with 6-element array matching §4 widths.
   Old Σ = 277.97 mm | New Σ = 280.0 mm

Step 2 — Rewrite BuildTableHeader()
   6 simple ThCellConfig cells, all rowSpan=1, topBd=true.
   Remove the "Previous Purchase Details" spanning group header.

Step 3 — Rewrite BuildTable()
   - Remove `totalValue` parameter from signature
   - Remove TotalsRowConfig block
   - Reduce cell array from 10 to 6 cells per row
   - Map cells: S.No | ItemCode (Mono) | ItemName | Uom | QtyInd (N3) | Remarks
   - Pass TotalsRow: null to TableConfig

Step 4 — Update Compose()
   Change: BuildTable(totalValue) → BuildTable()
   Remove: var totalValue = ... Sum line

Step 5 — Rewrite BuildInfo()
   - Reduce LeftPanel to 2 rows: Amendment No., PR. No.
   - Reduce RightPanel to 2 rows: Amendment Date, PR. Date.
   - Update LabelMm values for new label widths (30mm left, 32mm right)

Step 6 — Update BuildSignature()
   Change "Requested By" → "Prepared By"
   Change "Checked By"   → "Approved By"

Step 7 — Build & verify
   dotnet build Spinrise.sln
   Check for "Build succeeded" | Filter: Where-Object { $_ -match "error CS|Build succeeded" }
```

---

## 12. Out of Scope (Future Tasks)

| Item | Reason deferred |
|---|---|
| Header GSTIN / CIN / Email / Web right-panel | Requires new DTO fields + `QuestPdfTemplateEngine.RenderHeader` redesign; would affect PrPrintDocument too — separate CR needed |
| Indian number format (IL-13) | Separate IST finding — different task |
| AM/PM timestamp format (PR-12) | Applies to PR print, not Amendment |

---

## 13. Acceptance Criteria

- [ ] PDF opens without exception
- [ ] Header: Company name centred, logo left, address centred — unchanged from current
- [ ] Info section: 4 fields only — Amendment No, Amendment Date, PR No, PR Date — in 2×2 layout
- [ ] Table: exactly 6 columns, Σ = 280 mm, no overflow
- [ ] Column headers match Crystal Report labels (S.No, Item ID, Item Description, Unit, PR. Quantity, Amendment Reason)
- [ ] Qty displayed to 3 decimal places
- [ ] Amendment Reason column shows `line.Remarks` value
- [ ] No Grand Total row at bottom of table
- [ ] Signature: "Prepared By | Approved By | Authorised Signatory"
- [ ] Print stamp (Printed: dd/MM/yyyy hh:mm tt) at bottom right
- [ ] A4 Landscape orientation
