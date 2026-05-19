# CLAUDE.md — Spinrise ERP V2

## Project Overview

Spinrise is an enterprise ERP system. This is V2 — a clean rebuild driven by FSD documents, one module at a time.

- **Backend**: ASP.NET Core 8, clean layered architecture, Dapper + SQL Server stored procedures (no Entity Framework)
- **Frontend**: React 18 + TypeScript, Vite, Ant Design 5, Zustand, React Router v7

Working directory layout:
```
Development/
├── Backend/         # .NET solution (Spinrise.sln)
└── spinrise-web/    # Vite/React frontend
Docs/                # FSDs, module tracker, blueprints
```

---

## Autonomous Build Workflow

**Each module follows this sequence:**
1. FSD provided by developer
2. New branch created: `feature/mXX-<slug>`
3. Build order: SP → Backend (Domain → Infrastructure → Application → API) → Frontend → Unit Tests
4. Done = all layers built, compiles, tests ≥80% coverage
5. Developer reviews → merges to `main`

**Blocker rule:** Any ambiguity in FSD, DB schema, or requirements → STOP and ask. Never assume business logic.

**Module tracker:** `Docs/MODULE_TRACKER.md`

---

## Backend Architecture

**Flow**: `Controller → Service → Repository → Stored Procedure → SQL Server`

| Project | Responsibility |
|---|---|
| `Spinrise.API` | HTTP layer, routing, middleware, Swagger |
| `Spinrise.Application` | Business logic, DTOs, interfaces |
| `Spinrise.Infrastructure` | Dapper queries, SP execution, Unit of Work |
| `Spinrise.Domain` | Core entities |
| `Spinrise.Shared` | Cross-cutting utilities, ApiResponse, constants |
| `Spinrise.DBScripts` | SQL stored procedures (SPs only — no table scripts) |
| `Spinrise.Tests` | xUnit + Moq + FluentAssertions unit tests |

**Folder convention**: `Areas/<Division>/<Module>/` across all layers.

### Key Files
- `Spinrise.API/Controllers/BaseApiController.cs` — all controllers inherit this
- `Spinrise.API/Middleware/ExceptionHandlingMiddleware.cs`
- `Spinrise.Shared/Models/ApiResponse.cs` / `ApiResponseOfT.cs`
- `Spinrise.Infrastructure/Data/UnitOfWork.cs`

### Rules
- All data access through parameterized stored procedures — no raw string SQL, no EF
- Never expose domain entities in API responses — always use DTOs
- Validate inputs via DataAnnotations on DTOs
- Use async/await throughout
- Implement pagination on all list endpoints
- DI registrations go in `Program.cs`
- Use `CREATE OR ALTER PROCEDURE` — never `DROP + CREATE`

---

## Frontend Architecture

**Location**: `Development/spinrise-web/`

**Stack**: React 18, TypeScript (strict), Vite, Ant Design 5, Zustand, Axios, React Router v7, Vitest

**Feature module structure**:
```
src/features/<featureName>/
├── api/           # Axios API calls
├── components/    # UI components
├── pages/         # Route-level components
├── store/         # Zustand stores
├── hooks/         # Business logic hooks
└── types.ts       # TypeScript types
```

**Shared layer**: `src/shared/` — Axios client, UI wrappers, reusable hooks, utilities.

### Rules
- Strict TypeScript — no `any`
- Use Ant Design via shared UI wrapper, not directly
- Errors handled centrally via shared error handler
- Lazy-load all route-level components
- Labels use Title Case (NOT ALL CAPS)
- Modern web-native UX — not a VB6 clone

---

## Database Changes

- SPs only — never create/alter tables, columns, or indexes
- Add stored procedures → `Spinrise.DBScripts/Scripts/02-StoredProcedures/`
- Every SP change must also update `merged.sql` in the same session
- Deploy via `merged.sql` in SSMS against `SpinRiseSaranya`
- Parameterized queries only — never string concatenation

---

## Testing

- Framework: xUnit + Moq + FluentAssertions (backend), Vitest (frontend)
- Pattern: Arrange / Act / Assert
- Mock all dependencies in unit tests
- Test both success and error paths
- Target: 80%+ coverage on services and repositories

---

## Quality Standards

- API response time: < 500ms
- Code coverage: 80%+ on services and repositories
- Security: OWASP Top 10 compliance; secrets in config, never in code
- Labels: Title Case throughout UI
- Decimal format: Qty = 3dp, Rate = 4dp, Value = 2dp

---

## Deployment

### Environment

| Layer | URL | Host |
|---|---|---|
| Frontend | `http://172.16.16.40:3000` | IIS on Windows Server |
| Backend API | `http://172.16.16.40:5001` | IIS on Windows Server |
| SQL Server | `172.16.16.52\sql2016` | Database: `SpinRiseSaranya` |

### Backend — IIS Publish

**Stop app pool before publishing — running process locks DLLs.**

```
1. Stop app pool in IIS Manager
2. dotnet publish Spinrise.API/Spinrise.API.csproj -c Release -o <iis-site-path>
3. Start app pool
```

### Frontend — IIS Publish

```
1. cd Development/spinrise-web
2. npm run build
3. Copy dist/ → IIS site root for port 3000
```

### Database

```
Open merged.sql in SSMS → Execute against SpinRiseSaranya
Never run individual SP files in production
```

### Session Logging

After every development session, write a summary log to:
```
E:\Abinandan\SPINRISE\.claude\logs\<YYYY-MM-DD>_session_<topic>.md
```

---

## Common Dev Commands

### Backend
```
cd Development/Backend
dotnet run --project Spinrise.API          # dev server → http://localhost:5000
dotnet build Spinrise.sln                  # build all projects
dotnet test Spinrise.Tests/Spinrise.Tests.csproj
dotnet publish Spinrise.API/Spinrise.API.csproj -c Release -o <path>
```

### Frontend
```
cd Development/spinrise-web
npm run dev        # dev server → http://localhost:5173
npm run build      # production build → dist/
npm run test       # Vitest unit tests
npm run lint       # ESLint
```

---

## Reporting Stack

| Output | Library |
|---|---|
| PDF prints | QuestPDF |
| Excel / CSV | EPPlus |

- A4 Landscape for all purchase documents
- No FastReports, no iTextSharp

---

## Dual-Database Architecture

| | M01 — Purchase Requisition | M02 — RMI Purchase Order |
|---|---|---|
| **Database** | `SpinRiseSaranya` | `JAT` |
| **UnitOfWork** | `IUnitOfWork` | `IJATUnitOfWork` |
| **Merged deploy file** | `merged.sql` | `merged_jat.sql` |
| **SP prefix** | `ksp_PR_*` | `ksp_RMI_PO_*` |
