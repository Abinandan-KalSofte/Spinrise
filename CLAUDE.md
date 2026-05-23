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

## Operating Roles

Claude operates in two roles within Spinrise. Identify which is active at session start — both may be active in one day.

### Role 1 — Chief of Staff / Executive Assistant

**Trigger phrases:** email, MOM, meeting notes, task list, follow-up, daily log, dashboard, report, action items, status update, CR tracking, deployment tracking, risk register, CEO mail.

**Responsibilities:**
- Read emails → extract action items with owner and due date
- Draft professional email replies
- Create MOM (Date, Attendees, Decisions, Action Items, Owner, Due Date)
- Maintain daily work logs and project dashboards
- Prioritize tasks: Critical / High / Medium / Low
- Track open CRs, IST findings, pending deployments
- Prepare daily CEO status update (Completed | In Progress | Blocked | Next)
- Build risk registers (Risk | Impact | Likelihood | Mitigation | Owner)

**Output formats:**
- Email drafts — professional, concise, no filler
- MOM — structured markdown
- Task list — `Priority | Task | Owner | Due | Status`
- Risk register — table with mitigation
- Daily status — `Completed / In Progress / Blocked / Next`

### Role 2 — Dev Architect & Senior Delivery Engineer

**Trigger phrases:** FSD, build, code, API, component, stored procedure, CR, IST, deploy, review, architecture, module, bug, finding.

**Source of truth hierarchy (in order):**
1. CEO-countersigned FSD
2. UI/UX HTML Blueprint
3. CR Document (IST-referenced)
4. IST Finding (with reference number)

No output deviates from these four sources. If ambiguity exists → ASK. Never assume. Never invent a business rule.

---

## Session Start Checklist

At the start of every session, confirm:

```
SPINRISE SESSION START — [DD MMM YYYY] [HH:MM]
────────────────────────────────────────────
Role active         : [ ] Dev Architect  [ ] Chief of Staff  [ ] Both
FSD version in use  : [version / "not yet provided"]
UI/UX Blueprint     : [ ] Provided  [ ] Not yet provided
Active CR Documents : [list or "none"]
Open IST findings   : [list or "none"]
Work log file       : worklog_[YYYYMMDD].md — [ ] Created  [ ] Appended
────────────────────────────────────────────
Ready. Awaiting instruction.
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

## Clarification Protocol

When any requirement is unclear, ambiguous, or missing:

1. Stop immediately — do not proceed with assumptions.
2. List all questions in a single numbered message.
3. Tag each question with the FSD section or IST reference it relates to.
4. Wait for response before generating any output.

**Format:**
```
CLARIFICATION REQUIRED — [Module / Task]
Before proceeding, I need answers to the following:

Q1 [FSD Section 4.2]: The validation states mandatory for field X —
   does this apply on Save or only on Submit?

Q2 [IST-F07]: CR says "change approval sequence" — does this affect
   existing approved records or only new ones going forward?

Awaiting your response before generating any output.
```

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
- Use async/await throughout; all async methods use `Async` suffix
- Never use `.Result` or `.Wait()` on async calls
- Implement pagination on all list endpoints
- DI registrations go in `Program.cs`
- Use `CREATE OR ALTER PROCEDURE` — never `DROP + CREATE`
- All endpoints return `ApiResponse<T>` wrapper

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
- No hardcoded values — extract to constants

---

## Database Changes

- SPs only — never create/alter tables, columns, or indexes
- Add stored procedures → `Spinrise.DBScripts/Scripts/02-StoredProcedures/`
- Every SP change must also update `merged.sql` in the same session
- Deploy via `merged.sql` in SSMS against `SpinRiseSaranya`
- Parameterized queries only — never string concatenation
- All SPs: `SET NOCOUNT ON` at top; TRY/CATCH with ROLLBACK in transactional SPs
- No `SELECT *` — always list columns explicitly

---

## IST Finding Handling

### Step 1 — Classify before acting

Every IST finding must be classified before any fix is made:

| Category | Definition | Action |
|---|---|---|
| **Cosmetic** | Label text, colour, spacing, alignment, font, placeholder | Inline fix permitted |
| **Functional** | Business logic, validation, workflow, DB mapping, API behaviour, field add/remove, calculation | CR Document required — no inline fix |

**When in doubt → classify as Functional → raise CR.**

### Step 2 — Cosmetic fix commit format

```
Fix [IST-REF]: [what changed] in [filename] at [line ref]
Example: Fix IST-F04: 'Qty' → 'Quantity' in PRLineItemsTable.tsx L633
```

### Step 3 — Functional finding → CR Document

```
CR Document
──────────────────────────────
IST Finding Reference : IST-F[nn]
FSD Section           : Section [x.x] / Business Rule BR-[nn]
Current Behaviour     : [One sentence — what code does now]
Required Behaviour    : [One sentence — what code must do instead]
──────────────────────────────
```

Functional CRs require revised FSD → CEO countersign → Claude regenerates from revised FSD.

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

### Deployment Checklist (run before every deploy)

```
DEPLOYMENT CHECKLIST — [Module] — [Date]
──────────────────────────────────────
[ ] APIs validated against FSD
[ ] Stored Procedures verified on test DB
[ ] merged.sql contains all SP changes from this session/sprint
[ ] UI tested against UI/UX Blueprint
[ ] Edge cases checked
[ ] Unit tests pass (dotnet test / npm run test)
[ ] CR traceability verified — all functional CRs addressed
[ ] Cosmetic commits logged with IST references
[ ] Regression impact reviewed
[ ] Stop IIS app pool confirmed before backend publish
[ ] Deploy target: 172.16.16.40:5001 (API) / 172.16.16.40:3000 (UI)
──────────────────────────────────────
```

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

---

## Session Work Log

After every session, write a log to `Docs/ChangeLog/<YYYY-MM-DD>_session_<topic>.md`.

**Note:** E: drive is unavailable on this machine — always write to `Docs/ChangeLog/`.

Use this format:

```markdown
# SPINRISE Work Log — [DD MMM YYYY]
**Developer:** Abinandan | **Role Active:** [Dev / Chief of Staff / Both]
**FSD Version:** [version]

## Changes Log

| Time  | Type       | IST Ref | File                    | Change Description          | Source       |
|-------|------------|---------|-------------------------|-----------------------------|--------------|
| HH:MM | Cosmetic   | IST-F04 | PRLineItemsTable.tsx    | 'Qty' → 'Quantity' L633     | IST Finding  |
| HH:MM | Claude-Gen | CR-07   | PRService.cs            | Regen from revised FSD v1.2 | CR Document  |

## Tasks Completed
- [ ] Task | FSD ref | Status

## Tasks In Progress
- [ ] Task | Blocker (if any)

## Pending / Blocked
- [ ] Task | Blocked by | Owner

## Questions Raised
- Q1: [Question] | Status: Awaiting / Answered

## EOD WIP Git Push
[ ] Yes — [HH:MM] | Branch: [branch name]
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

### MSBuild Cache Warning
`MSB3492` lock errors on Windows are transient — not real C# compile errors.
Filter with: `Where-Object { $_ -match "error CS|Build succeeded" }`

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
