# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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
DB_Schema/           # Live schema snapshots (SpinRiseSaranya_Schema.md, JAT_Schema.md)
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
Prior session WIP   : [ ] Read worklog_[yesterday].md — pending tasks noted
Git status          : [ ] Confirmed — no stray uncommitted changes
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

**Module tracker:** `MODULE_TRACKER.md` (root level)

---

## File Verification Rule

**Never assume a file on disk is the same as an email attachment.**

- Do not read any file unless the user explicitly points to it by path or confirms it is the correct file.
- If a filename looks relevant to an email or task, always ask: *"Is this the file you want me to read, or is it saved elsewhere?"* — do not read it on assumption.

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
- `Spinrise.Shared/Constants/StoredProcedures.cs` — all SP name constants (`StoredProcedures.Po.SaveEntry`, `StoredProcedures.Pr.GetParameters`, etc.)

### UnitOfWork & Dynamic Database Routing

`UnitOfWork` opens the connection **lazily** (on first use) — this prevents failed connections on `[AllowAnonymous]` endpoints where no DB token is present.

`DbNameMiddleware` reads the JWT claim → extracts `DbName` → stores it in `HttpContext.Items`. `UnitOfWork` reads `HttpContext.Items["DbName"]` (falls back to `"JAT"`) and passes it to `DbConnectionFactory.CreateConnection(dbName)`. The factory swaps `Database=master` in the template connection string for the actual DB name. Connection string template lives in `appsettings.json` under `ConnectionStrings:ServerConnection`.

This is how a single API codebase serves multiple client databases — the database name comes from the user's token, not from configuration.

### StoredProcedures Constants

All SP names are centralized in `Spinrise.Shared/Constants/StoredProcedures.cs` as nested static classes:

```csharp
StoredProcedures.Pr.GetParameters   // "ksp_PR_GetParameters"
StoredProcedures.Po.SaveEntry       // "ksp_PO_SaveEntry"
StoredProcedures.Auth.Login         // etc.
```

Never hardcode SP name strings in repositories — always reference these constants.

### Exception → HTTP Status Mapping

`ExceptionHandlingMiddleware` converts exceptions to `ApiResponse.Fail(message)`:

| Exception | Status |
|---|---|
| `InvalidOperationException`, `ArgumentException` | 400 |
| `UnauthorizedAccessException` | 403 |
| `ConcurrencyConflictException`, `BusinessConflictException` | 409 |
| SQL 2601/2627 (duplicate key), 547 (FK), 515 (NOT NULL) | 400 |
| Unhandled | 500 (sanitized message) |

Throw `InvalidOperationException` for business-rule violations (e.g., "PR already approved"). Throw `BusinessConflictException` for state conflicts (e.g., "GRN raised, cannot delete").

### Rules
- All data access through parameterized stored procedures — no raw string SQL, no EF
- Never expose domain entities in API responses — always use DTOs
- Validate inputs via DataAnnotations on DTOs
- Use async/await throughout; all async methods use `Async` suffix
- Never use `.Result` or `.Wait()` on async calls
- Implement pagination on all list endpoints
- DI registrations go in `Program.cs`
- Use `CREATE OR ALTER PROCEDURE` — never `DROP + CREATE`
- **HARD RULE — Existing SP referenced in FSD = use AS-IS. Never alter or recreate it.**
  - If the FSD mentions an SP name **without saying "create new"** → that SP already exists in the legacy DB (VB6/ASP.NET). Use it exactly as-is. Do NOT write, alter, or recreate it.
  - If any change to that SP is needed → STOP. Raise to **Sasi and CEO** for approval before touching it.
  - Only `CREATE OR ALTER` an SP when the FSD explicitly says to create a new SP, or when it is confirmed that no legacy application uses that SP name.
- All endpoints return `ApiResponse<T>` wrapper

---

## Frontend Architecture

**Location**: `Development/spinrise-web/`

**Stack**: React 18, TypeScript (strict), Vite, Ant Design 5, Zustand, Axios, React Router v7, Vitest

**TypeScript path alias**: `@/*` → `src/*` (configured in `tsconfig.app.json` and `vite.config.ts`). Use `@/shared/...`, `@/features/...` — never relative `../../` paths crossing feature boundaries.

**Feature module structure**:
```
src/features/<featureName>/
├── types.ts       # TypeScript interfaces + helper functions/constants
├── api/           # Axios API calls (one file per screen or sub-feature)
├── store/         # Zustand stores
├── hooks/         # Orchestration hooks (form state, screen init, save/delete)
├── pages/         # Route-level components (compose hooks + components)
└── components/    # UI components split by screen section
```

**Layer sequence when building a feature:**
`types.ts` → `api/` → `store/` → `hooks/` → `pages/` → `components/`

Each `api/` file centralizes a `BASE` constant (e.g., `const BASE = 'po'`) so the route prefix can be changed in one place. Hooks call the API layer and update the Zustand store; pages only compose hooks and components — no direct API calls in pages.

**Shared layer**: `src/shared/` — Axios client, UI wrappers, reusable hooks, utilities.

### Auth Store & Session Context

Login stores session in Zustand + persisted to `localStorage` key `spinrise-auth-v2`. The store holds `user` (with `userId`, `divCode`, `dbName`, `compCode`) and `processingDate`.

The Axios request interceptor (`src/shared/api/client.ts`) automatically attaches:
- `Authorization: Bearer <accessToken>`
- `X-Processing-Date: <processingDate>`

Token refresh is handled transparently: on 401, the interceptor queues pending requests, refreshes the token, then replays them. On refresh failure, it clears auth state and shows a session-expired modal.

### Financial Year Bounds

`getFYBounds(date?)` in `src/shared/lib/dateUtils.ts` computes Indian April–March FY:
- Start: `YYYY-04-01`
- End: lesser of today and `YYYY+1-03-31`

Used in every list/report query as `fDate`/`lDate` parameters. Pass `processingDate` from auth store when the user is working in a past FY.

### Error Handling

Frontend: `src/shared/lib/errorHandler.ts` — `getErrorMessage(error)` normalises any thrown value (Axios error, AppError, unknown) into a user-readable string. Always call this in `catch` blocks before showing toasts or modals.

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
- Every SP change must also update `merged.sql` (SpinRiseSaranya) or `merged_jat.sql` (JAT) in the same session
- Deploy via the appropriate `merged*.sql` in SSMS
- Parameterized queries only — never string concatenation
- All SPs: `SET NOCOUNT ON` at top; TRY/CATCH with ROLLBACK in transactional SPs
- No `SELECT *` — always list columns explicitly

### MANDATORY: Read Schema Before Writing Any SP

**Before writing any stored procedure, read `DB_Schema/SpinRiseSaranya_Schema.md` or `DB_Schema/JAT_Schema.md`** (root-level `DB_Schema/` folder — not under `Docs/`).

This is non-negotiable. Every SP written without reading the schema will have wrong column names and fail in SSMS.

Critical facts from the live schema (memorise these):

| Rule | Detail |
|------|--------|
| `PP_PASSWD` user column | `user_id` (underscore) — NOT `USERID` |
| `PP_PASSWD` level column | `alevel` — NOT `ULEVEL` |
| `PR_EMP` name column | `ename` — NOT `empname` |
| `PO_PRL` machine column | `macno` (no underscore) — NOT `mac_no` |
| `mm_MACmas` machine column | `MAC_NO` (uppercase with underscore) |
| `IN_SCC` columns | `SCCCODE`, `SCCNAME`, `Divcode`, `DEPCODE` |
| `PO_PRH` has NO PRSTATUS | Never write `PO_PRH.PRSTATUS = ...` — column does not exist |
| `PO_PRH.APP1TIME` | Is `datetime` type — set with `GETDATE()`, not a string |
| `REQNAME → PR_EMP` join | `TRY_CAST(h.REQNAME AS decimal(5,0)) = e.empno` |
| Dept-by-user lookup | Join `PO_IndentAppUser` directly — no `PP_PASSWD` join needed |

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

## UI/UX Design Correction Handling

### Trigger phrase

When the user says any of the following, activate this workflow immediately:

> *"UI/UX correction received"* | *"design correction"* | *"first-level approval correction"* | *"UI feedback from [name]"*

### Input format — any of these are accepted

| User provides | Claude action |
|---|---|
| Pasted email body | Extract correction items from email text |
| Pasted Word / Excel table | Parse rows as correction items |
| File path to PDF / Word / Excel | Read the file, extract correction items |
| Screenshot or image | Read visually, extract correction items |

The user does NOT need to fill any template. Just paste or point to the source and say "process this."

### Processing steps (run for every correction)

1. **Extract** — pull every correction item from the input (screen, element, current vs required)
2. **Classify each item:**
   - **Cosmetic** — label text, colour, spacing, alignment, font, placeholder, icon → fix inline
   - **Functional** — logic, validation, field add/remove, API behaviour, workflow, calculation → CR only
   - When in doubt → classify as Functional → raise CR
3. **Cosmetic fixes** — apply immediately; commit format:
   ```
   Fix [UI-C##]: [what changed] in [filename] at [line ref]
   Example: Fix UI-C01: 'dept' → 'Department' in PRHeaderV1.tsx L42
   ```
4. **Functional items** — do NOT touch code; raise a CR Document per item:
   ```
   CR Document
   ──────────────────────────────────────
   UI Correction Ref : UI-F[nn]
   Screen / Component: [screen and component name]
   FSD Section       : Section [x.x] (if known)
   Current Behaviour : [one sentence]
   Required Behaviour: [one sentence]
   ──────────────────────────────────────
   ```
5. **Report back** — after processing all items:
   - Table: `# | Item | Classification | Action Taken / CR Raised`
   - Files changed with line references (cosmetic fixes)
   - CR Documents (functional items — no code written)
   - Open questions (if any ambiguity found)

### Hard rules

- Do NOT assume any business rule from a design correction
- If a correction contradicts the FSD → STOP, flag the conflict, ask before proceeding
- Approval level (first / second) does not change the Cosmetic vs Functional classification rule

---

## Testing

- Framework: xUnit + Moq + FluentAssertions + AutoFixture (backend), Vitest (frontend)
- Pattern: Arrange / Act / Assert
- Mock all dependencies in unit tests — tests are organised under `Spinrise.Tests/Areas/<Module>/`
- Test naming convention: `{MethodName}_{Condition}_{ExpectedResult}`
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

## Prompt Library

Reusable master prompts live in `D:\SpinriseV2\Prompts\`. Always load a saved prompt before starting a large feature — they encode project context, rules, and lessons from past sessions.

| File | Use Case |
|---|---|
| `PROMPT_01_FULLSTACK_FEATURE.md` | Before building any new screen or API endpoint |
| `PROMPT_02_UIUX_HTML.md` | Before generating any ERP screen HTML |
| `PROMPT_03_EMAIL_TASK_EXTRACTION.md` | Morning email parsing → daily task list |
| `PROMPT_04_SESSION_STARTUP.md` | First message every Claude Code session |
| `PROMPT_05_ARCHITECTURE_AUDIT.md` | End of sprint / weekly clean architecture review |

**Usage:** `Read D:\SpinriseV2\Prompts\PROMPT_01_FULLSTACK_FEATURE.md, then execute for [MODULE NAME]`

---

## Developer Habits

These habits prevent the most common quality failures in this project.

### Prompting

- **One concern per prompt.** Never mix API + SP + React component in a single message — Claude loses focus mid-generation. Break into three sequential prompts.
- **@file references, not paste.** Use `@ServiceName.cs` instead of pasting file content. Pasting wastes 2,000–4,000 tokens and makes context degrade faster.
- **Write a prompt file first** for any feature spanning more than two files. Save to `D:\SpinriseV2\Prompts\prompt_[module]_[YYYYMMDD].md`, then reference it with `Read @...` in the first message.
- **Ask "why" after every fix.** After any bug fix: *"Explain why this caused the bug and what to check next time this pattern is written."* Builds skill, not dependency.

### Session management

- **Read the worklog first — hard rule.** First action every session: `Read Docs/ChangeLog/[yesterday].md`. Identify what was left incomplete and continue from there. Do not start new work until prior WIP is confirmed resolved or explicitly deferred.
- **Start with the checklist.** After reading the worklog, run `git status` — confirm no stray uncommitted changes before touching any file.
- **15-turn rule.** After 15 turns on one module, start a new conversation. Reference prior work with `Read @worklog_[YYYYMMDD].md`.

### Slash commands

Use these slash commands consistently — they exist to catch mistakes before they reach production:

| Command | When to use |
|---|---|
| `/review` | After **every** generated file — before accepting it |
| `/explain` | When Claude output is unclear or you don't understand the reasoning |
| `/fix @file` | When patching a specific bug — attach the file so Claude sees the exact context |

Do not skip `/review` on the assumption that the output "looks right." The review step has caught silent regressions and wrong SP column names multiple times.

### Output validation

Before applying or committing any Claude-generated output:

- **Diff first.** Read the full diff before applying. If an edit replaces more than expected, stop and ask.
- **C# / TypeScript:** Verify the method signature matches the interface. Verify no new `using` import introduces an unintended dependency.
- **SQL:** Execute on test DB (`SpinRiseSaranya` / JAT on 172.16.16.52\sql2016) and verify result set columns match what the C# DTO expects. Never touch `merged.sql` / `merged_jat.sql` before a successful test run.
- **JSON payloads:** Check the exact property names passed to Dapper match the SP parameter names (case-insensitive, but spelling must match exactly).
- **GST routing:** When building line-level save logic, ensure `igstPer`/`igstAmt` are zeroed for LOCAL route and `cgstPer`/`sgstPer`/their amounts are zeroed for IGST route before sending to the SP. The SP trusts the payload — it does not apply route-based guards.

### Code quality

- **Tests alongside features.** Every new service method → add *"Write 3 xUnit tests: happy path, null/invalid input, exception case."*
- **Review every generated file.** Run `/review` before accepting any generated file. For SQL: execute on test DB before touching production `merged.sql`.
- **Architecture self-check.** After any multi-file feature: run `PROMPT_05_ARCHITECTURE_AUDIT.md` and verify all layers get PASS.

---

## Deployment

### Environment

| Layer | URL | Host |
|---|---|---|
| Frontend | `http://172.16.16.40:3000` | IIS on Windows Server |
| Backend API | `http://172.16.16.40:5001` | IIS on Windows Server |
| SQL Server | `172.16.16.52\sql2016` | Database: `SpinRiseSaranya` / `JAT` |

### Deployment Checklist (run before every deploy)

```
DEPLOYMENT CHECKLIST — [Module] — [Date]
──────────────────────────────────────
[ ] APIs validated against FSD
[ ] Stored Procedures verified on test DB
[ ] merged.sql / merged_jat.sql contains all SP changes from this session/sprint
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
Open merged.sql or merged_jat.sql in SSMS → Execute against target DB
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
dotnet test --filter "ClassName~PrServiceTests"          # single test class
dotnet test --filter "FullyQualifiedName~AddAsync_Valid"  # single test method
dotnet publish Spinrise.API/Spinrise.API.csproj -c Release -o <path>
```

### Frontend
```
cd Development/spinrise-web
npm run dev          # dev server → http://localhost:5173
npm run build        # tsc -b && vite build (type-checks then bundles)
npm run lint         # ESLint (flat config, typescript-eslint + react-hooks)
npm run test         # Vitest run (all unit tests, jsdom environment)
npm run test:watch   # Vitest watch mode
npm run test:coverage          # coverage report (text + HTML)
npx vitest run src/features/po # single feature test suite
npm run test:e2e               # Playwright end-to-end
npm run test:e2e:amendment     # single Playwright spec
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

M01 spans two databases — PR and PO sub-modules are on different DBs:

| | M01 PR — Purchase Requisition | M01 PO — PR to PO Transfer + PO Approval | M02 — RMI Purchase Order |
|---|---|---|---|
| **Database** | `SpinRiseSaranya` | `JAT` | `JAT` |
| **UnitOfWork** | `IUnitOfWork` | `IJATUnitOfWork` | `IJATUnitOfWork` |
| **Merged deploy file** | `merged.sql` | `merged_jat.sql` | `merged_jat.sql` |
| **SP prefix** | `ksp_PR_*` | `ksp_PO_*` | `ksp_RMI_PO_*` |
| **Branch** | `feature/m01-pr` | `feature/m01-po` | `feature/m02-*` |

**Critical:** Never commit PO Entry/Approval changes to `feature/m01-pr` — that branch protects live PR code at JAT + SCMTS. PO changes go to `feature/m01-po`.

All `ksp_PO_*` stored procedures deploy via `merged_jat.sql` (not `merged.sql`).

---

## Persistent Tools

### Email Agent

Never rediscover these paths — they are confirmed and stable.

| Item | Path |
|---|---|
| Script | `D:\SpinriseV2\Tools\email_agent\email_agent.py` |
| Config | `D:\SpinriseV2\Tools\email_agent\config.json` |
| Thunderbird INBOX | `C:\Users\Admin\AppData\Roaming\Thunderbird\Profiles\fjzej4xv.default-release\ImapMail\mail.kalsofte.com\INBOX` |
| Sent folder | `C:\Users\Admin\AppData\Roaming\Thunderbird\Profiles\fjzej4xv.default-release\ImapMail\mail.kalsofte.com\INBOX.sbd\Sent` |
| Email summary (MD) | `D:\SpinriseV2\Docs\Email\EmailSummary.md` |
| Task log (Excel) | `D:\SpinriseV2\Docs\Email\EmailTasks.xlsx` |
| Claude prompts | `D:\SpinriseV2\Docs\Email\prompt_YYYYMMDD.md` |
| Attachments extracted | `D:\SpinriseV2\Docs\Extracted\` |

**Provider:** Anthropic Claude Haiku (`claude-haiku-4-5-20251001`) — API key set in config.json.

**Run:** `python D:\SpinriseV2\Tools\email_agent\email_agent.py`

**Sender weights** (in config.json): `ceo@kalsofte.com` / `md@kalsofte.com` → Highest; `qa@kalsofte.com` / `muthuvel` → High.
