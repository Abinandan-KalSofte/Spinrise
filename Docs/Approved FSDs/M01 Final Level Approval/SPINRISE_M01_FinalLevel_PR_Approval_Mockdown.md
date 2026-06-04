# SPINRISE — M01 Final Level Purchase Requisition Approval
## Screen Mockdown Document
**Module:** M01 — Purchase
**Form:** PRApproval_Final.aspx → `/purchase/final-level-pr-approval`
**Developer:** Mohan Babu
**Date:** 28-May-2026
**Blueprint:** v6.2

---

## 1. Screen Header

```
SPINRISE  /  Purchase  /  Final Level PR Approval          Mohan Babu [user icon]
```

---

## 2. Page Title

```
[checks icon]  Final level purchase requisition approval
```

---

## 3. Filter Bar

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Company  [Kalpatharu Mill — KML ▼]   Division  [ALL ▼]   [✓] Bypass All   │
│  [Show]  [Refresh]  [Save]  [Cancel]                                        │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Filter Controls

| Control | ID | Type | Behaviour |
|---|---|---|---|
| Company | `seldb` | Dropdown | Populated via `BindDB()` — pp_database. If ALL selected, Division disabled. |
| Division | `seldiv` | Dropdown | Populated via `Binddivision(dbname)` — disabled when Company = ALL. Default: ALL (divcode=0). |
| Bypass All | `chkbypass` | Checkbox | Checked by default (AS-IS). Bypass=1 → shows PRs with First Approval only (skips Second/Third). |
| Show | `btnshow` | Button | Calls `GetData()` — loads grid. |
| Refresh | `btnrefresh` | Button | Re-triggers Show. |
| Save | `btnsave` | Button | Calls `Update()` for all checked rows. Disabled until Show is clicked. |
| Cancel | `btncancel` | Button | Clears grid. Disables Save. |

### imode Routing Logic (SPINRISE — OBS-2 Resolved)

| Condition | imode | divcode |
|---|---|---|
| Company = ALL | 2 | '0' |
| Company selected + Division = ALL | 2 | '0' |
| Company selected + Division selected | 3 | selected divcode |

> **Note:** imode=1 does not exist in `ksp_po_finalapproval`. Company=ALL uses imode=2 + divcode='0'. (OBS-2 RESOLVED — 28-May-2026, Sasi.)

---

## 4. Approval Grid

### 4.1 Column Layout

| # | Column Header | Source | Width | Notes |
|---|---|---|---|---|
| 1 | ☐ (checkbox) | — | 26px | Select row for save. Disabled if Disposition = PL Discuss. |
| 2 | Company | `DB_NAME()` → CName | 52px | Dynamic — current DB name. |
| 3 | Div | `pp_divmas.abbr` | 38px | Division abbreviation. |
| 4 | PR No. | `po_prh.Prno` | 46px | Purchase Requisition number. |
| 5 | PR Date | `po_prh.Prdate` (formatted) | 68px | Display as DD/MM/YYYY. |
| 6 | Department | `in_dep.Depname` | 72px | JOIN on divcode + depcode. |
| 7 | Item Name | `in_item.itemname` | 100px | Item description. |
| 8 | UOM | `in_item.uom` | 32px | Unit of measure. |
| 9 | Cur. Stock | `KSP_PRItemStock_FUN` / `_WITH_DIV` | 60px | Right-aligned. 3 decimal places. |
| 10 | Qty Reqd | CASE cascade (ThirdAppQty → SecondAppQty → FirstAppQty → QTYREQD) | 60px | Right-aligned. 3 decimal. |
| 11 | Qty Approved | `po_prl.FinalAppQty` | 68px | **Editable input.** Must be ≤ Qty Reqd. 3 decimal. |
| 12 | Disposition | `po_prl.FinalLevel_Remarks` | 90px | **Dropdown.** See §4.3. |
| 13 | LPO Rate | `po_prl.LPO_RATE` | 60px | Right-aligned. 4 decimal. |
| 14 | LPO Date | `po_prl.LPO_DATE` (formatted) | 66px | Last PO date. |
| 15 | Approx. Cost | `po_prl.APPCOST` | 64px | Right-aligned. 2 decimal. NULL if value = 0. |

### 4.2 Grid Sample Data

```
┌───┬──────┬─────┬────────┬────────────┬─────────────┬────────────────┬─────┬──────────┬──────────┬──────────────┬────────────┬──────────┬────────────┬─────────────┐
│ ☑ │ Co.  │ Div │ PR No. │  PR Date   │  Department │   Item Name    │ UOM │ Cur.Stk  │ Qty Reqd │ Qty Approved │Disposition │ LPO Rate │  LPO Date  │ Approx.Cost │
├───┼──────┼─────┼────────┼────────────┼─────────────┼────────────────┼─────┼──────────┼──────────┼──────────────┼────────────┼──────────┼────────────┼─────────────┤
│ ✓ │ KML  │ 01  │ 100245 │ 12/05/2026 │ Maintenance │ Bearing 6205   │ NOS │    4.000 │   10.000 │   [10.000]   │ Approved ▼ │  245.00  │ 14/01/2026 │    2,450.00 │  ← Green (Third App)
│ ✓ │ KML  │ 01  │ 100245 │ 12/05/2026 │ Maintenance │ V-Belt B68     │ NOS │    2.000 │    6.000 │    [6.000]   │ Approved ▼ │  180.00  │ 03/02/2026 │    1,080.00 │  ← Green (Third App)
│   │ KML  │ 02  │ 100289 │ 15/05/2026 │ Production  │ Cotton Waste   │ KGS │  120.000 │  500.000 │  [500.000]   │    Hold  ▼ │   32.50  │ 20/03/2026 │   16,250.00 │  ← Amber (Second App)
│ ✗ │ KML  │ 03  │ 100301 │ 18/05/2026 │ Admin       │ A4 Paper Box   │ BOX │    5.000 │   20.000 │   [20.000]   │PL Discuss ▼│  550.00  │ 10/11/2025 │   11,000.00 │  ← Yellow (First App) — checkbox disabled
│ ✓ │ KML  │ 01  │ 100318 │ 21/05/2026 │ Engineering │ Gear Oil 220   │ LTR │   18.000 │   50.000 │   [50.000]   │ Approved ▼ │  420.00  │ 05/02/2026 │   21,000.00 │  ← Amber (Second App)
└───┴──────┴─────┴────────┴────────────┴─────────────┴────────────────┴─────┴──────────┴──────────┴──────────────┴────────────┴──────────┴────────────┴─────────────┘
```

### 4.3 Disposition Dropdown Values

| Code | Label | imode=4 SP Behaviour |
|---|---|---|
| 1 | PL Discuss | SecondApp='N'. Row checkbox **disabled** — cannot save. SMS sent. |
| 2 | Approved | SecondApp='Y' (only when Bypass selected). ThirdApp='Y'. PRSTATUS='D'. DirectApp='Y'. SMS sent. |
| 3 | Hold | SecondApp='N'. SMS sent. |
| 4 | Declined | FClosed='Y'. SecondApp='N'. SMS sent. |
| 5 | Postponed | SecondApp='N'. SMS sent. |

> **SPINRISE Note (OI-09 CLOSED):** `FirstApp='Y'` — **removed** from SPINRISE write. `SecondApp='Y'` — written only when Bypass checkbox is selected. `Al_SMSMessage` INSERTs for all disposition codes — **retained** in SPINRISE.

### 4.4 Row Colour Legend

```
┌──────────────────────────────────────────────────────────┐
│  Approval status:                                        │
│  [■ pale yellow]  First approval only                    │
│  [■ amber       ]  Second approval done                  │
│  [■ pale green  ]  Third approval done (final ready)     │
└──────────────────────────────────────────────────────────┘
```

| Colour | Hex (AS-IS) | Condition |
|---|---|---|
| Pale yellow | `#FFFFAA` | FirstApp='Y', SecondApp null/empty, ThirdApp null/empty |
| Amber | `#FFD400` | SecondApp='Y' (or not null), ThirdApp null/empty |
| Pale green | `#7FFF00` | ThirdApp='Y' (or not null) |

---

## 5. Validation Rules

| Rule | Source | Message |
|---|---|---|
| Qty Approved > Qty Required | AS-IS `onblur` validation | "Approved quantity should be lesser/equal to Required Quantity" — resets to Qty Reqd. |
| Disposition = PL Discuss | Row click handler | Checkbox disabled. Row excluded from Save. |
| Numeric input only | `keydown` handler | Allows: 0–9, backspace, tab, delete, arrows, decimal point. Blocks all else. |
| Save disabled until Show | `setImageUrl` | Save and Cancel buttons disabled until grid is loaded. |

---

## 6. Confirmation Modal

```
┌──────────────────────────────────┐
│ Approval                      [✕]│
├──────────────────────────────────┤
│                                  │
│   [message text here]            │
│                                  │
│        [OK]     [Cancel]         │
└──────────────────────────────────┘
```

Triggered for: Save confirmation, Exit confirmation, Validation errors.

---

## 7. SPINRISE React Component Spec

| Property | Value |
|---|---|
| Route | `/purchase/final-level-pr-approval` |
| Component name | `FinalLevelPRApproval` |
| API GET | `GET /api/finallevel-pr?dbname=&divcode=&bypass=` |
| API POST | `POST /api/finallevel-pr/update` |
| Auth | JWT session — `FinalAppUser` from token claim |
| State | Independent — does not share state context with First/Second Level screens (OI-08 confirmed) |
| Concurrency | Fetch `row_version` from `PO_PRL` before update. Include `WHERE row_version=@captured_version`. Return HTTP 409 if 0 rows affected. |

### API Request — GET

```json
{
  "dbname": "KML",
  "divcode": "0",
  "bypass": 1
}
```

### API Request — POST (Update)

```json
{
  "Dbname": "KML",
  "divcode": "01",
  "Fqty": "10.000",
  "Frem": "2",
  "Prno": "100245",
  "Prdate": "2026-05-12",
  "Prsno": "1",
  "row_version": "<captured_before_update>"
}
```

> **Note:** `logindate` parameter **removed** from SPINRISE DTO (CD-07 — dead parameter). SP uses `GETDATE()` internally.

---

## 8. SP Write Targets — imode=4

### po_prl

| Column | Value | Notes |
|---|---|---|
| `FinalAppUser` | JWT user claim | Final approver user ID |
| `Prstatus` | `'D'` | Retain |
| `DirectApp` | `'Y'` | Retain |
| `FirstApp` | — | **Removed from SPINRISE** (set by First Level only) |
| `SecondApp` | `'Y'` | Only when Bypass checkbox selected |
| `ThirdApp` | `'Y'` | Retain |
| `DirectAppDate` | `GETDATE()` | DB layer timestamp |
| `QtyReqd` | `@FinalAppQty` | Updated to approved qty |
| `FinalAppQty` | `@FinalAppQty` | Final approved qty |
| `FinalLevel_Remarks` | `@FinalLevel_Remarks` | Disposition code (int enum in SPINRISE) |

### po_prh

| Column | Value |
|---|---|
| `appflg` | `'Y'` |
| `app1` | `ISNULL(app1, 'DIR')` |
| `APP1DATE` | `ISNULL(APP1DATE, GETDATE())` |
| `APP1TIME` | `ISNULL(APP1TIME, GETDATE())` |
| `app2` | `ISNULL(app2, 'DIR')` |
| `APP2DATE` | `ISNULL(APP2DATE, GETDATE())` |
| `APP2TIME` | `ISNULL(APP2TIME, GETDATE())` |
| `app3` | `ISNULL(app3, 'DIR')` |
| `APP3DATE` | `ISNULL(APP3DATE, GETDATE())` |
| `APP3TIME` | `ISNULL(APP3TIME, GETDATE())` |

### PO_Para

| Column | Value | Condition |
|---|---|---|
| `PRSMSStatusFlg` | `'Y'` | Always on imode=4 save |

---

## 9. Critical Defects — SPINRISE Must Not Carry Forward

| CD | Risk | Summary |
|---|---|---|
| CD-01 | MED | logindate set from Prdate at app layer — dead parameter, SP uses GETDATE(). Remove from DTO. |
| CD-07 | MED | @logindate dead parameter in SP — never consumed. Remove from SP signature. |
| CD-08 | MED | @FinalLevel_Remarks declared varchar but SMS block compares integer literals. Change to int enum. |
| CD-09 | LOW | 4 PRINT statements in production SP. Remove before migration. |
| CD-10 | LOW | @phno phone lookup runs on imode=2/3 grid loads (never used). Move inside imode=4 block only. |
| CD-11 | LOW | Al_SMSMessage INSERT for Disposition=5 (Postponed) missing SendDate + NoofTry. Non-blocking — both columns NULLABLE (verified 28-May-2026). Fix recommended. |
| CD-12 | MED | prdate datetime key — time component risk. Use CAST(@prdate AS DATE). Add @@ROWCOUNT check — return HTTP 404 if 0 rows affected. |

---

## 10. Document Sign-Off

| Stage | Owner | Status |
|---|---|---|
| Stage 0 — Source cleanup | Sasi (TL-Dev) | ✅ CLEARED — 23-May-2026 |
| Stage 2 — TL-Dev review | Sasi (TL-Dev) | ✅ CLEARED — 27-May-2026 |
| Stage 3 — Domain review | Palanivel (TL-IST) | ⏳ Pending |
| Stage 4 — CEO countersignature | T. Mani (CEO) | ⏳ Pending |

> **No coding begins until CEO Stage 4 countersignature.**

---

*SPINRISE Project · Kalpatharu Software Ltd · Internal Confidential · Blueprint v6.2*
