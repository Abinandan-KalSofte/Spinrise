# Purchase Requisition Amendment Form Documentation

## Overview

| Attribute | Value |
|---|---|
| **VB Form Name** | `tmpIndAment` |
| **File** | `tmpindAment.frm` |
| **Caption** | Purchase Requisition Amendment |
| **Window State** | Maximized |
| **MDI Child** | Yes |
| **Key Preview** | Yes |
| **Primary DB Tables** | `PO_APRH` (amendment header), `PO_APRL` (amendment lines), `PO_PRH` (PR header), `PO_PRL` (PR lines), `IN_DEP` (department), `IN_ITEM` (item master), `mm_MACmas` (machine), `IN_SCC` (sub-cost centre), `LogDet_PO` (audit log), `PO_INDENTTYPE` (indent type), `PO_DOC_PARA` (document number), `pr_emp` (employee) |
| **Print** | Crystal Reports — `Cry_PRAmendment` (≤4 lines), `Cry_PRAmd_full` (≥5 lines) |

---

## 1. OCX / External Dependencies

| OCX File | Purpose | SPINRISE Replacement |
|---|---|---|
| `MSDATGRD.OCX` | `DataGrid` (grddatagrid) — item grid | Ant Design Table |
| `MSDATLST.OCX` | `DataCombo` (DataCombo1) — PR lookup | React select / Modal LOV |
| `MSMASK32.OCX` | `MaskEdBox` — date inputs | React DatePicker |
| `MSCOMCTL.OCX` | `StatusBar` (stbar) | React status bar |
| `TABCTL32.OCX` | `SSTab1` — tab container | Ant Design Tabs |
| `MSCOMCT2.OCX` | `DTPicker1`, `DTPicker2` — date pickers | React DatePicker |
| `listacx.ocx` | `KSLDESC2` — lookup list | React Modal LOV |
| `Kallistacx.ocx` | `ksldesc1` — primary lookup | React Modal LOV |
| `Crystl32.OCX` | `CrystalReport1` — print | QuestPDF / EPPlus |

---

## 2. Toolbar Buttons (Buttonframe)

| Index | Tooltip | Keyboard Shortcut | Action |
|---|---|---|---|
| 0 | Add | Ctrl+A | Open PR lookup → load header + lines → begin transaction |
| 1 | Modify | — | Select record → load for editing |
| 2 | Delete | — | Select record → choose Complete or Line deletion |
| 3 | Find | Ctrl+F | Open amendment number lookup |
| 5 | First Record | Ctrl+Left | `adoPrimaryRS.MoveFirst` |
| 6 | Next Record | Ctrl+Down | `adoPrimaryRS.MoveNext` |
| 7 | Previous Record | Ctrl+Up | `adoPrimaryRS.MovePrevious` |
| 8 | Last Record | Ctrl+Right | `adoPrimaryRS.MoveLast` |
| 9 | Save | Ctrl+S | Execute save logic (Add / Modify / Delete) |
| 10 | Cancel | Ctrl+Backspace | Rollback transaction, reset form |
| 11 | Exit | Ctrl+Q | `Unload Me` |
| 13 | Crystal Report | Ctrl+Y | Print amendment via Crystal Reports |

---

## 3. Header Section (Frame1 — PR Details)

### Header Fields

| Control | Label | DB Field | Table | Notes |
|---|---|---|---|---|
| `txtfields(3)` | Amendment No. | `Indamdno` / `amendno` | `PO_APRH` | Right-justified; auto-generated via `usp_GetNextAmendNo` |
| `MaskEdBox1(1)` | Amendment Date | `amenddate` | `PO_APRH` | Format: `dd/MM/yyyy`; must equal `pdate` for all customers |
| `DTPicker2` | Amendment Date (picker) | — | — | Bound to `MaskEdBox1(1)` on CloseUp |
| `txtfields(2)` | PR No. * | `prno` | `PO_PRH` | Mandatory; right-justified; locked after Add selection |
| `MaskEdBox1(0)` | PR Date | `prdate` | `PO_PRH` | Format: `dd/MM/yyyy`; disabled in Add mode |
| `DTPicker1` | PR Date (picker) | — | — | Disabled in Add mode |
| `txtfields(5)` | Department | `depcode` | `IN_DEP` | Lookup via `DepLookup()` |
| `Text2` | Department Name | `depname` | `IN_DEP` | Read-only; auto-filled from dept lookup |
| `txtfields(8)` | Reference No. | `refno` | `PO_APRH` | Max 15 characters |
| `Text3` | Section | `section` | `PO_APRH` | Max 20 alphanumeric characters |
| `txtfields(1)` | Requester Name / Scope | `reqname` | `PO_APRH` | Lookup via `ScopeLookup()` from `pr_emp` |
| `Text4` | Requester Name (display) | `ename` | `pr_emp` | Read-only; auto-filled from requester lookup |
| `Text5` | PR Type (internal) | `itype` | `PO_APRH` | Hidden; extracted from Combo2 selection (char 50+) |
| `Combo2` | PR Type | `ABCFLG` | `PO_INDENTTYPE` | Dropdown List; loads active types in Add/Mod, all in Query |
| `Txt_Amndreason` | Amendment Reason * | `amendreason` | `PO_APRH` | Mandatory on Save; max 100 alphanumeric characters |

---

## 4. Item Details Section (Frame7)

### Item Input Fields

| Control | Label | DB Field | Table | Notes |
|---|---|---|---|---|
| `ItemCodeTextBox` | Item * | `itemcode` | `IN_ITEM` | Max 7 chars; triggers `ItemLookup()` on Enter/Validate |
| `ItemNameTextBox` | Item Name (display) | `itemname` | `IN_ITEM` | Read-only; auto-filled on item selection |
| `UnitLabel` | UOM | `uom` | `IN_ITEM` | Label; auto-filled on item selection |
| `Text8` | Current Stock (display) | `curstk` | `IN_ITEM` | Read-only; computed via `stkchk1()` + `stkchk2()` |
| `RateTextBox` | Rate | `rate` | `IN_ITEM` / `In_trnTail` | Hidden in main form; populated from item master |
| `QtyReqTextBox` | Quantity Required * | `QTYIND` | `PO_APRL` | Format: `0;(0)`; max 9 integer + 3 decimal |
| `MachineTextBox` | Machine | `MACNO` | `mm_MACmas` | Max 10 chars; lookup via `MacLookup()` |
| `Text6` | Machine Name (display) | `Description` | `mm_MACmas` | Read-only; auto-filled on machine selection |
| `MaskEdBox2` | Required Date | `reqddate` | `PO_APRL` | Format: `dd/MM/yyyy`; cannot be less than `pdate` |
| `TxtDays` | Days (to calculate required date) | — | — | Enter number of days; auto-calculates `MaskEdBox2` on LostFocus |
| `AppCostTextBox` | Approx. Cost | `appcost` | `PO_APRL` | Format: `0.00`; max 9 integer + 2 decimal |
| `RemarksTextBox` | Remarks | `remarks` | `PO_APRL` | Max 50 characters; alphanumeric with special chars |
| `PlaceTextBox` | Place | `place` | `PO_APRL` | Max 40 chars; hidden in current UI |
| `txtfields(7)` | Sub Cost Centre | `SubCost` / `CCCODE` | `IN_SCC` | Lookup via `SubCostLookup()` |
| `Text10` | Sub Cost Centre Name (display) | `SccName` | `IN_SCC` | Read-only; auto-filled from SCC lookup |

### Item Action Buttons

| Button | Caption | Action |
|---|---|---|
| `Command6` | &Add | Add new item row to `adoSecondaryRS` grid |
| `Command3` | &Modify | Update selected item row in grid |

---

## 5. Item Grid (grddatagrid — DataGrid)

### Grid Columns — Add / Modify Mode

| Col Index | Caption | DB Field | Notes |
|---|---|---|---|
| 0 | — | `DIVCODE` | Hidden |
| 1 | — | `PRNO` | Hidden |
| 2 | — | `PRDATE` | Hidden |
| 3 | — | `PRSNO` | Hidden |
| 4 | Code | `ITEMCODE` / `Item` | Locked after Add selection |
| 5 | Description | `itemname` | Auto-filled; locked |
| 6 | UOM | `uom` | Auto-filled; locked |
| 7 | Rate | `RATE` | Hidden; format `0.0000`; right-aligned |
| 8 | Current Stock | `curstk` / `Current Stock` | Right-aligned; format `0.000` |
| 9 | Quantity Required | `QTYIND` | Mandatory; right-aligned; format `0.000` |
| 10 | Category | `CATCODE` | Triggers category lookup if blank |
| 11 | Cost Centre | `CCCODE` | Triggers cost centre lookup if blank |
| 12 | Budget Group | `BGRPCODE` | Hidden in query mode |
| 13 | Machine Code | `MACNO` | Triggers machine lookup on exit |
| 14 | Required Date | `reqddate` | Format `dd/mm/yy` |
| 15 | Place | `place` | Hidden |
| 16 | Approx. Cost | `appcost` | Right-aligned; format `0.00` |
| 17 | Remarks | `remarks` | Editable |
| 18 | REMARKS1 | `REMARK1` | Hidden |
| 19 | AmdFlg | `amdflg` | Hidden |

### Grid Columns — Query / Find Mode (additional)

| Col Index | Caption | DB Field | Notes |
|---|---|---|---|
| 10 | Quantity Required | `QTYIND` | |
| 11 | Qty Approved | `QTYREQD` | Right-aligned |
| 12 | Qty Ordered | `QTYord` | Right-aligned |
| 13 | Quantity Received | `qtyrec` | Right-aligned |
| 14 | Required Date | `reqddate` | Format `dd/mm/yy` |
| 19 | Amendment No. | `amendno` | Width 1800 |
| 20 | Amendment Date | `amenddate` | Format `dd/mm/yy` |
| 21 | Approx. Cost | `appcost` | Right-aligned; format `0.00` |
| Col 8 | PR Status | computed | ORDERED / ENQUIRED / RECEIVED / Requested |

---

## 6. Module Variables

| Variable | Type | Purpose |
|---|---|---|
| `adoPrimaryRS` | Recordset (WithEvents) | Amendment header recordset (`PO_APRH`) |
| `adoSecondaryRS` | Recordset | Amendment line items recordset (`PO_APRL`) |
| `adoprimaryrs1` | Recordset (WithEvents) | Secondary primary recordset for PRANO lookup |
| `adoSecondaryRS1` | Recordset | Secondary line items for PRANO |
| `db` | Connection | Primary ADO database connection |
| `Opt` | String | Current mode: `"add"`, `"mod"`, `"del"`, `"fnd"`, `"qry"`, `" "` |
| `deltype` | String | `"1"` = complete deletion, `"2"` = line deletion |
| `amdopt` | String | Item operation: `"add"` or `"mod"` |
| `ITARY()` | String array | Tracks item codes to prevent duplicates |
| `FLG` | String | General flag |
| `GRP` | String | Item group code for lookup |
| `RW` | Long | Tracks current grid row to detect row changes |
| `rpt` | String | `"Y"` if item code repeats |
| `Fnd` | Boolean | `True` if record found via Find |
| `find` | Boolean | Find result flag |
| `mvd` | String | Grid movement flag |
| `SNO`, `SNos`, `SlNos` | Integer | Serial number counters for line items and log |
| `prsh`, `prsl` | Recordset | Backup of `PO_APRH` / `PO_APRL` for delete restore |
| `Logrecordset` | Recordset | Log entries batch for `LogDet_PO` |
| `prano` | Integer | PR Approval Number reference |

---

## 7. Stored Procedures & Queries

| SP / Query | Parameters | Purpose |
|---|---|---|
| `usp_GetNextAmendNo` | `@divcode`, `@v_stdate`, `@v_endate` → `@newdocno` (OUTPUT) | Generates next amendment number |
| `POIndentstkchk1` | `@divcode`, `@oym`, `@itm`, `@yfdate`, `@pdate` | Stock check for item (method 1) |
| `stkchk2` (function) | item, db, param | Stock check for item (method 2); uses lesser of two stock values |
| `qry1` (inline SHAPE) | `divcode`, `fnmfdate(pdate)`, `pdate` | Default query — today's amendments (SHAPE join) |
| `fnd1` (inline SHAPE) | `divcode`, `yfdate`, `yldate`, `MDOC` | Find specific amendment by number |
| `adoSecondaryRS` inline | `divcode`, `prno`, `prdate`, `amendno` | Load amendment lines for `adoPrimaryRS_MoveComplete` |
| Select into `po_prh` | `divcode`, `prno`, `prdate`, `depcode`… | Re-insert PR header after amendment |
| Select into `po_prl` | `divcode`, `prno`, `prdate`, `prsno`… | Re-insert PR lines after amendment |
| Insert into `po_Aprh` | `divcode`, `prno`, `prdate`, `depcode`, `refno`, `section`, `itype`, `reqname`, `amendno`, `amenddate`, `amendreason` | Save new amendment header |
| Insert into `po_Aprl` | `divcode`, `prno`, `prdate`, `prsno`, `itemcode`, `RATE`, `QTYIND`, `place`, `appcost`, `remarks`, `MACNO`, `reqddate`, `AMENDNO`, `AMENDDATE`, `amdflg`, `cccode` | Save new amendment line items |
| Insert into `LogDet_PO` | `divcode`, `prno`, `prdate`, `pramdno`, `pramddt`, `SubCost`, `prsno`, `itemcode`, `depcode`, `macno`, `RATE`, `quantity`, `username`, `Trans_UserId`, `Trans_date`, `Trans_Name`, `Trans_Mod`, `Trans_IPADD`, `Trans_Host`, `moduleNo` | Audit log entry |

---

## 8. Lookup Panels (Frame2 — ksldesc1 / KSLDESC2)

| `listfield1` Value | Caption | Fields | Triggered By |
|---|---|---|---|
| `depname` | Department Listing | `depcode`, `depname` | txtfields(5) validation |
| `grpcode` | Group Listing | `grpcode`, `grpname` | Item Code entry → group first |
| `itemname` | Item Listing | `itemcode`, `itemname` | Item Code entry |
| `s.macno` | Machine Listing | `macno`, description | Grid col 13 exit |
| `macno` | Machine Listing | `mac_no`, `Description` | MachineTextBox |
| `MACDES` | Machine Listing | — | Alternate machine lookup |
| `BGRPCODE` | Budget Group | `BGRPCODE`, `BGRPNAME` | Grid col 12 exit |
| `catcode` | Category Listing | `catcode`, `catdesc` | Grid col 10 exit |
| `cccode` | Cost Centre Listing | `cccode`, `ccname` | Grid col 11 exit |
| `MAC_NO` | Machine Listing | `mac_no`, description | MachineTextBox Validate |
| `ITEMNAME,GrpName` | Item Listing | `itemcode`, `itemname` | Item Code entry (alternate) |
| `PRANO` | PR Approval Listing | `prano`, `pradate` | PR Approval Number lookup |

---

## 9. Transaction Logic

### 9.1 Add (Amendment Creation)

1. User clicks **Add** (BUTTON(0)).
2. PR lookup opens — filters PRs where: `appflg='N'`, `qtyord=0`, not in `PO_ENQL`, `cancelflag='N'`, `Fclosed<>'Y'`, within financial year.
3. Selected PR header loaded into `adoPrimaryRS`, lines into `adoSecondaryRS`.
4. `db.BeginTrans` begins.
5. If PR already amended (`AmendCount ≥ 1`), user confirms continuation.
6. On Save (BUTTON(9)):
   - Validates: Amendment Reason mandatory, Department not empty, all line items have Quantity.
   - Calls `newdocno()` → `usp_GetNextAmendNo` to generate amendment number.
   - Inserts into `po_Aprh` (amendment header).
   - Inserts all lines into `po_Aprl`.
   - Deletes original lines from `po_prl` and `po_prh`.
   - Re-inserts into `po_prh` and `po_prl` with new `amendno`.
   - Inserts audit log into `LogDet_PO` (`Trans_Name = "Purchase Requisition Amendment"`, `Trans_Mod = "ADD"`).
   - `db.CommitTrans`.
   - Displays amendment number in MsgBox.

### 9.2 Modify (Amendment Edit)

1. User clicks Modify. PR combo loads from `PO_APRH` where `amendno is not null`.
2. Record selected → `delmodproc()` loads SHAPE recordset.
3. User edits item lines in grid.
4. On Save:
   - Re-inserts updated lines into `po_Aprl`.
   - Re-inserts header into `po_prh` / updates `amendno`.
   - Updates `po_aprh` with new `amenddate`, `reqname`, `itype`, `section`, `AmendReason`.
   - `db.CommitTrans`.

### 9.3 Delete

**Option 1 — Complete Deletion (deltype = "1"):**
- Checks `PO_ORDL` for dependencies; blocks if exists.
- Restores original lines from `po_Aprl` back to `po_prl`.
- Restores original header from `po_Aprh` back to `po_prh` (sets `amendno = null`).
- Deletes from `po_Aprl` and `po_Aprh`.
- `db.CommitTrans`.

**Option 2 — Line Deletion (deltype = "2"):**
- Double-click on grid row triggers single-line delete.
- Checks `PO_ORDL` for line-level dependency.
- Executes `DELETE FROM PO_APRL WHERE ... itemcode = '...'`.
- Refreshes grid from `po_aprl`.

### 9.4 Find

- Opens amendment number lookup from `PO_APRH`.
- Calls `fnd1(MDOC)` → SHAPE query filtered by `amendno`.
- Binds result to grid.

---

## 10. Validation Rules

| Field / Event | Rule |
|---|---|
| Amendment Date | Must equal `pdate` (processing date) for all customers — VB6 enforces `CDate(MaskEdBox1(1).Text) = pdate` |
| Amendment Reason | Mandatory on Save; cannot be blank |
| Department | Cannot be empty on Save |
| Item Code | Cannot repeat within the same amendment |
| Quantity Required | Cannot be empty or ≤ 0 |
| Required Date | Cannot be less than `pdate`; prompts to update to current date if past |
| Rate | Max 8 integer + 2 decimal |
| Approx. Cost | Max 9 integer + 2 decimal; format `##0.#0` on LostFocus |
| Quantity in Modify | Cannot be less than already-ordered quantity (`QTYREQD` in `po_prl`) |
| Amendment Count | Informational MsgBox if PR already amended ≥ 1 times; does not block |

---

## 11. Business Rules

| Rule ID | Description |
|---|---|
| BR-AMD-01 | Amendment Date must equal the processing date (`pdate`) for all customers. No customer-specific variation applies. |
| BR-AMD-02 | Amendment Reason (`amendreason`) is mandatory. Save is blocked if blank. |
| BR-AMD-03 | Only PRs with `appflg='N'`, `qtyord=0`, `cancelflag='N'`, `Fclosed<>'Y'` and not in `PO_ENQL` are eligible for amendment. |
| BR-AMD-04 | Item codes cannot repeat within a single amendment. |
| BR-AMD-05 | Amendment count is informational only. No hard block on number of amendments. |
| BR-AMD-06 | On complete deletion, original PR lines are restored from `PO_APRL` back to `PO_PRL`. |
| BR-AMD-07 | `RATE_SOURCE` defaults to `ORIGINAL` (rate pre-populated from `PO_APRL`). If user overrides, `RATE_SOURCE = MANUAL` and `RATE_JUSTIFICATION` is mandatory. |
| BR-AMD-08 | Crystal Reports: uses `Cry_PRAmendment` if ≤ 4 line items; uses `Cry_PRAmd_full` if ≥ 5 line items. |
| BR-AMD-09 | EmpCommon flag controls whether requester lookup is division-scoped or global across all divisions. |

---

## 12. Lookup Subroutines

| Subroutine | Purpose | Source Table | Result Fields |
|---|---|---|---|
| `DepLookup()` | Department lookup | `In_dep` where `Active='Y'` | `depcode` → `txtfields(5)`, `depname` → `Text2` |
| `MacLookup()` | Machine lookup | `mm_macmas` where `macflag='M'` and `depcode` matches | `Mac_no` → `MachineTextBox`, `Description` → `Text6` |
| `ItemLookup()` | Item lookup | `In_Item`, `in_grp` | `itemcode` → `ItemCodeTextBox`, fills name, UOM, rate, stock |
| `ScopeLookup()` | Requester/employee lookup | `pr_emp` (optionally filtered by `divcode`) | `Empno` → `txtfields(1)`, `ename` → `Text4` |
| `SubCostLookup()` | Sub-Cost Centre lookup | `In_Scc` where `Active='Y'` | `SccCode` → `txtfields(7)`, `SccName` → `Text10` |
| `IndType()` | Load PR type combo | `PO_INDENTTYPE` (active filter in Add/Mod) | `idesc + itype` → `Combo2` |

---

## 13. Status Bar (stbar)

| Panel | Content |
|---|---|
| Panel 1 | `SbMsg` — application-level status message |
| Panel 2 | Context-sensitive hint (e.g. "Record 3 / 10", "First Record", field tip) |
| Panel 3 | Current date (Style = Date) |
| Panel 4 | Current time (Style = Time) |

---

## 14. Grid Column Visibility Summary

| Mode | Hidden Cols | Key Visible Cols |
|---|---|---|
| Add | 0, 1, 2, 3, 7, 10, 15, 19 | 4 (Code), 5 (Desc), 6 (UOM), 8 (Stock), 9 (Qty), 13 (Machine), 14 (Req Date), 16 (Cost), 17 (Remarks) |
| Modify | 0, 1, 2, 3 | Same as Add |
| Query / Find | 0, 1, 2, 3, 4, 12, 21 | 5 (Desc), 6 (UOM), 7 (Rate), 8 (Machine), 9 (Stock), 10 (Qty Req), 11 (Qty Approved), 12 (Qty Ordered), 13 (Qty Received), 14 (Req Date), 19 (Amd No.), 20 (Amd Date) |

---

## 15. Print Function (`indentreplist`)

Generates a dot-matrix text print to `indentlist.TXT` via `KALBATPROCESS`.

**Print layout includes:**
- Division name and address from `pp_divmas`
- Indent number, date, PR type
- Department and section
- Item lines: Serial No., Item Code, Item Name + Spec, UOM, Quantity, Place, Approx Cost, Remarks, Required Date
- Signature block: Prep by / Sec I/c / Dept I/c / Store I/c / G.M / Purch I/c / Fin/Accts / Director

**Crystal Report print** (BUTTON(13) — Ctrl+Y):
- Parameters: `@DivCode`, `@AMDNO`, `@AMDDT`
- Report file: `KALFOLDERDATA & "RepPO.rpt"`

---

## 16. Form Lifecycle

| Event | Action |
|---|---|
| `Form_Load` | Opens ADO connection with `PROVIDER=MSDataShape`; loads indent types; calls `Query_mode(0,1)`; sets DTPicker bounds; disables all input controls |
| `Form_Unload` | Closes `db`; releases all recordsets; resets screen |
| `Form_Resize` | Adjusts Panel 2 width of status bar |
| `adoPrimaryRS_MoveComplete` | Reloads `adoSecondaryRS` for current header; refreshes grid; populates header fields; resolves `itype` in Combo2; fills requester name |

---

## 17. SPINRISE Migration Notes

| VB6 Element | SPINRISE Replacement | Notes |
|---|---|---|
| `MSDATGRD.OCX` DataGrid | Ant Design Table with editable rows | Separate controllers: `PrAmendmentController` |
| `MaskEdBox` date fields | React DatePicker | `dd/MM/yyyy` format |
| `DTPicker` | React DatePicker | Bounded to `yfdate`–`yldate` |
| `KSLDESC.OCX` / `ksldesc1` | React Modal LOV | Reusable lookup modal component |
| `CrystalReport1` | QuestPDF | Two report templates: short (≤4 lines) and full (≥5 lines) |
| `SHAPE` query | Separate API calls | Parent: `GET /api/amendment/{amendNo}`, Child: `GET /api/amendment/{amendNo}/lines` |
| `db.BeginTrans` / `CommitTrans` | SQL Server transaction in stored procedure | Wrap insert/delete/update in `sp_PR_SaveAmendment` |
| `LogDet_PO` insert | Dapper insert in API controller after save | `Trans_Name = "Purchase Requisition Amendment"` |
| `usp_GetNextAmendNo` | Retain as-is or replace with SEQUENCE | Called before save to get next amendment number |
| `POIndentstkchk1` SP | Retain as-is | Called on item selection for stock check |
| `EmpCommon` flag | Global variable from `po_para` at login | Not read inside this form; passed as login state |
| `PurTypeFlg` flag | Global variable from `po_para` at login | Controls PR type filter in `Combo2` |
| `BackDate` flag | Not applicable here | VB6 enforces `amenddate = pdate` for ALL customers — no customer-specific BackDate logic exists in this form |
| `ig_param` | Not applicable | Zero `ig_param` reads in this form |

---

*Documentation generated from `tmpindAment.frm` — VB6 source code analysis.*
*SPINRISE M01 — Purchase Order Module | Kalpatharu Software Ltd | Internal Confidential*
