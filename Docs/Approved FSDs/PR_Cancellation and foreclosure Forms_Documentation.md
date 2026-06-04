# Purchase Requisition Forms Documentation

## Overview

These are two Visual Basic 6 (VB6) MDI child forms used in a Purchase Requisition (PR) management system. Both forms interact with a SQL Server database via ADO and are part of a larger ERP-style application.

---

## 1. Indentcancellation.frm — Purchase Requisition Cancellation

### Purpose

Allows users to cancel an open Purchase Requisition (PR) and optionally undo a previously recorded cancellation.

### Form Properties

| Property | Value |
|---|---|
| VB Form Name | `Indentcancellation` |
| Caption | Purchase Requisition Cancellation |
| Window State | Maximized |
| MDI Child | Yes |
| Key Preview | Yes |

### UI Controls

#### Header Section (Frame2)
| Control | Field Binding | Description |
|---|---|---|
| `txtfields(2)` | `prno` | PR Number (right-justified) |
| `MaskEdBox1(0)` | `prdate` | PR Date (format: `dd/MM/yyyy`) |
| `txtfields(5)` | `depcode` | Department Code |
| `Text2` | `depname` | Department Name (read-only) |
| `txtfields(8)` | `refno` | Reference Number (max 15 chars) |
| `Text3` | `section` | Section |
| `txtfields(1)` | `reqname` | Requester Name / Scope (hidden) |
| `Combo2` | `ABCFLG` | PR Type (dropdown from `PO_INDENTTYPE`) |
| `Text4` | — | Employee name (read-only, hidden) |
| `Text5` | `iType` | Indent Type code (hidden) |

#### Data Grid (DataGrid1)
Displays line items of the selected PR with the following visible columns:

| Column | Caption | Format |
|---|---|---|
| Item Code | Code | — |
| Item Description | — | — |
| UOM | — | — |
| Rate | Rate | `######0.0000` |
| Machine | — | — |
| Quantity Required | Quantity Required | `######0.000` |
| Qty Approved | Quantity Approved | `######0.000` |
| Qty Ordered | Quantity Ordered | `######0.000` (hidden) |
| Quantity Received | Quantity Received | `######0.000` |
| Required Date | — | `dd/mm/yy` |
| PR Status | — | ORDERED / ENQUIRED / RECEIVED / REQUESTED |
| Place Of Issue | Place of Issue | — |
| Approx. Cost | Approx.Cost | `######0.00` |

#### Cancellation Input (Frame1, hidden initially)
- `cancltxt` — Multi-line text box for entering the cancellation reason (max 100 chars, upper-cased on save).
- `Label2` — Prompt label: "Enter the Cancellation Reason".

#### Command Buttons

| Button | Caption | Action |
|---|---|---|
| `Command1` | &Ok | Proceeds based on current mode (fetch / cancel / undo) |
| `Command2` | &Exit | Unloads the form |
| `Command3` | &Undo Cancellation | Switches mode to undo and triggers undo lookup |

#### Status Bar (`stbar`)
4-panel bar showing: user message, description, current date, current time.

### Operational Modes

The form uses an `Opt` variable to track its state:

| Mode | Description |
|---|---|
| `fetch` | Initial mode; user selects a PR to cancel via a lookup popup |
| `cancl` | User enters a cancellation reason; on OK the PR is cancelled |
| `undo` | User selects a cancelled PR; on OK the cancellation is reversed |

### Business Logic

#### Cancel Flow (`ScopeLookup` → OK button)
1. On load, `ScopeLookup` opens a lookup popup listing open, un-cancelled, un-enquired PRs within the financial year.
2. User selects a PR; header and line details are loaded.
3. User clicks **Ok** → form switches to `cancl` mode and shows the cancellation reason input.
4. User enters a reason and clicks **Ok** again:
   - `PO_PRH.cancelflag` is set to `'Y'`, `canceldt` and `canreason` are updated.
   - `PO_PRL.PRSTATUS` is set to `'X'` for all line items.
   - An audit log entry is inserted into `LogDet_PO` with transaction type `'ADD'`.

#### Undo Flow (`Command3` → OK button)
1. User clicks **Undo Cancellation**; `undoLookup` opens a popup listing cancelled PRs.
2. User selects a PR; header and line details are loaded.
3. User clicks **Ok**:
   - `PO_PRH.cancelflag`, `canceldt`, and `canreason` are set to `NULL`.
   - `PO_PRL.PRSTATUS` is set to `NULL`.
   - An audit log entry is inserted into `LogDet_PO` with transaction type `'DELETE'`.

### Database Tables

| Table | Usage |
|---|---|
| `PO_PRH` | PR Header — cancelflag, canceldt, canreason, prno, prdate, depcode |
| `PO_PRL` | PR Lines — PRSTATUS per line item |
| `IN_DEP` | Department master — depcode, depname |
| `IN_ITEM` | Item master — itemname, UOM, rate, curstk |
| `PO_INDENTTYPE` | Indent type lookup — itype, idesc |
| `PR_EMP` | Employee master — Empno, ename |
| `MM_MACmas` | Machine master — mac_no, MacFlag |
| `PO_ENQL` | Enquiry table — used to exclude already-enquired PRs |
| `LogDet_PO` | Audit log — records all cancel/undo actions |

### Key Variables

| Variable | Type | Description |
|---|---|---|
| `db` | `Connection` | ADO database connection |
| `adoPrimaryRS` | `Recordset` | Header recordset for selected PR |
| `Opt` | `String` | Current mode: `fetch`, `cancl`, or `undo` |
| `pordno` | `Long` | Selected PR number |
| `porddt` | `String` | Selected PR date |
| `deptc` | `String` | Selected department code |
| `CancelFlg` | `String` | Cancel flag value of loaded PR |

---

## 2. FrmPRForeclosure.frm — Purchase Requisition Fore Closure

### Purpose

Allows users to foreclose (close out) individual line items of open Purchase Requisitions where the balance quantity has not been fully ordered. This marks selected lines as closed, preventing further processing.

### Form Properties

| Property | Value |
|---|---|
| VB Form Name | `FrmPRForeclosure` |
| Caption | Purchase Requisition Fore Closure |
| Window State | Maximized |
| MDI Child | Yes |
| Key Preview | Yes |

### UI Controls

#### Toolbar (Buttonframe)
Icon-based graphical command buttons:

| Button Index | Tooltip | Keyboard Shortcut | Action |
|---|---|---|---|
| 1 | Modify (Ctrl M) | Ctrl+A | Switch to modification mode |
| 9 | Save (Ctrl S) | Ctrl+S | Save selected foreclosures |
| 10 | Cancel (Ctrl Backspace) | Ctrl+Backspace | Reset/cancel to query mode |
| 11 | Exit (Ctrl Q) | Ctrl+Q or Esc | Unload the form |

#### Header Area
- `Text1` — PR Number filter input (tooltip: "PR.No.")
- `Label2` — Label: "PR.No."
- `heading` — Large italic title label
- `desc` — Mode indicator label (shows "Query" or "Modification")
- `DATLAB` — Current date display label

#### Selection Frame (FrameSelection, hidden until active)
| Control | Description |
|---|---|
| `DTPicker1` | Date picker for filtering |
| `ChkByPass` | "ByPass All" checkbox |
| `CmdShow` | Show button — triggers filtered grid display |
| `CmdCancel` | Cancel button — resets to query mode |
| `Label1` | "Date" label |

#### Spread Grid (spdVar — FarPoint Spread)
The main data grid with the following columns:

| Column Constant | Index | Caption | Cell Type | Width |
|---|---|---|---|---|
| `inCheckBox` | 1 | (checkbox) | CheckBox | 2 |
| `inprno` | 2 | PR. No | Static Text | default |
| `inPrdt` | 3 | Date | Static Text | default |
| `indepname` | 4 | Department Name | Static Text | 23 |
| `inprsno` | 5 | Sl.No | Static Text | 5 |
| `inItemcode` | 6 | Item Code | Static Text | default |
| `inItemname` | 7 | Item Description | Static Text | 27 |
| `inbalance` | 8 | Balance | Number (3 dec) | 12 |

First 6 columns are frozen. Grid is read-only; only the checkbox column is interactive.

#### Status Bar (`stbar`)
4-panel bar showing: user message, description, current date, current time.

### Operational Modes

| Mode (`Opt`) | Description |
|---|---|
| `Qry` | Query/display mode — grid populated, no editing |
| `mod` | Modification mode — checkboxes enabled for selection |

### Business Logic

#### Display Flow
1. On load, the form initialises in `mod` mode and opens the grid showing all open, non-foreclosed PR line items with a positive balance quantity (unapproved quantity minus ordered quantity minus enquired quantity > 0).
2. User can optionally enter a PR number in `Text1` and click **Show** to filter results.
3. The grid is populated from `Billdisplay()`, which queries `PO_PRH`, `PO_PRL`, `In_dep`, and `in_item`.

#### Save (Foreclosure) Flow
1. User checks one or more rows in the grid.
2. User clicks **Save** (Button 9):
   - For each checked row:
     - `PO_PRL.PRSTATUS` is set to `'Z'`, `FClosed` to `'Y'`, and `FCloseddt` to the current date (parameterized).
     - Department code is looked up from `in_dep` by department name.
     - An audit record is inserted into `LogDet_PO` with transaction type `'ADD'` and module name `'Purchase Requisition Foreclosure'`.
   - If at least one row was processed, the transaction is committed and a success message shown.
   - If no rows were checked, the transaction is rolled back and the user is warned.
3. On success, the form resets to query mode (Button 10 is called).

#### PR Filter
When the user enters a PR number in `Text1` and clicks **Show**, `Billdisplay("S")` is called, which adds a `LIKE` filter (`prno LIKE '<input>%'`) to the query.

### Database Tables

| Table | Usage |
|---|---|
| `PO_PRH` | PR Header — cancelflag, prno, prdate, divcode, depcode |
| `PO_PRL` | PR Lines — FClosed, FCloseddt, PRSTATUS, QTYREQD, QTYORD, enq_qty, qtyrec, prsno, itemcode |
| `In_dep` | Department master — depcode, depname |
| `in_item` | Item master — itemcode, Itemname |
| `LogDet_PO` | Audit log — records all foreclosure actions |

### Key Variables & Constants

| Name | Type | Description |
|---|---|---|
| `db` | `Connection` | ADO database connection |
| `rsQry` | `Recordset` | Grid data recordset |
| `Opt` | `String` | Current mode: `Qry` or `mod` |
| `frmOption` | `Integer` | External mode property (`frmOpt`) |
| `iCheckBox` (1) | `Const` | Grid checkbox column index |
| `inprno` (2) | `Const` | Grid PR No. column index |
| `inPrdt` (3) | `Const` | Grid PR Date column index |
| `indepname` (4) | `Const` | Grid Department Name column index |
| `inprsno` (5) | `Const` | Grid Serial No. column index |
| `inItemcode` (6) | `Const` | Grid Item Code column index |
| `inItemname` (7) | `Const` | Grid Item Description column index |
| `inbalance` (8) | `Const` | Grid Balance Qty column index |

### Security Notes

All database operations in `FrmPRForeclosure` use **parameterized ADODB commands**, protecting against SQL injection. The `Indentcancellation` form uses string-concatenated SQL queries and should be refactored to use parameterized commands similarly.

---

## Shared Infrastructure

Both forms rely on the following application-level globals and utilities:

| Global / Function | Description |
|---|---|
| `divcode` | Division code for the active session |
| `connectstring` | ADO connection string |
| `pdate` | Current posting/system date |
| `yfdate` / `yldate` | Financial year start and end dates |
| `UserName` / `uid` | Logged-in user name and ID |
| `LocalIP` / `LocalHost` | Client machine IP and hostname |
| `ModuleNo` | Module identifier for audit logging |
| `head` | Application title string for message boxes |
| `SbMsg` | Status bar message |
| `GSNO` | Global serial number used in form navigation |
| `intervalminutes` | Session timeout counter (reset to 0 on user action) |
| `LookUp` | Shared lookup popup form |
| `showForm4FunctionKey()` | F-key handler for help/navigation |
| `adddelmod()` | Enables/disables toolbar buttons by mode |
| `NEWFORM()` | Resets form state for a new operation |
| `ToAlphaNumber()` | Input validation helper |
