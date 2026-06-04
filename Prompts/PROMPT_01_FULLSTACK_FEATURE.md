# PROMPT_01 — Fullstack Feature Build
**Use before building any new screen or API endpoint.**
Fill every `[PLACEHOLDER]` before sending. Remove unused OPTIONAL sections.

---

## Context load (send these @references first)

```
Read @CLAUDE.md for project memory and all coding rules.
Read @[FSD_filename.md or .docx] — §[section number] only.
Read @Development/Backend/Spinrise.Application/Areas/[Division]/[Module]/Services/[ServiceName].cs
Read @Development/Backend/Spinrise.Infrastructure/Areas/[Division]/[Module]/[RepositoryName].cs
```

---

## Task

You are my senior .NET + React architect for Spinrise ERP V2.

**Module:** [MODULE NAME — e.g. M01 Purchase Requisition]
**Feature:** [Specific feature — e.g. "Add GetItemHistory endpoint and wire it to the Amendment line grid"]
**FSD reference:** §[x.x] — [Business Rule name]

Build this feature following the clean architecture flow:
`Controller → Service → Repository → Stored Procedure`

### 1 — Stored Procedure (if new SP required)

- File: `Spinrise.DBScripts/Scripts/02-StoredProcedures/ksp_[Prefix]_[Name].sql`
- Use `CREATE OR ALTER PROCEDURE`
- `SET NOCOUNT ON` at top
- Parameterized only — never string concatenation
- List every column explicitly — no `SELECT *`
- Read `Docs/DB_Schema/JAT_Schema.md` (M01) or `Docs/DB_Schema/SpinRiseSaranya_Schema.md` before writing
- After writing: add to `merged.sql` (M01) or `merged_jat.sql` (M02)

### 2 — DTO

- File: `Spinrise.Application/Areas/[Division]/[Module]/DTOs/[DtoName].cs`
- Strongly typed record or class — **zero `dynamic`**
- Property names must match SP column names (Dapper maps by name)

### 3 — Repository method

- File: `Spinrise.Infrastructure/Areas/[Division]/[Module]/[RepositoryName].cs`
- Use `QueryAsync<[DtoName]>` with `CommandType.StoredProcedure`
- Async throughout — no `.Result` or `.Wait()`
- Inject via `IUnitOfWork` — never `new SqlConnection()`

### 4 — Interface

- Add method signature to `Spinrise.Application/Areas/[Division]/[Module]/Interfaces/I[RepositoryName].cs`

### 5 — Service method

- File: `Spinrise.Application/Areas/[Division]/[Module]/Services/[ServiceName].cs`
- Orchestrate only — **no direct DB calls in service**
- Add `ILogger<[ServiceName]>` log line: `LogInformation("[Feature] | Div: {DivCode} | ...")`
- Validate inputs here — throw `ArgumentException` or `InvalidOperationException` with a user-readable message

### 6 — Controller action

- File: `Spinrise.API/Areas/[Division]/Controllers/[ControllerName].cs`
- Thin — validate HTTP input only, call service, return `ApiResponse<T>`
- No business logic in controller
- Correct HTTP verb and route: `[HttpGet("[route]")]` / `[HttpPost]` etc.
- Register new service/repo in `Program.cs` if not already registered

### 7 — React frontend (OPTIONAL — include only if UI work is in scope)

- API function: `src/features/[feature]/api/[name]Api.ts` — use `apiHelpers.get<T>()` / `.post<T>()`
- Component: `src/features/[feature]/components/[ComponentName].tsx`
  - Ant Design 5 only — no inline styles
  - Shared table headers: import `ERP_TH / ERP_TD` from `@/shared/styles/erpTable`
  - Errors: surface via `getErrorMessage()` from `@/shared/lib/errorHandler`
  - Labels: Title Case
- Types: add to `src/features/[feature]/types.ts` — strict TypeScript, no `any`
- State: use Zustand store if state is shared across components; local `useState` if component-only

---

## Hard rules (non-negotiable)

| Rule | Detail |
|---|---|
| No `dynamic` in Dapper | Every query must use a strongly-typed DTO |
| Async suffix | Every async method must end in `Async` |
| No `.Result` / `.Wait()` | Deadlock risk — always `await` |
| Schema first | Read schema MD before writing any SP column name |
| No EF | Dapper + SPs only |
| No raw SQL strings | Parameterized stored procedure calls only |
| Tests | After generating service method, write 3 xUnit tests (happy path, invalid input, exception) |

---

## Self-check (output this table before finishing)

| Layer | Rule checked | PASS / FAIL |
|---|---|---|
| SP | Uses `CREATE OR ALTER`, `SET NOCOUNT ON`, parameterized, listed columns | |
| DTO | Strongly typed, no `dynamic`, properties match SP columns | |
| Repository | `QueryAsync<DTO>`, `CommandType.StoredProcedure`, `async/await` | |
| Interface | Method signature added | |
| Service | No DB calls, has log line, validates inputs | |
| Controller | No business logic, returns `ApiResponse<T>` | |
| DI | Registered in `Program.cs` | |
| Tests | 3 xUnit tests written | |

Ask me ONE question if anything is unclear. Do not assume any business rule.
