# PROMPT_05 — Architecture Audit
**Use weekly (or before any major deploy) to verify clean architecture compliance.**
No placeholders needed for M01. For other modules, replace `PurchaseRequisition` / `pr`.

---

## Context load

```
Read @CLAUDE.md for project memory and all coding rules.
```

---

## Task

You are my senior .NET + React architect for Spinrise ERP V2.

Run a full clean architecture audit on the M01 Purchase Requisition module (backend + frontend) and produce a PASS/FAIL compliance report.

---

## Backend audit — 7 checks

### Check 1 — Layer separation

Verify no business logic leaks into wrong layers:

- **Controller** — should contain only: HTTP validation, call service, return `ApiResponse<T>`
- **Service** — should contain: orchestration, validation, logging. No `SqlConnection`, no Dapper calls
- **Repository** — should contain: Dapper query execution only. No business rules, no `throw` for business errors
- **Stored Procedure** — should contain: data access only. No application-level decisions

Scan these files:
```
Development/Backend/Spinrise.API/Areas/PurchaseOrder/Controllers/
Development/Backend/Spinrise.Application/Areas/PurchaseOrder/PurchaseRequisition/Services/
Development/Backend/Spinrise.Infrastructure/Areas/PurchaseOrder/PurchaseRequisition/
```

Report any violations.

### Check 2 — DTO hygiene

- No `dynamic` in any DTO
- All DTO properties are strongly typed
- No domain entities exposed in API responses

Scan:
```
Development/Backend/Spinrise.Application/Areas/PurchaseOrder/PurchaseRequisition/DTOs/
```

### Check 3 — Async compliance

- Every repository method and service method is `async` and ends in `Async`
- No `.Result` or `.Wait()` in any file

```
grep -r "\.Result" Development/Backend/Spinrise.Application/
grep -r "\.Wait()" Development/Backend/Spinrise.Infrastructure/
```

### Check 4 — DI registration

- Every service and repository registered in `Program.cs`
- No `new ServiceName()` anywhere in application code

Scan:
```
Development/Backend/Spinrise.API/Program.cs
```

### Check 5 — Stored procedures

- Every SP uses `CREATE OR ALTER PROCEDURE`
- Every SP has `SET NOCOUNT ON` at top
- No `SELECT *` in any SP
- No string concatenation — parameterized only

Scan:
```
Development/Backend/Spinrise.DBScripts/Scripts/02-StoredProcedures/ksp_PR_*.sql
```

### Check 6 — API response wrapper

- Every controller action returns `ApiResponse<T>` or `ApiResponse`
- No raw `return Ok(data)` without the wrapper

### Check 7 — Unit test coverage

- Services tested: `PrService`, `PrFirstApprovalService`, `FinalLevelApprovalService`, `PrAmendmentService`
- Each service has at minimum: happy path, invalid input, exception path

Scan:
```
Development/Backend/Spinrise.Tests/Areas/PurchaseOrder/
```

---

## Frontend audit — 5 checks

### Check 1 — TypeScript strict compliance

- `"strict": true` in `tsconfig.app.json`
- No `any` types in feature files
- No `!` non-null assertions without justification comment

### Check 2 — Shared style usage

- No local `background: '#1e293b'` definitions — must import from `@/shared/styles/erpTable`
- All table headers use `ERP_TH` or `LOOKUP_TH`
- No duplicated `TH` / `TD` constant blocks

### Check 3 — API layer hygiene

- All API calls in `src/features/[feature]/api/`
- No `fetch()` or `axios` calls inside components or hooks directly
- `apiHelpers.get<T>()` / `.post<T>()` pattern used

### Check 4 — Error handling

- All errors surfaced via `getErrorMessage()` from `@/shared/lib/errorHandler`
- No silent `catch {}` blocks (swallow only where documented)
- No `alert()` for error display

### Check 5 — Labels

- All UI labels in Title Case
- No ALL CAPS labels (except acronyms like ID, PR, PO)
- Decimal format: Qty=3dp, Rate=4dp, Value=2dp

---

## Audit output format

```
SPINRISE ARCHITECTURE AUDIT — M01 Purchase Requisition — [DD MMM YYYY]
══════════════════════════════════════════════════════════════════════

BACKEND
───────
Check 1 — Layer separation      : PASS / FAIL
  [FAIL detail if any]

Check 2 — DTO hygiene            : PASS / FAIL
  [FAIL detail if any]

Check 3 — Async compliance       : PASS / FAIL
  [FAIL detail if any]

Check 4 — DI registration        : PASS / FAIL
  [FAIL detail if any]

Check 5 — Stored procedures      : PASS / FAIL
  [FAIL detail if any]

Check 6 — API response wrapper   : PASS / FAIL
  [FAIL detail if any]

Check 7 — Unit test coverage     : PASS / FAIL
  [FAIL detail if any]

FRONTEND
────────
Check 1 — TypeScript strict      : PASS / FAIL
  [FAIL detail if any]

Check 2 — Shared style usage     : PASS / FAIL
  [FAIL detail if any]

Check 3 — API layer hygiene      : PASS / FAIL
  [FAIL detail if any]

Check 4 — Error handling         : PASS / FAIL
  [FAIL detail if any]

Check 5 — Labels + decimals      : PASS / FAIL
  [FAIL detail if any]

──────────────────────────────────────────────
OVERALL : [X / 12 checks passed]
ACTION REQUIRED : [list FAIL items as tasks]
══════════════════════════════════════════════════════════════════════
```

---

## Hard rules

| Rule | Detail |
|---|---|
| Read files, do not assume | Every check must read actual code — no assumptions |
| Report file + line for failures | e.g. `PrService.cs:142 — direct Dapper call in service` |
| No auto-fix | This prompt is audit-only — report findings, do not change code |
| Raise CR for Functional failures | If a violation is a business logic error → CR Document |
