# SPINRISE Coding Reference
**Version:** v2 — 07-Jul-2026 (QA review corrections: §2 Rule 5 merged-file model documented — module-based files executed per database, client bundles regenerated from canonical; `dd/MM/yyyy` date format in §6; `BLCODE` and `LOGDET_PO.Trans_date GETUTCDATE()` added to the trap table)
**Purpose:** the single pattern document for every Claude Code session and every developer (CEO directive 06-Jul-2026 §1-Six). Every excerpt below is lifted from working production code — copy these shapes, do not invent new ones.
**Reference implementation:** PO Entry (PR → PO Transfer). Follow it end-to-end for any new screen.
**Golden rule:** read `Development/DB_Schema/*.md` (LT-01 gate) before any SP; read this file before any code.

---

## 1. Architecture at a glance

```
React page → hook → Zustand store → api/*.ts → Axios client
    → Controller (Spinrise.API) → Service (Spinrise.Application)
    → Repository (Spinrise.Infrastructure, Dapper) → Stored Procedure → SQL Server
```

| Layer | Project | Owns |
|---|---|---|
| HTTP | `Spinrise.API` | routing, auth, ApiResponse envelope — no business logic |
| Business | `Spinrise.Application` | services, DTOs, interfaces |
| Data | `Spinrise.Infrastructure` | Dapper + SP execution only — no logic |
| SQL | `Spinrise.DBScripts` | one file per SP + merged deploy files |
| PDF/Excel | `Spinrise.Reports` | QuestPDF documents (EPPlus for Excel) |

Folder convention everywhere: `Areas/<Division>/<Module>/` (e.g. `Areas/PurchaseOrder/PoEntry/`).

**Two databases, one server** (`172.16.16.52\sql2016`), multi-tenant by login:
- `SpinRiseSaranya` = internal PR-module dev/test DB; `JAT` and `SCM` (SCMTS) = the customer-site databases
- Merged deploy files are **module-scoped, not database-scoped**: `merged.sql` = PR module, `merged_jat.sql` = PO module (`_jat` suffix is historical, not a DB binding). Each file is **run once per target database** — JAT and SCM/SCMTS each receive both module files (never assume a `USE` statement — select the DB first; the hardcoded `USE [JAT]` was removed 06-Jul after it silently redirected an SCM deploy to JAT)
- The JWT carries a `DbName` claim; `UnitOfWork` reads it from `HttpContext.Items` and `DbConnectionFactory` swaps `Database=master` in the template connection string. **You never hardcode a database name in code.**

---

## 2. Stored procedure template

Source shape: `Spinrise.DBScripts/Scripts/02-StoredProcedures/ksp_PO_SaveEntry.sql`.

```sql
-- ============================================================
-- ksp_PO_SaveEntry
-- Converts approved PR lines into a Purchase Order (ADD only).
-- Atomic transaction: header + lines + delivery slots + PR update.
-- Column names verified against live JAT schema.        ← say HOW you verified
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ksp_PO_SaveEntry
(
    @DivCode     VARCHAR(2),                -- match live column widths exactly
    @PoDate      DATE,
    @CurrRate    NUMERIC(13,4) = 1,         -- defaults on optional params
    @TotalOrdVal NUMERIC(18,2) = 0
    -- ... group params by section with comments: Header / Tax / Payment / Lines
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;                      -- transactional SPs only
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validate FIRST, with user-facing messages (frontend shows them verbatim)
        IF @TotalOrdVal <= 0
            RAISERROR('Total Order Value must be greater than zero. Please verify the commercial charges and discount values.', 16, 1);

        -- ... INSERT / UPDATE work ...

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;                               -- never swallow; middleware maps it
    END CATCH
END;
GO
```

Read-only SPs: same skeleton without transaction/XACT_ABORT (see `ksp_PO_SupplierWise_Report.sql`).

**Non-negotiable SP rules**
1. **LT-01 gate:** read `DB_Schema/JAT_Schema.md` / `SpinRiseSaranya_Schema.md` before writing. Every SP written blind has shipped wrong column names.
2. `CREATE OR ALTER` — never `DROP + CREATE`.
3. `SET NOCOUNT ON` always; `TRY/CATCH` + `ROLLBACK` in anything that writes.
4. Explicit column lists — no `SELECT *`. Parameterized only — no string concat.
5. **Same session:** every SP add/change also updates its module's merged deploy file. The merged files are split **by module, not by database**:
   - `merged.sql` → **PR module** (`ksp_PR_*`)
   - `merged_jat.sql` → **PO module** (`ksp_PO_*` / `ksp_RMI_PO_*`) — the `_jat` suffix is historical (filenames mistakenly took database names at generation time; naming being corrected), **not** a database binding
   Each merged file is executed **once per target database** — both JAT and SCM/SCMTS receive both module files at deployment. Client deployment bundles are always **regenerated from these canonical files** — never maintained as hand-edited variants, and never with a hardcoded `USE` header (a stale `USE [JAT]` in a generated SCMTS copy silently redirected an SCM deploy to JAT on 06-Jul; select the target DB by connection).
   An SP not in its merged file does not exist in production (the DeptWise report SP was missing for 2 days — found only during deployment).
6. Test the body read-only against the live test DB **before** touching the merged file.
7. Legacy SPs (e.g. `KSP_PR_PO_gst`) are read-only history — wrap or replace with a `ksp_*` SP in the merged file; never edit the legacy object.

**Live-schema traps that have actually bitten us**

| Rule | Detail |
|------|--------|
| `PP_PASSWD` user column | `user_id` (underscore) — NOT `USERID` |
| `PP_PASSWD` level column | `alevel` — NOT `ULEVEL` |
| `PR_EMP` name column | `ename` — NOT `empname` |
| `PO_PRL` machine column | `macno` (no underscore) — NOT `mac_no` |
| `mm_MACmas` machine column | `MAC_NO` (uppercase, underscore) |
| `PO_PRH` | has **NO** `PRSTATUS` column |
| `PO_ORDH` | has **NO** `DEPCODE` — department lives on `PO_ORDL.DepCode` |
| `PO_ORDL` received qty | `RCVDQTY` — NOT `RECQTY` |
| GST amount | `cgstamt + sgstamt + igstamt` — `TAXAMT` is under-populated on live data |
| Carrier name | join `PO_CAR` on `CARCODE` — `CARNAME` is not a `PO_ORDH` column |
| `PO_ORDH↔PO_ORDL` join | 4 keys: `DIVCODE, PORDNO, CAST(PORDDT AS DATE), POGRP` |
| `REQNAME → PR_EMP` | `TRY_CAST(h.REQNAME AS decimal(5,0)) = e.empno` |
| `BLCODE` | **Never populate in any SPINRISE INSERT** — legacy field, leave it out of every INSERT column list (standing Blueprint v6.3 constraint) |
| `LOGDET_PO.Trans_date` | **Always `GETUTCDATE()`, never `GETDATE()`** — CEO directive 04-Jul (Stage 4 countersignature); business-date columns keep `GETDATE()` |

---

## 3. Dapper repository pattern

Source: `Spinrise.Infrastructure/Areas/PurchaseOrder/PoEntry/PoEntryRepository.cs`.

```csharp
public class PoEntryRepository : IPoEntryRepository
{
    private readonly IUnitOfWork _uow;                    // IJATUnitOfWork for JAT-DB lookups
    public PoEntryRepository(IUnitOfWork uow) => _uow = uow;

    public async Task<PoParametersDto?> GetParametersAsync(string divCode)
    {
        return await _uow.Connection.QueryFirstOrDefaultAsync<PoParametersDto>(
            StoredProcedures.Po.GetParameters,             // constant — never a string literal
            new { DivCode = divCode },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IEnumerable<SupplierOptionDto>> GetSuppliersAsync(string divCode, string? search)
    {
        return await _uow.Connection.QueryAsync<SupplierOptionDto>(
            StoredProcedures.Po.GetSuppliers,
            new { DivCode = divCode, Search = search },
            commandType: CommandType.StoredProcedure);
    }
}
```

**Rules**
1. **Typed DTOs only — never `dynamic`.** Late-bound member access is the #1 systemic defect class (`RuntimeBinderException` at runtime, invisible at compile time). SP column alias must equal DTO property name (Dapper maps case-insensitively).
2. SP names live in `Spinrise.Shared/Constants/StoredProcedures.cs`, one nested static class per module:
   ```csharp
   public static class PoReport
   {
       public const string DateWiseReport     = "ksp_PO_DateWise_Report";
       public const string SupplierWiseReport = "ksp_PO_SupplierWise_Report";
   }
   ```
3. `IUnitOfWork` = tenant DB from the JWT (`DbName` claim). `IJATUnitOfWork` = explicit JAT routing for lookups that always serve JAT data (supplier, variety, payment mode, currency). Pick per data ownership, not per module habit.
4. Repositories contain zero business logic — a method is one SP call plus parameter shaping.
5. Register everything in `Program.cs`, scoped, interface → implementation pairs:
   ```csharp
   builder.Services.AddScoped<IUnitOfWork, UnitOfWork>();
   builder.Services.AddScoped<IPoEntryRepository, PoEntryRepository>();
   builder.Services.AddScoped<IPoEntryService, PoEntryService>();
   ```

---

## 4. API controller pattern

Source: `Spinrise.API/Areas/PurchaseOrder/Controllers/PoEntryController.cs` + `Controllers/BaseApiController.cs`.

```csharp
[Authorize(Policy = "PoAccess")]
[Area("PurchaseOrder")]
[Route("api/v1/po")]
public class PoEntryController : BaseApiController
{
    private readonly IPoEntryService _service;
    private readonly ILogger<PoEntryController> _logger;

    public PoEntryController(IPoEntryService service, ILogger<PoEntryController> logger)
    {
        _service = service;
        _logger  = logger;
    }

    [HttpGet("parameters")]
    public async Task<IActionResult> GetParameters([FromQuery] string divCode)
    {
        var result = await _service.GetParametersAsync(divCode);
        if (result is null)
            return NotFoundResponse("No parameters found for this division.");
        return OkResponse(result);
    }

    [HttpGet("permissions")]
    public async Task<IActionResult> GetUserPermissions([FromQuery] string divCode)
    {
        var userId = User.FindFirstValue(SpinriseClaims.UserId) ?? string.Empty;   // identity from claims, never from query
        var result = await _service.GetUserPermissionsAsync(userId, divCode);
        return OkResponse(result);
    }
}
```

`BaseApiController` gives the response envelope — always use it, never raw `Ok()`:

```csharp
protected IActionResult OkResponse<T>(T data, string message = "Success") => Ok(ApiResponse<T>.Ok(data, message));
protected IActionResult FailResponse(string message, int statusCode = 400, object? errors = null) => ...;
protected IActionResult NotFoundResponse(string message = "Not found.") => ...;
```

**Rules:** thin controllers (validate → call service → wrap response); DTO inputs with DataAnnotations; user identity from `SpinriseClaims`; exceptions bubble to `ExceptionHandlingMiddleware` (which turns SP `RAISERROR` text into the API error message the UI shows); domain entities never leave the API — DTOs only; list endpoints paginate.

---

## 5. React feature module structure

Source: `Development/spinrise-web/src/features/po/`.

```
src/features/<feature>/
├── api/          # one file per screen: poTransferApi.ts — all HTTP in/out
├── components/   # presentational pieces (tabs, modals, grids)
├── hooks/        # orchestration: usePoTransferForm.ts — business rules live here
├── pages/        # route-level: PrToPoTransferPage.tsx (lazy-loaded in the router)
├── store/        # Zustand: usePoTransferStore.ts — state only, no fetching
├── types.ts      # all TS types for the feature
└── utils/        # pure functions: poTransferRules.ts (calculation engine)
```

API layer (`api/poTransferApi.ts`) — typed helpers over the shared Axios client:

```ts
import api, { apiHelpers } from '@/shared/api/client'
const BASE = 'po'    // single const — one edit retargets the whole feature

export const getParameters = (divCode: string) =>
  apiHelpers.get<PoParameters>(`${BASE}/parameters?divCode=${divCode}`)
```

Zustand store (`store/usePoTransferStore.ts`) — flat state + named actions:

```ts
interface PoTransferState {
  mode: ScreenMode                    // VIEW / ADD / DELETE
  parameters: PoParameters | null
  currentPo: PoHeader | null
  draftLines: PoLine[]
  loading: boolean
  saving:  boolean
  setMode:         (mode: ScreenMode) => void
  updateDraftLine: (lineNo: number, patch: Partial<PoLine>) => void
  removeDraftLine: (lineNo: number) => void
}
export const usePoTransferStore = create<PoTransferState>((set) => ({ ... }))
```

**Rules**
1. Strict TypeScript — `any` is banned.
2. Data flows one way: page → hook → store/api. Components never call the API directly.
3. Business rules live in `hooks/` + `utils/` pure functions (testable), not in components and not in the store.
4. Ant Design only via the shared wrappers in `src/shared/` — never `import { Button } from 'antd'` in a feature.
5. `@/` path alias for shared imports; relative imports inside the feature.
6. Central error handling via the shared Axios client — feature code does not `try/catch` HTTP.
7. Route-level components are lazy-loaded.

---

## 6. Naming & formatting conventions

| Thing | Convention | Example |
|---|---|---|
| Stored procedure | `ksp_<Module>_<Action>` | `ksp_PO_SaveEntry`, `ksp_PR_GetPrint` |
| SP constant class | `StoredProcedures.<Module>.<Action>` | `StoredProcedures.Po.GetSuppliers` |
| DTO | `<Thing><Kind>Dto` | `PoParametersDto`, `SupplierOptionDto` |
| API route | `api/v1/<module>/<kebab-resource>` | `api/v1/po/pre-add-checks` |
| React store | `use<Feature>Store` | `usePoTransferStore` |
| Hook | `use<Feature><Purpose>` | `usePoTransferForm` |
| QuestPDF document | `<Report>Document` in `Spinrise.Reports` | `PoSupplierWiseDocument` |
| Git branch | `task/<owner>/<topic>` | `task/abinandan/POList-SupplierWise-Print-Correction` |

**Display formatting (screen AND print, no exceptions):** Qty = 3dp · Rate = 4dp · Value/Amount = 2dp · dates `dd/MM/yyyy` — four-digit year, with `/` separators (07/07/2026, never 07/07/26; applies equally to screen display and QuestPDF print output, matching the legacy Crystal reference in `Reports_Vb6/`) (always `CultureInfo.InvariantCulture` in C# format calls — culture default breaks the separator) · UI labels Title Case, never ALL CAPS.

**JSON:** camelCase over the wire (C# `JsonNamingPolicy.CamelCase`); SP JSON params documented in the SP header.

---

## 7. Reference walk-through — PO Entry end-to-end

One user action ("load PO screen parameters") through every layer:

| # | Layer | File | What it does |
|---|---|---|---|
| 1 | SQL | `Spinrise.DBScripts/Scripts/02-StoredProcedures/ksp_PO_GetParameters.sql` | `SELECT` from `PO_PARA` — read-only skeleton |
| 2 | Constant | `Spinrise.Shared/Constants/StoredProcedures.cs` → `Po.GetParameters` | the only place the SP name string exists |
| 3 | Repository | `Spinrise.Infrastructure/Areas/PurchaseOrder/PoEntry/PoEntryRepository.cs` | `QueryFirstOrDefaultAsync<PoParametersDto>` |
| 4 | Service | `Spinrise.Application/Areas/PurchaseOrder/PoEntry/Services/PoEntryService.cs` | business rules around the repo call |
| 5 | Controller | `Spinrise.API/Areas/PurchaseOrder/Controllers/PoEntryController.cs` → `GET api/v1/po/parameters` | claims + envelope |
| 6 | API client | `spinrise-web/src/features/po/api/poTransferApi.ts` → `getParameters()` | typed fetch |
| 7 | Store | `spinrise-web/src/features/po/store/usePoTransferStore.ts` → `setParameters` | state |
| 8 | Hook | `spinrise-web/src/features/po/hooks/usePoTransferForm.ts` | orchestrates load on screen open |
| 9 | Page | `spinrise-web/src/features/po/pages/PrToPoTransferPage.tsx` | render only |

The save path is the same chain through `ksp_PO_SaveEntry` — study it for: multi-table transaction, validation-first RAISERROR messages, JSON table params for lines, and the frontend/SP mirror rule (client-side guards in `poTransferRules.ts` are mirrored server-side in the SP — e.g. the net-order-value guard exists in both).

---

## 8. Process rules that gate every change

1. **Cosmetic vs Functional:** label/colour/spacing = inline fix with `Fix [IST-REF]: <what> in <file> L<line>` commit. Anything touching logic, validation, DB mapping, or calculations = CR document + CEO-countersigned FSD first. When in doubt → Functional.
2. **Verify before deploy:** `dotnet build` + targeted tests locally; SQL tested on the test DB before merged-file update; report layout changes rendered via `Spinrise.ReportHarness` and eyeballed against the Crystal reference PDF in `Reports_Vb6/`.
3. **Deployment:** merged SQL first, then backend (stop app pool → publish → start — the running pool locks DLLs), then frontend `dist/` copy. Verify SPs post-run with `OBJECT_DEFINITION()`. Packages built by `export_package.bat` → `Exports/SpinriseV2_Package_<ts>/`.
4. **PDF = QuestPDF, Excel = EPPlus** — FastReports/iTextSharp are banned; A4 landscape for purchase documents.
5. Multi-select report filters (dept/supplier arrays vs single-code SPs) are a **known post-sprint CR** — do not "fix" during report work; IST tests single-code only.
6. Naming in team records: **OI-03-PRINT** and **CD-NEW-xx** — never bare "OI-03".
