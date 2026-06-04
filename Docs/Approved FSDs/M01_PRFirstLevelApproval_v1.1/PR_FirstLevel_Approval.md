# Purchase Requisition Approval — First Level Approval

**Module:** `frmindentapp`
**Form Caption:** Purchase Requisition Approval
**Source File:** `frmindentapp.frm`

---

## 1. Overview

The **Purchase Requisition (PR) Approval** module manages the multi-level approval workflow for purchase requisitions raised within the organisation. This document covers the **First Level Approval** process, which is the initial stage in a three-tier approval hierarchy.

A Purchase Requisition (PR) raised by a department must pass through up to three approval levels before it can proceed to ordering. The first-level approver reviews and approves quantities for requisition lines that have not yet received any approval.

---

## 2. Approval Hierarchy

| Level | Flag Column | Label (Configurable) | Status on Approval |
|-------|------------|----------------------|--------------------|
| Level 1 (First) | `FirstApp` / `FirstAppQty` | Configured via `po_para.appuserlabel1` (e.g., SM) | `FIRST LEVEL APPROVED` |
| Level 2 (Second) | `SecondApp` / `SecondAppQty` | Configured via `po_para.appuserlabel2` (e.g., FM) | `SECOND LEVEL APPROVED` |
| Level 3 (Third) | `ThirdApp` / `ThirdAppQty` | Configured via `po_para.appuserlabel3` (e.g., GM) | `THIRD LEVEL APPROVED` |

> User approval levels are defined in the **Parameters** form (`po_para`) per division. The logged-in user's level (`ulevel`) is matched against `appuserlevel1`, `appuserlevel2`, or `appuserlevel3` to determine which approval stage they can act on.

---

## 3. First Level Approval — Eligibility Criteria

A PR line is eligible for **First Level Approval** when **all** of the following conditions are met:

- `FirstApp` is `NULL` or empty
- `SecondApp` is `NULL` or empty
- `ThirdApp` is `NULL` or empty
- `DirectApp` is `NULL` or empty (not a direct/final-level approval)
- The PR header is **not cancelled** (`cancelflag <> 'Y'`)
- The PR header is **not closed** (`Fclosed <> 'Y'`)
- The PR date is on or before the current system date (`PRDATE <= pdate`)

---

## 4. Form Layout

### 4.1 Header Section (PR Details)

| Field Label | Control | Data Field | Notes |
|------------|---------|-----------|-------|
| PR No. | `txtfields(2)` | `prno` | Read-only, auto-populated |
| PR Date | `MaskEdBox1(0)` | `prdate` | Format: `dd/MM/yyyy` |
| Department Code | `txtfields(5)` | `depcode` | Read-only |
| Department Name | `Text2` | `depname` | Read-only, locked |
| SubCost Centre Code | `txtfields(3)` | `SubCost` | Read-only |
| SubCost Centre Name | `Text5` | `SccName` | Read-only, locked |
| Approve Date | `MaskEdBox1(1)` | `app1date` | Format: `dd/MM/yyyy`, set at approval |
| Reference No. | `txtfields(8)` | `refno` | Max 20 characters |
| Requester Name | `Text4` | Derived from `PR_EMP` | Populated from employee master |
| Section | `Text3` | `section` | Read-only |
| Indent Type | `Option3` (radio) | `itype` | Emergency / Urgent / Ordinary |

### 4.2 Approval Status Checkboxes

Located in `Frame7`. Labels are loaded dynamically from `po_para`:

| Checkbox | Caption Source | Purpose |
|---------|---------------|---------|
| `Check1(2)` | `appuserlabel1` | Indicates First Level Approval status |
| `Check1(1)` | `appuserlabel2` | Indicates Second Level Approval status |
| `Check1(0)` | `appuserlabel3` | Indicates Third Level Approval status |

### 4.3 Line Item Grid (`grddatagrid`)

Displays the PR line items. Key columns shown during approval:

| Column | Caption | Notes |
|--------|---------|-------|
| Item Code | Code | Locked (read-only) |
| Description | Description | Locked (read-only) |
| Unit | Unit | |
| Rate | Rate | Read-only |
| Current Stock | Current Stock | |
| Quantity Required | Quantity Required | Original indented quantity |
| Quantity Approved | Quantity Approved | Editable by approver |
| FirstApp Qty | FirstApp Qty | Set at first level approval |
| SecondApp Qty | SecondApp Qty | Set at second level |
| ThirdApp Qty | ThirdApp Qty | Set at third level |
| Qty Ordered | Qty Ordered | |
| Qty Received | Quantity Received | |
| Required Date | Required Date | Format: `dd/mm/yy` |
| Place of Issue | Place Of Issue | |
| Approx. Cost | Approx. Cost | |
| Remarks | Remarks | |

> **Validation:** The approved quantity cannot exceed the required quantity. If it does, the system resets it to the required quantity with the message: *"Approved Quantity must be less than or equal to Required Quantity"*

---

## 5. Toolbar Buttons

| Button Index | Tooltip | Shortcut | Function |
|-------------|---------|----------|----------|
| 0 | Add | — | Not applicable in approval mode |
| 1 | Modify (Approve) | Ctrl+M | Opens PR selection for approval |
| 2 | Delete (Reverse) | Ctrl+D | Reverses an existing approval |
| 3 | Find | Ctrl+F | Find an approved PR by PR No. |
| 5 | First Record | Ctrl+Left | Navigate to first record |
| 6 | Next Record | Ctrl+Down | Navigate to next record |
| 7 | Previous Record | Ctrl+Up | Navigate to previous record |
| 8 | Last Record | Ctrl+Right | Navigate to last record |
| 9 | Save | Ctrl+S | Save/confirm the approval |
| 10 | Cancel | Ctrl+Backspace | Cancel current operation |
| 11 | Exit | Ctrl+Q | Close the form |
| 13 | Crystal Print | Ctrl+Y | Print the PR approval report |

---

## 6. First Level Approval — Step-by-Step Process

### Step 1: Open the Form
Navigate to the **Purchase Requisition Approval** module. On load, the system:
- Establishes a database connection (`MSDataShape` provider)
- Sets the form to query mode
- Loads approval level labels from `po_para`
- Validates that user levels are configured; if not, displays *"Set User Level In Parameter Form"*

### Step 2: Initiate Approval (Button 1 — Modify)
1. The system reads the logged-in user's approval level from `po_para`.
2. **Department Lookup** is displayed — the user selects the department (or "All") to filter PRs.
3. The system checks that the user's level matches `appuserlevel1`:
   - If matched → queries PRs eligible for **First Level Approval** (no approvals recorded yet).
   - If not matched → checks for level 2 or 3 eligibility.
   - If no match → displays *"Not Approved User Level"* and exits.
4. If no eligible PRs are found → displays *"No Records Found"*.

### Step 3: Select a Purchase Requisition
A lookup popup displays eligible PRs with the following columns:
- Purchase Requisition No.
- Purchase Requisition Date
- Department Name
- SubCost Centre
- Item Description
- Unit of Measure

The user double-clicks or selects a PR to load it into the form.

### Step 4: Review Line Items
The PR header and all line items are loaded. The grid shows:
- Items where `FirstApp` is `NULL` (not yet approved at first level)
- Columns: item details, required quantities, current stock, approximate cost

The approver can edit the **Quantity Approved** (`QTYREQD`) column per line item.

### Step 5: Save the Approval (Button 9 — Save)
On save, the system:
1. Begins a database transaction.
2. For each selected/checked line item:
   - Updates `po_prl` — sets `FirstApp = 'Y'`, `FirstAppQty` = approved quantity, `QTYREQD` = approved quantity.
   - Updates `po_prh` — sets `app1 = user ID`, `app1date = current date`, `app1time = current time`, `appflg = 'Y'`.
3. Inserts an audit log record into `LogDet_PO` with transaction details (user, IP address, hostname, timestamp, module number).
4. Commits the transaction.
5. Displays: *"The Purchase Requisition Approval process completed"*

> If no items are selected, the system shows: *"Item is not Selected"*

---

## 7. Database Tables

| Table | Role |
|-------|------|
| `PO_PRH` | Purchase Requisition Header — stores PR master data and approval flags |
| `PO_PRL` | Purchase Requisition Lines — stores item-level details and per-level approval quantities |
| `IN_DEP` | Department Master |
| `IN_ITEM` | Item Master |
| `IN_Scc` | Sub Cost Centre Master |
| `PO_para` | Approval parameter configuration (user levels, labels) |
| `PO_IndentAppUser` | Users authorised for PR approval per department |
| `PP_PASSWD` | User credentials and access level |
| `PR_EMP` | Employee master (for requester name lookup) |
| `MM_MACmas` | Machine master |
| `LogDet_PO` | Audit log for all PR approval transactions |

### Key Fields in `PO_PRL`

| Field | Description |
|-------|-------------|
| `QTYIND` | Original indented quantity |
| `QTYREQD` | Approved quantity (updated at each level) |
| `FirstApp` | `'Y'` when first level approved; `NULL` otherwise |
| `FirstAppQty` | Quantity approved at first level |
| `SecondApp` | `'Y'` when second level approved |
| `SecondAppQty` | Quantity approved at second level |
| `ThirdApp` | `'Y'` when third level approved |
| `ThirdAppQty` | Quantity approved at third level |
| `DirectApp` | `'Y'` for direct/final-level approval (bypasses levels) |
| `PRSTATUS` | Overall PR line status (NULL / `'O'` Ordered / `'E'` Enquired / `'C'` Received) |

### PR Status Values

| Status Code | Display Label |
|------------|---------------|
| `NULL`, `FirstApp = NULL` | REQUESTED |
| `NULL`, `QTYREQD = 0` | PR. CANCELLED |
| `NULL`, `DirectApp = 'Y'` | FINAL LEVEL APPROVED |
| `NULL`, `ThirdApp = 'Y'` | THIRD LEVEL APPROVED |
| `NULL`, `SecondApp = 'Y'` | SECOND LEVEL APPROVED |
| `NULL`, `FirstApp = 'Y'` | FIRST LEVEL APPROVED |
| `'O'`, `QTYORD > 0` | ORDERED |
| `'O'`, `QTYORD = 0` | ORDER CANCELLED |
| `'E'` | ENQUIRED |
| `'C'` | RECEIVED |

---

## 8. Approval Reversal (Delete — Button 2)

A first-level approver can **reverse** an approval they have granted:

1. The system identifies the user's level from `po_para`.
2. For First Level reversal:
   - `po_prh` is updated: clears `appflg`, `app1`, `app2`, `app3`, and all approval dates/times.
   - `po_prl` is updated: clears `QTYREQD`, `FirstAppQty`, `FirstApp`, and resets `Prstatus = NULL`.
3. An audit log entry is inserted into `LogDet_PO` with `Trans_Mod = 'DELETE'`.
4. Displays: *"Purchase Requisition Approval Deleted Successfully"*

---

## 9. Printing

Button 13 (Crystal Print / Ctrl+Y) generates a Crystal Reports printout of the approved PR using:
- Report file: `RepPO.rpt`
- Parameters passed: `@Divcode`, `@Prno`, `@PrDate`

> Printing is only available after **Final Level Approval** is complete. Attempting to print before final approval shows: *"Final Level Approval not completed. Hence Printout can not be taken"*

---

## 10. Validations & Business Rules

| Rule | Message / Behaviour |
|------|---------------------|
| User level not configured | *"Set User Level In Parameter Form"* |
| User not authorised to approve | *"Not Approved User Level"* |
| No eligible PRs found | *"No Records Found"* |
| Approved qty > Required qty | Resets to required qty; *"Approved Quantity must be less than or equal to Required Quantity"* |
| No items selected on save | *"Item is not Selected"* |
| Backdate check (if enabled) | PR date must be ≥ maximum existing PR date in the financial year |
| Item master not defined | *"Please Define Item in Item Master"* |
| Department not defined | *"Please Define Department in Setup"* |
| Document number not defined | *"Please Define Document No. for Requisition in Housekeeping"* |
| Exit confirmation | *"Do you want to Quit?"* (Yes/No prompt on Esc key) |

---

## 11. Audit Trail

Every approval and reversal is logged to `LogDet_PO` with the following fields:

- Division Code, PR No., PR Date
- Item Code, Department Code
- Transaction User ID and Username
- PR Serial No., Approved Quantity
- Transaction Date & Time
- Transaction Name: `'Purchase Requisition Approval'`
- Transaction Mode: `'ADD'` or `'DELETE'`
- Client IP Address and Hostname
- UOM, Rate, Machine No., SubCost Centre
- Module Number

---

## 12. Prerequisites / Setup

Before using the First Level Approval form, ensure:

1. **Item Master** (`in_item`) — Items must be defined.
2. **Department Master** (`in_dep`) — Departments must be configured for the division.
3. **Document Numbering** (`po_doc_para`) — A document number series for `'PURCHASE REQUISITION'` must exist.
4. **Approval Parameters** (`po_para`) — User levels (`appuserlevel1/2/3`) and labels (`appuserlabel1/2/3`) must be configured per division.
5. **Authorised Users** (`po_IndentAppUser`) — The approving user must be listed for the relevant department and division.
6. **Financial Year** — Year start/end dates (`yfdate`, `yldate`) must be configured for correct date-range filtering.

---

*Document generated from source: `frmindentapp.frm` (Visual Basic 6 form)*
