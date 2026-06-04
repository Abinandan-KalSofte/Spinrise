# PR First Level Approval — Implementation Prompt
**Module:** M01 Purchase Order · Stage: PR First Level Approval (`frmindentapp.frm`)
**FSD Version:** v1.1 · 21 May 2026 · Stage 0 FULLY APPROVED (Sasi)
**Prompt updated:** 29 May 2026 — all clarifications from critical analysis session incorporated.
**Status:** READY FOR IMPLEMENTATION (subject to HELD items below)

---

## Role

Act as a Principal Enterprise Architect, Senior Fullstack Migration Lead, and Claude Code Enterprise Implementation Specialist.

Generate a complete production-ready fullstack module STRICTLY based on the reference files and clarifications recorded in this prompt. This prompt is the authoritative implementation brief — it supersedes the generic scaffold.

---

## Reference Files (Source of Truth — in priority order)

1. **FSD v1.1** — `SPINRISE_FSD_M01_PRFirstLevelApproval_v1.1.docx`
2. **HTML Prototype** — `SPINRISE_FSD_M01_PRFirstLevelApproval_v1_1.html`
3. **VB6 Code Reference** — `PR_FirstLevel_Approval.md`
4. **This prompt** — all clarifications override any ambiguity in the above

---

## STRICT RULES (Non-Negotiable)

- Follow reference files and clarifications EXACTLY
- Do NOT change business logic
- Do NOT redesign UI/UX beyond HTML prototype
- Do NOT rename existing SPs, DB columns, or tables
- Do NOT generate inline SQL anywhere — ZERO inline SQL
- Do NOT use Entity Framework, dynamic SQL concatenation, MAX+1, hardcoded values, or mock implementations
- Do NOT skip any validation defined in FSD or VB6 reference
- Do NOT generate placeholder code

---

## MANDATORY CLARIFICATION RULE

If ANY ambiguity, missing field, unclear workflow, conflicting business rule, or undefined DB mapping is encountered that is NOT already resolved in this prompt:

1. STOP immediately
2. Generate a `CLARIFICATION REQUIRED` section
3. Ask precise, numbered questions
4. Do NOT continue implementation until answered
5. Never assume to continue coding

---

## HELD ITEMS — Do NOT Implement

The following are explicitly deferred. Implement the header-level default as shown in the HTML prototype, but flag with a `// OI-07 HELD` comment. An email must be sent to the team when the module is deployed explaining these open items.

| Item | What is held | Default implementation |
|------|-------------|----------------------|
| **OI-07** | Delete-approval: per-line vs header-level scope (CEO confirmation pending) | Implement header-level reset as shown in HTML prototype confirm-delete dialog |
| **OI-08** | Multi-level workflow (Second/Third Level forms) — separate FSDs | This form handles First Level only. Do not wire any Second/Third Level logic here |

---

## CLARIFICATIONS — LOCKED DECISIONS

These were resolved on 29 May 2026. Do not re-open.

| Ref | Question | Resolution |
|-----|----------|------------|
| **B1 / Q1** | SP naming convention | The two existing SPs (`sp_PR_GetPendingFirstApproval`, `sp_PR_GetFirstApprovedForDeletion`) already exist in the live DB — use as-is, do NOT rename. Any NEW SPs created for this module must use the `ksp_PR_*` prefix. |
| **B2** | Trans_Mod on audit log (VB6 = 'ADD', FSD = 'MODIFY') | **Follow VB6.** Trans_Mod = `'ADD'` for approval save. Trans_Mod = `'DELETE'` for delete-approval. |
| **B3 / Q2** | PRSTATUS = 'F' — is it a live value? | Confirmed. `'F'` is already a valid live value in `PO_PRL.PRSTATUS`. Use it. |
| **B4 / Q3** | HTML prototype bug — SM + FM both turn green on First Level save | **SM-only is correct.** First Level Approval writes only `app1` on PO_PRH. The HTML prototype is wrong — only the SM approval switch turns green/on after save. |
| **B5 / Q4** | OI-05 DirectApp — print blocked? | **Enable print.** Implement print endpoint and UI. Fix any DirectApp-condition bugs in a later sprint. |
| **B8 / Q7** | Department lookup — "All Departments" option? | **No "All" option.** Department modal shows only departments assigned to the logged-in user via `PO_IndentAppUser` (filtered by divcode + user ID from `PP_PASSWD`). |
| **B9** | @dep parameter semantics | `@dep` = specific `depcode` of the selected department. No wildcard or NULL-means-all. |
| **B10 / Q8** | Indent Type (itype) | **Skip.** Not required in SPINRISE First Level Approval form. |
| **B13 / B14** | Year guard on listing SPs | **Year guard IS required.** Both listing SPs must include `@yfdate` and `@yldate` parameters to filter `prdate BETWEEN @yfdate AND @yldate`. This overrides FSD OI-02's "year guard not required" note — follow VB6 behaviour. |
| **Q6** | Find function SP | Find reuses `sp_PR_GetFirstApprovedForDeletion`. No separate SP needed for Find. |

---

## Technology Stack

| Layer | Technology |
|-------|-----------|
| Backend | ASP.NET Core 8, C#, Dapper, SQL Server |
| Frontend | React 18, TypeScript, Ant Design 5, Zustand |
| Grid | Ant Design Table (editable columns) — NOT AG Grid |
| Reports | QuestPDF (`PrApprovalReport` class) |
| Export | EPPlus (if applicable) |

---

## Stored Procedures

### Existing SPs — Use As-Is, Do Not Alter Names

| SP Name | Parameters | Purpose |
|---------|-----------|---------|
| `sp_PR_GetPendingFirstApproval` | `@divcode varchar(10)`, `@dep varchar`, `@yfdate datetime`, `@yldate datetime` | Lists PRs eligible for First Level Approval (all approval flags NULL, not cancelled, not closed, prdate within financial year, depcode = @dep) |
| `sp_PR_GetFirstApprovedForDeletion` | `@divcode varchar(10)`, `@yfdate datetime`, `@yldate datetime` | Lists PRs where FirstApp IS NOT NULL AND DirectApp IS NULL — used for both Delete-Approval and Find |

### New SPs — Follow `ksp_PR_*` Prefix

Any additional SPs required (e.g. `ksp_PR_GetFirstApprovalHeader`, `ksp_PR_GetFirstApprovalLines`, `ksp_PR_SaveFirstApproval`, `ksp_PR_DeleteFirstApproval`, `ksp_PR_GetPoParaForApproval`, `ksp_PR_GetDeptForUser`) must use `ksp_PR_*` prefix and follow project SP conventions:
- `SET NOCOUNT ON` at top
- `TRY/CATCH` with `ROLLBACK` in all write SPs
- No `SELECT *` — explicit column lists only
- Parameterised queries only
- `CREATE OR ALTER PROCEDURE` — never DROP + CREATE

---

## Database Tables

| Table | Role |
|-------|------|
| `PO_PRH` | PR Header — approval flags, dates, approver IDs |
| `PO_PRL` | PR Lines — item-level approval quantities, PRSTATUS |
| `In_dep` | Department Master |
| `In_item` | Item Master |
| `mm_MACmas` | Machine Master |
| `In_Scc` | Sub Cost Centre Master |
| `PO_para` | Approval parameter config — user levels, labels (SM/FM/GM) |
| `PO_IndentAppUser` | Departments authorised per user per division |
| `PP_PASSWD` | User credentials, ulevel |
| `LogDet_PO` | Audit log for all approval transactions |

### Key Columns Written on First Level Approval Save

**PO_PRH:**

| Column | Value Written |
|--------|-------------|
| `appflg` | `'Y'` |
| `app1` | Logged-in user ID |
| `app1date` | Approve date (from form field, validated ≤ pdate) |
| `app1time` | Current time |

**PO_PRL (per approved line):**

| Column | Value Written |
|--------|-------------|
| `QTYREQD` | FirstAppQty value entered by approver |
| `FirstAppQty` | Same as QTYREQD |
| `FirstApp` | `'Y'` |
| `rate` | Rate value (editable by First Level approver) |
| `value` | `QTYREQD × rate` (auto-calculated) |
| `PRSTATUS` | `'F'` (First Approved — confirmed live value) |

### Key Columns Cleared on Delete-Approval (Header-Level — OI-07 Default)

**PO_PRH:**

| Column | Value After Delete |
|--------|-------------------|
| `appflg` | `'N'` |
| `app1` | NULL |
| `app1date` | NULL |
| `app1time` | NULL |

**PO_PRL (all lines where DirectApp IS NULL):**

| Column | Value After Delete |
|--------|-------------------|
| `QTYREQD` | NULL |
| `FirstAppQty` | `0` |
| `FirstApp` | NULL |
| `PRSTATUS` | NULL |

---

## Audit Log — LogDet_PO

**Trans_Mod values (follow VB6):**
- Approval save → `Trans_Mod = 'ADD'`
- Delete-approval → `Trans_Mod = 'DELETE'`

**Fields inserted per approved line:**

| Field | Value |
|-------|-------|
| `divcode` | Session divcode |
| `prno` | PR number |
| `prdate` | PR date |
| `itemcode` | Line item code |
| `depcode` | Department code |
| `Trans_UserId` | Logged-in user ID |
| `prsno` | PR serial number |
| `quantity` | QTYREQD (approved qty) |
| `username` | Logged-in username |
| `Trans_date` | Current datetime |
| `Trans_Name` | `'Purchase Requisition Approval'` |
| `Trans_Mod` | `'ADD'` (save) or `'DELETE'` (delete-approval) |
| `Trans_IPADD` | Client IP address |
| `Trans_Host` | Client hostname |
| `UOM` | Unit of measure |
| `rate` | Rate |
| `macno` | Machine number |
| `SubCost` | Sub Cost Centre |
| `moduleNo` | Module number |
| `docno` | PR number |
| `docdt` | PR date |

All 21 LogDet_PO columns must be verified in the live DDL before coding the INSERT.

---

## API Endpoints

| Method | Endpoint | Purpose |
|--------|---------|---------|
| `GET` | `/api/pr-approval/departments` | Fetch departments assigned to logged-in user (PO_IndentAppUser + PP_PASSWD, filtered by divcode) |
| `GET` | `/api/pr-approval/pending?divcode=&dep=&yfdate=&yldate=` | List PRs pending First Level Approval (`sp_PR_GetPendingFirstApproval`) |
| `GET` | `/api/pr-approval/approved?divcode=&yfdate=&yldate=` | List First-Level-Approved PRs for Delete / Find (`sp_PR_GetFirstApprovedForDeletion`) |
| `GET` | `/api/pr-approval/{prno}/{prdate}/header` | Load PR header details (PO_PRH + In_dep + In_Scc joins) |
| `GET` | `/api/pr-approval/{prno}/{prdate}/lines` | Load PR line items (PO_PRL + In_item + mm_MACmas joins) |
| `GET` | `/api/pr-approval/para?divcode=` | Load po_para once — returns `PoParaDto` (approval labels + user levels) |
| `POST` | `/api/pr-approval/{prno}/{prdate}/approve` | Save First Level Approval — commits transaction |
| `POST` | `/api/pr-approval/{prno}/{prdate}/delete-approval` | Delete/Undo First Level Approval — header-level reset (OI-07 default) |
| `POST` | `/api/pr-approval/{prno}/{prdate}/print` | Generate QuestPDF `PrApprovalReport` — SEPARATE from save |

All endpoints return `ApiResponse<T>` wrapper per project convention.
All endpoints are `async`/`await` throughout.
No business logic inside controllers — service layer handles all logic.

---

## Architecture Mandates

### 1. po_para Caching (CEO Directive CD-06 — Mandatory)

`po_para` must be read **ONCE** at page load via a single parameterised Dapper call.
Map the result to a `PoParaDto` and cache it for the lifetime of the request (or React session state).
All service methods that need `po_para` values read from the in-memory `PoParaDto` — never call the DB again.

```
// Pattern:
PoParaDto para = await _prApprovalService.GetPoParaAsync(divcode);
// Use para.AppUserLabel1, para.AppUserLevel1, etc. throughout
```

Zero repeated DB round-trips on `PO_para`.

### 2. Print / Save Separation (CEO Directive CD-05 — Mandatory)

Save endpoint commits the transaction and returns success.
Print endpoint is a separate POST — called by the client AFTER save succeeds.
If print fails, the approval record already stands (committed). User is notified to reprint.
Print button is enabled on the UI only after save returns success.

### 3. Transaction Boundary — Approval Save

```
BeginTransaction
  UPDATE PO_PRH (appflg, app1, app1date, app1time)
  FOR EACH approved line:
    UPDATE PO_PRL (QTYREQD, FirstAppQty, FirstApp, rate, value, PRSTATUS='F')
    INSERT LogDet_PO (Trans_Mod='ADD')
CommitTransaction
-- AFTER commit: print is a separate API call
```

### 4. Transaction Boundary — Delete-Approval

```
BeginTransaction
  UPDATE PO_PRH (appflg='N', app1/date/time = NULL)
  UPDATE PO_PRL SET ... WHERE prno=@prno AND prdate=@prdate AND DirectApp IS NULL
  FOR EACH affected line:
    INSERT LogDet_PO (Trans_Mod='DELETE')
CommitTransaction
```

### 5. Concurrency

`PO_PRH.row_version` and `PO_PRL.row_version` (ROWVERSION) are confirmed present in live DDL (OI-03 CLOSED). Use rowversion for optimistic concurrency checks on UPDATE.

---

## Business Rules

| Rule | Behaviour |
|------|-----------|
| User level check | Read `dep` (user's approval level) from `PO_para` at page load. If not set: show error "Set User Level In Parameter Form". API returns HTTP 403 if user level does not match First Level. |
| Department scope | Only departments in `PO_IndentAppUser` for the logged-in user and divcode are shown in the Department modal. |
| PR eligibility | PR must have: FirstApp IS NULL, SecondApp IS NULL, ThirdApp IS NULL, DirectApp IS NULL, cancelflag ≠ 'Y', FClosed ≠ 'Y', prdate BETWEEN @yfdate AND @yldate |
| Approve Date | Must be ≤ pdate (current process date). Default: today. Error: "Date should be Equal to Current Date Or Max Purchase Requisition Date" |
| FirstAppQty validation | Must be ≤ QTYIND. If exceeded: reset to QTYIND, show error "Approved Quantity must be less than or equal to Required Quantity" |
| No items selected | If Save clicked with zero rows checked: show error "Item is not Selected" |
| Approval badge display | SM badge driven by `app1 IS NOT NULL`. FM badge driven by `app2 IS NOT NULL`. GM badge driven by `app3 IS NOT NULL`. First Level save sets app1 only — SM badge turns on, FM and GM remain off. |
| PRSTATUS transition | On First Level save: PRSTATUS → `'F'`. On Delete-Approval: PRSTATUS → NULL. |
| Rate and Value | Rate is editable by First Level approver. `value = FirstAppQty × rate` is auto-calculated and written to `PO_PRL.value` on save. |
| Print availability | Print enabled after save succeeds. QuestPDF `PrApprovalReport`. Print endpoint is separate from save. |
| Year guard | All listing SPs filter `prdate BETWEEN @yfdate AND @yldate` — year guard IS required. |
| Find function | Reuses `sp_PR_GetFirstApprovedForDeletion` — shows already-approved PRs. |

---

## UI — Form Layout (Follow HTML Prototype Exactly)

### Toolbar Buttons

| Button | State | Label / Shortcut |
|--------|-------|-----------------|
| Load PRs | Query mode: enabled | "Load PRs" |
| Delete | Query mode: enabled | "Delete" (danger style) |
| Find | Query mode: enabled | "Find" |
| Navigation (« ‹ › ») | After Find: enabled | First / Prev / Next / Last |
| Save | Load-mode: enabled; saved: disabled | "Save" (Ctrl+S) / "Confirm Delete" in delete mode |
| Print | After save: enabled | "Print" |
| Cancel | Load-mode: enabled | "Cancel" (Alt+X) |

### Header Fields (All Read-Only After PR Selection)

PR No. · PR Date · Approve Date (editable during approve action, default today, validated ≤ pdate) · Department Id · Department Name · Reference No. · Section · Sub Cost Centre · Sub Cost Centre Name · Requester Name

**Omitted from SPINRISE (not required):** Indent Type (itype)

### Approval Status Switches

Three read-only toggle switches: SM (app1) · FM (app2) · GM (app3)
Labels loaded from `PoParaDto.AppUserLabel1/2/3`.
Switch state driven by `app1/app2/app3 IS NOT NULL` on PO_PRH.

### Grid Columns (Follow HTML Prototype)

| Column | Editable? |
|--------|----------|
| # (row number) | No |
| Item Id | No |
| Item Name | No |
| Unit | No |
| Rate | **Yes** (First Level approver only) |
| Machine | No |
| Current Stock | No |
| Quantity Required (QTYIND) | No |
| First Approval Quantity (FirstAppQty) | **Yes** (validated ≤ QTYIND) |
| Required Date | No |
| Approx. Value (auto-calculated = FirstAppQty × Rate) | No |
| Remarks | No |

**Omitted from SPINRISE:** SecondApp Qty, ThirdApp Qty, Qty Ordered, Qty Received, Place of Issue, BGRPCODE, PR Status column — follow HTML prototype which intentionally excludes these.

### Footer Summary

Total Items · Total Value (sum of FirstAppQty × Rate) · Approval Status

### Two-Step PR Selection Flow (Approve Mode)

1. User clicks **Load PRs** → Department modal opens (departments from `PO_IndentAppUser` for logged-in user, shown with Pending PR count)
2. User selects a department → PR Lookup modal opens (filtered by selected depcode via `sp_PR_GetPendingFirstApproval`)
3. User selects a PR → Header and lines loaded into form

### Single-Step PR Selection Flow (Delete Mode / Find Mode)

- Delete: **Delete** button → PR Lookup modal (list from `sp_PR_GetFirstApprovedForDeletion`)
- Find: **Find** button → PR Lookup modal (same SP: `sp_PR_GetFirstApprovedForDeletion`)

### Lookup Modal Columns

PR No. · PR Date · Department Id · Department Name · Reference No. · Section

---

## Print — QuestPDF `PrApprovalReport`

**Class:** `PrApprovalReport`
**Format:** A4 Landscape (per project standard for purchase documents)
**Trigger:** POST `/api/pr-approval/{prno}/{prdate}/print` — called after save succeeds
**Parameters to SP/query:** `@divcode`, `@prno`, `@prdate`

**Report Content:**
- Header: PR No., PR Date, Department, Ref No., Section, Sub Cost Centre, Requester
- Lines: S.No, Item Code, Description, UOM, Qty Required, Qty Approved (FirstAppQty), Rate, Remarks
- Approval stamp: Approver Name, Approval Date, Approval Level (SM/FM/GM label from PoParaDto)

---

## Validations — Full Matrix

| Validation | Where | Message |
|-----------|-------|---------|
| User level not set in po_para | Page load / API | "Set User Level In Parameter Form" |
| User not authorised for First Level | API (HTTP 403) | "Not Approved User Level" |
| No eligible PRs found | After SP call | "No Records Found" (toast) |
| Approve date > pdate | Save (frontend + API) | "Date should be Equal to Current Date Or Max Purchase Requisition Date" |
| FirstAppQty > QTYIND | Grid cell change (frontend) + API | "Approved Quantity must be less than or equal to Required Quantity" — reset to QTYIND |
| No rows selected on Save | Save button click | "Item is not Selected" |
| DB error on stock lookup | API try-catch | Log error + return 0, show React toast |
| Concurrency conflict | UPDATE with rowversion | HTTP 409, React error toast |

---

## Keyboard Shortcuts (Follow HTML Prototype)

| Action | Shortcut |
|--------|---------|
| Save | Ctrl+S |
| Cancel | Alt+X |
| Close modals | Escape |

---

## Implementation Flow

1. Verify all 21 LogDet_PO columns in live DDL
2. Verify PO_PRL.PRSTATUS allows `'F'` (confirmed live — spot check)
3. Verify rowversion on PO_PRH and PO_PRL (confirmed OI-03 CLOSED)
4. Write `ksp_PR_GetDeptForUser` SP — returns departments from PO_IndentAppUser for @divcode + @userId
5. Write `ksp_PR_GetPoParaForApproval` SP — returns po_para row for @divcode (mapped to PoParaDto)
6. Write `ksp_PR_GetFirstApprovalHeader` SP — header query (PO_PRH + In_dep + In_Scc)
7. Write `ksp_PR_GetFirstApprovalLines` SP — lines query (PO_PRL + In_item + mm_MACmas)
8. Write `ksp_PR_SaveFirstApproval` SP — UPDATE PO_PRH + UPDATE PO_PRL + INSERT LogDet_PO (Trans_Mod='ADD') inside TRY/CATCH transaction
9. Write `ksp_PR_DeleteFirstApproval` SP — header-level reset UPDATE PO_PRH + UPDATE PO_PRL + INSERT LogDet_PO (Trans_Mod='DELETE') inside TRY/CATCH transaction (OI-07 HELD — header-level default)
10. Write `ksp_PR_GetFirstApprovalReport` SP — report data query
11. Update `merged.sql` with all new SPs
12. Generate Domain DTOs: `PoParaDto`, `PrApprovalHeaderDto`, `PrApprovalLineDto`, `PrApprovalSaveRequest`, `PrApprovalDeleteRequest`, `DepartmentDto`
13. Generate Repository: `PrApprovalRepository` (implements `IPrApprovalRepository`) — all SP calls via Dapper
14. Generate Service: `PrApprovalService` — business logic, PoParaDto caching, validation
15. Generate Controller: `PrApprovalController` — HTTP layer only, delegates to service
16. Register DI in `Program.cs`
17. Generate frontend API layer (`prApprovalApi.ts`)
18. Generate Zustand store (`prApprovalStore.ts`)
19. Generate React components matching HTML prototype exactly
20. Generate `PrApprovalReport` QuestPDF class
21. Validate all endpoints return `ApiResponse<T>`
22. Run build check
23. Update `merged.sql`

---

## Backend Architecture Rules

- Clean layered architecture: Controller → Service → Repository → SP
- DTOs for all requests and responses — never expose domain entities
- DataAnnotations on all request DTOs
- All async/await — no `.Result` or `.Wait()`
- No business logic in controllers
- No inline SQL under any condition
- DI registrations in `Program.cs`
- Use `IUnitOfWork` (not `IJATUnitOfWork` — this is the SpinRiseSaranya DB, not JAT)
- Folder: `Areas/PurchaseOrder/PurchaseRequisition/` (follow existing PR module structure)

---

## Frontend Architecture Rules

- Strict TypeScript — no `any`
- Ant Design 5 components only
- Zustand for state management
- No direct API calls inside UI components — all via store/hooks
- All validations display inline errors
- Lazy-load route-level components
- Labels: Title Case (not ALL CAPS)
- Decimal format: Qty = 3dp, Rate = 4dp, Value = 2dp

---

## Database Rules

- SPs only — `ksp_PR_*` for new SPs, existing `sp_PR_*` as-is
- `SET NOCOUNT ON` at top of every SP
- `TRY/CATCH` with `ROLLBACK` in all write SPs
- No `SELECT *` — explicit column lists only
- All DML inside transactions
- `CREATE OR ALTER PROCEDURE` — never DROP + CREATE
- Update `merged.sql` in same session after every SP change

---

## Deployment Notes

| Layer | Target |
|-------|--------|
| Frontend | `http://172.16.16.40:3000` |
| Backend API | `http://172.16.16.40:5001` |
| Database | `172.16.16.52\sql2016` → `SpinRiseSaranya` |
| Deploy via | `merged.sql` in SSMS (never individual SP files) |

**Email to send on deployment (re: held items):**

> Subject: M01 PR First Level Approval — Deployed · Open Items Requiring CEO Decision
>
> OI-07: Delete-Approval implemented as header-level reset (all lines) pending CEO confirmation on whether per-line selective reversal is required.
> OI-08: Multi-level workflow (Second/Third Level) not included — separate FSD required.
> Please review and advise at earliest convenience.

---

## Output Format

Step-by-step implementation. Separate sections for:

1. Reference Analysis
2. DB Column Verification Checklist
3. Stored Procedures (new `ksp_PR_*` SPs)
4. merged.sql update
5. Backend — Domain / DTOs
6. Backend — Repository
7. Backend — Service
8. Backend — Controller
9. Backend — DI registration
10. Frontend — API layer
11. Frontend — Zustand store
12. Frontend — React components (follow HTML prototype exactly)
13. QuestPDF Report
14. Validation Matrix
15. Compliance Matrix (FSD → Code mapping)
16. Deployment Checklist

Include complete production-ready code.
Include file names and folder paths.
At the end of every section print: `Strict Reference Validation Completed.`

Take a deep breath and work on this problem step by step.
