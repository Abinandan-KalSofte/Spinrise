# SPINRISE — Plan Document
**Date:** 03 June 2026  
**Author:** Abinandan N  
**Purpose:** (1) PO Entry architecture review prep for 6 PM CEO meeting  
**&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;** (2) Multi-client source code management strategy recommendation

---

## PART 1 — Meeting Prep: PR→PO Architecture Reuse Review

> **Objective:** Identify what can be directly reused from PR sprint into PO Entry.  
> Come to the 6 PM meeting with a clear answer on component reuse, DTO patterns, and new challenges.

---

### 1.1 Frontend (React) — Reuse Inventory

| Component / File | PR Location | PO Entry Action | Notes |
|---|---|---|---|
| `usePRFormCore.ts` | `features/pr/hooks/` | **Replicate** as `usePoEntryFormCore.ts` | Core form state machine: mode (new/view/edit), dirty tracking, lookup loading, save/delete flow — identical pattern |
| `PRHeaderV1.tsx` | `features/pr/components/pr-form/` | **Replicate** as `PoEntryHeader.tsx` | Ant Design Form header layout — fields differ but structure identical |
| `PRLineItemsTable.tsx` | `features/pr/components/pr-form/` | **Replicate** as `PoLineItemsTable.tsx` | PO adds Rate, Amount, Tax columns — base editable grid pattern same |
| `PRToolbar.tsx` | `features/pr/components/pr-form/` | **Replicate** as `PoToolbar.tsx` | New / Save / Delete / Print / Prev / Next — identical toolbar actions |
| `PRKPIStrip.tsx` | `features/pr/components/pr-form/` | **Replicate** as `PoKpiStrip.tsx` | KPI values differ (PO value, items count) — layout identical |
| `ItemSelectionModal.tsx` | `features/pr/components/` | **Reuse directly** | Same item master. No change needed. |
| `MachineLookupModal.tsx` | `features/pr/components/pr-form/` | **Reuse directly** | Same machine master. Same SP. |
| `CostCentreLookupModal.tsx` | `features/pr/components/pr-form/` | **Reuse directly** | Same cost centre master. Same SP. |
| `PrStatusBadge.tsx` | `features/pr/components/` | **Replicate** as `PoStatusBadge.tsx` | PO has its own status set — component pattern identical |
| `PrPrintPreviewModal.tsx` | `features/pr/components/` | **Replicate** as `PoPrintPreviewModal.tsx` | QuestPDF + same PDF preview pattern |
| `PRPickerModal.tsx` | `features/pr/components/pr-form/` | **Adapt** as `PoPickerModal.tsx` (list/navigation picker) | Same picker pattern — different SP behind it |
| `PrApprovalGrid.tsx` | `features/pr/components/first-approval/` | **Replicate** for PO First Level Approval | Grid + inline edit approval pattern — identical for PO |
| `PrApprovalHeader.tsx` | `features/pr/components/first-approval/` | **Replicate** | Header display pattern same |
| `usePrStore.ts` | `features/pr/store/` | **Replicate** as `usePoStore.ts` | Zustand store shape identical — different state keys |
| `prApi.ts` | `features/pr/api/` | **Replicate** as `poApi.ts` | `const BASE = 'po'` — all `apiHelpers.get/post` calls same pattern |
| `useAuthStore` usage | across PR hooks/pages | **Reuse directly** | `divCode`, `processingDate`, `user` — same for PO |

**Shared layer — zero changes needed:**  
`shared/api/client.ts` · `shared/lib/errorHandler.ts` · `shared/lib/dateUtils.ts` · `shared/components/AppShell.tsx` · `themeConfig.ts`

---

### 1.2 Backend (.NET) — Reuse Inventory

| Layer | PR Pattern | PO Entry Action |
|---|---|---|
| **Repository** | `PrRepository.cs` → `IPrRepository` | Create `PoRepository.cs` → `IPoRepository`. Constructor: `IUnitOfWork _uow`. All methods: `QueryFirstOrDefaultAsync` / `QueryAsync` / `ExecuteAsync` with SP constants. Identical pattern. |
| **Service** | `PrService.cs` → `IPrService` | Create `PoService.cs` → `IPoService`. Inject repository. Map DTOs. Same async/await pattern. |
| **Controller** | `PrController.cs` → `BaseApiController` | Create `PoController.cs`. All endpoints return `ApiResponse<T>`. Pagination on list endpoints. Identical structure. |
| **DTOs** | `PrHeaderDto`, `PrLineDto`, `SavePrRequest` etc. | Create `PoHeaderDto`, `PoLineDto`, `SavePoRequest`, `SavePoLineRequest`, `DeletePoRequest`. Same nullability and DataAnnotations pattern. |
| **StoredProcedures.cs** | `Spinrise.Shared/Constants/StoredProcedures.cs` | Add `public static class Po { ... }` section. All `ksp_PO_*` SP name constants go here. Never hardcode SP names in repository. |
| **UnitOfWork** | `IUnitOfWork` (JAT DB) | PO Entry uses JAT DB → same `IUnitOfWork`. No `IJATUnitOfWork` switch needed for M01 PO. |
| **ApiResponse wrapper** | `Spinrise.Shared` | No change. Reuse directly. |
| **DI Registration** | `Program.cs` | Add `builder.Services.AddScoped<IPoRepository, PoRepository>()` and `IPoService, PoService`. Same pattern as PR registrations. |

**Folder to create:**
```
Spinrise.Application/Areas/PurchaseOrder/PoEntry/
├── DTOs/
├── Interfaces/
└── Services/

Spinrise.Infrastructure/Areas/PurchaseOrder/PoEntry/
└── PoRepository.cs

Spinrise.API/Areas/PurchaseOrder/PoEntry/
└── PoController.cs
```

---

### 1.3 SP Pattern — Reuse

| PR SP | PO Entry Equivalent | Reuse Level |
|---|---|---|
| `ksp_PR_GetParameters` | `ksp_PO_GetParameters` | Replicate — reads `po_para` for PO-specific config |
| `ksp_PR_PreAddChecks` | `ksp_PO_PreAddChecks` | Replicate — period open check, add permission check |
| `ksp_PR_GetDepartments` | Reuse same SP via shared endpoint | Same dept master |
| `ksp_PR_GetItems` | Reuse same SP | Same item master |
| `ksp_PR_GetMachineLookup` | Reuse same SP | Same machine master |
| `ksp_PR_GetLastRecord` | `ksp_PO_GetLastRecord` | Replicate — same nav pattern but `PO_POH` table |
| `ksp_PR_GetById` | `ksp_PO_GetById` | Replicate |
| `ksp_PR_GetList` | `ksp_PO_GetList` | Replicate with pagination |
| `ksp_PR_Save` | `ksp_PO_Save` | Replicate — TRY/CATCH + ROLLBACK + rowversion enforcement |
| `ksp_PR_Delete` | `ksp_PO_Delete` | Replicate |
| `ksp_PR_GetPrint` | `ksp_PO_GetPrint` | Replicate for QuestPDF print |

---

### 1.4 New Technical Challenges — PO Entry vs PR

| Challenge | Detail | Approach |
|---|---|---|
| **Supplier Lookup** | PR has no supplier. PO requires supplier selection from `mm_SUPmas`. | New SP: `ksp_PO_GetSuppliers`. New modal: `SupplierLookupModal.tsx`. Pattern mirrors `ItemSelectionModal`. |
| **Rate / Amount Calculation** | PR only has Qty. PO line has Qty × Rate = Amount. Real-time calculation in the grid. | Add `rate` and `amount` columns to `PoLineItemsTable`. Calculate `amount = qty * rate` on cell change in the row handler. 3dp/4dp/2dp format per CLAUDE.md standard. |
| **PR-to-PO Population** | When creating a PO from an approved PR, header + lines must pre-populate from the PR. | New SP: `ksp_PO_GetApprovedPRForPO`. New modal: `ApprovedPrPickerModal.tsx` (similar to `PRPickerModal`). On selection, populate PO form state from PR data. |
| **Partial PO Against PR** | One approved PR can produce multiple POs (partial fulfillment). Outstanding qty tracking needed. | SP must track `QTYPO` (qty already on PO) vs `QTYAPPROVED`. Display balance qty in line grid. Verify against `PO_PRL.QTYPO` in live schema before SP authoring. |
| **Terms / Delivery Fields** | PO typically has Delivery Date, Payment Terms, Delivery Address fields not in PR. | Confirm exact fields with FSD before building. Do not assume from VB6. |
| **PO Number Generation** | PR uses `MAX(PRNO)+1`. PO number generation pattern needs confirmation. | Read `PO_POH` table structure in `JAT_Schema.md`. Confirm with Sasi whether MAX()+1 or a separate sequence. **Do not assume.** |
| **Currency** | PO may be multi-currency depending on supplier. | Confirm with FSD if currency is in scope for M01 PO Entry or deferred. |

---

### 1.5 Suggested Screen Structure for 6 PM Discussion

```
PO Entry Screen
├── Toolbar        (New | Save | Delete | Print | << Prev | Next >> | Close)
├── KPI Strip      (PO No | PO Date | Supplier | Total Value | Status)
├── Header Form    (PO No | PO Date | Supplier | Dept | ReqBy | Del Date | Terms | Ref PR)
├── Line Items Tab (Item | Desc | Qty | Unit | Rate | Amount | Machine | CostCentre | Remarks)
└── Footer         (Total Qty | Total Amount | Status Badge | Last Saved info)
```

This mirrors the PR Entry screen layout. Main additions: Supplier field in header, Rate/Amount in lines.

---

## PART 2 — Multi-Client Source Code Management Strategy

> **Context:** SPINRISE is migrating VB6 applications to React + ASP.NET Core.  
> Database is NOT migrated — existing SQL Server tables remain.  
> Deployment: each client runs IIS + SQL Server on Windows Server / Windows 10/11.  
> Currently live: JAT, SCMTS. More clients in future.  
> Challenge: how to maintain, upgrade, and add client-specific features without forking the codebase.

---

### 2.1 Core Problem Statement

| Scenario | Risk if not managed |
|---|---|
| Bug fix for one client | If deployed incorrectly, affects all clients |
| Feature added for one client | Code fork per client — becomes unmaintainable at 5+ clients |
| Client-specific upgrade | No rollback path if deployment history not tracked |
| Standard upgrade to all clients | Cannot push confidently if client configs not separated |

---

### 2.2 Recommended Strategy — Configuration-Driven Single Codebase

**Principle:** One codebase. One `main` branch. Client differences handled by configuration — never by code forks.

This follows the same principle the CEO already established: *"customer-specific VB6 features will not be carried into SPINRISE standard build."* Features go into the standard build or they are handled via CR at time of customer upgrade. This applies equally to the code structure.

---

### 2.3 Git Branching Strategy

```
main                        ← Standard SPINRISE build. Production-ready at all times.
develop                     ← Integration branch. Sprint work merged here.
feature/mXX-<slug>          ← Feature branches (already in use).
hotfix/<ref>                ← Emergency fix branches — merge to main + develop.
release/v<X.Y>              ← Release tags cut from main before each client deployment.
```

**What NOT to do:**
```
❌ client/jat               ← Do not create per-client branches
❌ client/scmts             ← Gets out of hand at 5+ clients
❌ main-jat, main-scmts     ← Diverges permanently — no recovery path
```

**Why:** Per-client branches mean every bug fix must be cherry-picked to N branches. At 10 clients that is 10 cherry-picks per fix. At 20 clients it is unworkable. Configuration solves the same problem cleanly.

---

### 2.4 Client Configuration Structure

Each client gets their own config files, never their own code branch.

**Backend — per-client `appsettings`:**

```
Spinrise.API/
├── appsettings.json              ← Base config (all shared settings)
├── appsettings.Production.json   ← Production overrides (no secrets)
└── ClientConfigs/
    ├── appsettings.jat.json      ← JAT-specific overrides
    └── appsettings.scmts.json    ← SCMTS-specific overrides
```

`appsettings.jat.json` example:
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=172.16.16.52\\sql2016;Database=JAT;..."
  },
  "ClientConfig": {
    "ClientCode": "JAT",
    "ClientName": "Sathy Silks (P) Ltd",
    "EnableSMSNotification": false,
    "EnableSecondLevelApproval": false,
    "DirectApproval": true,
    "ActiveModules": ["PR", "PO"]
  }
}
```

**Frontend — per-client env file:**

```
spinrise-web/
├── .env.production               ← Base production env
├── .env.jat                      ← JAT API URL + client code
└── .env.scmts                    ← SCMTS API URL + client code
```

`.env.jat` example:
```
VITE_API_BASE_URL=http://172.16.16.40:5001
VITE_CLIENT_CODE=JAT
VITE_CLIENT_NAME=Sathy Silks (P) Ltd
```

---

### 2.5 Feature Flags — Handling Client-Specific Behaviour

For features that differ between clients (SMS, approval levels, module enable/disable), use a `ClientFeatureService` that reads from config. **No `if (clientCode == "JAT")` in business logic.**

**Backend:**

```csharp
// Spinrise.Application/ClientConfig/IClientFeatureService.cs
public interface IClientFeatureService
{
    bool IsEnabled(string featureKey);
    string Get(string key);
}

// Usage in service:
if (_features.IsEnabled("EnableSMSNotification"))
{
    // SMS logic
}
```

**Frontend:**

```typescript
// src/shared/config/clientFeatures.ts
export const ClientFeatures = {
  enableSMS: import.meta.env.VITE_ENABLE_SMS === 'true',
  enableSecondLevelApproval: import.meta.env.VITE_ENABLE_SECOND_LEVEL === 'true',
}

// Usage in component:
{ClientFeatures.enableSecondLevelApproval && <SecondLevelApprovalTab />}
```

**Rule:** If more than 2 clients need a feature, it becomes standard. If only 1 client needs it, it stays behind a flag.

---

### 2.6 Deployment Package Per Client

Create a deployment script per client that selects the correct config at build/publish time.

**Backend deploy script (`deploy_jat.ps1`):**
```powershell
# Stop IIS app pool
Stop-WebAppPool -Name "SpinriseJAT"

# Publish with JAT config
dotnet publish Spinrise.API/Spinrise.API.csproj -c Release `
  -o "C:\inetpub\wwwroot\SpinriseJAT" `
  /p:EnvironmentName=jat

# Copy client config
Copy-Item "Spinrise.API/ClientConfigs/appsettings.jat.json" `
  "C:\inetpub\wwwroot\SpinriseJAT\appsettings.json" -Force

# Start IIS app pool
Start-WebAppPool -Name "SpinriseJAT"

Write-Host "JAT deployment complete — $(Get-Date)"
```

**Frontend build script (`build_jat.ps1`):**
```powershell
Copy-Item ".env.jat" ".env.production.local" -Force
npm run build
# Copy dist/ to IIS site root for JAT port
```

---

### 2.7 Client Deployment History Tracking

Create a `Docs/Clients/` folder per client. This replaces ad-hoc email tracking.

```
Docs/Clients/
├── JAT/
│   ├── config_reference.md        ← Connection strings, IIS paths, DB name
│   ├── deployment_history.md      ← Date | Version | SPs deployed | Notes
│   └── merged_jat.sql             ← All SP changes applied to JAT DB
└── SCMTS/
    ├── config_reference.md
    ├── deployment_history.md
    └── merged_scmts.sql
```

`deployment_history.md` format:
```markdown
| Date       | Version | Deployed By | SPs Changed                | Notes               |
|------------|---------|-------------|----------------------------|---------------------|
| 2026-06-03 | v1.0    | Abinandan   | ksp_PR_Save, ksp_po_final.. | M01 PR+PO go-live   |
| 2026-06-05 | v1.0.1  | Abinandan   | ksp_PR_UndoCancellation     | DEF-PRC-02 hotfix   |
```

**Each deployment gets a Git tag:**
```
git tag -a deploy/jat/v1.0.1-2026-06-05 -m "JAT hotfix DEF-PRC-02"
git tag -a deploy/scmts/v1.0.1-2026-06-05 -m "SCMTS hotfix DEF-PRC-02"
```

This gives an instant rollback path: checkout the previous tag, rebuild, redeploy.

---

### 2.8 Upgrade / Downgrade Per Client

| Scenario | Action |
|---|---|
| **Standard upgrade to all clients** | Merge to `main`, cut release tag, run deploy scripts for each client sequentially. Test on one client first. |
| **Upgrade only JAT (not SCMTS yet)** | Cut tag from `main` for JAT only. SCMTS tag remains on previous release. Run only `deploy_jat.ps1`. |
| **Rollback JAT to previous version** | `git checkout deploy/jat/v1.0` → rebuild → run `deploy_jat.ps1`. No code changes needed — config is separate. |
| **Client-specific hotfix** | `hotfix/<ref>` branch from `main` → merge to `main` → tag for specific client → deploy. Never a permanent per-client branch. |
| **New client onboarding** | Create `ClientConfigs/appsettings.<newclient>.json` + deploy scripts. Tag first deployment. Add to `Docs/Clients/`. No code change needed if standard build. |

---

### 2.9 What Happens With the DB (Client-Specific SQL)

Since the database is NOT migrated (tables stay as-is), client differences exist in DB config rows (`po_para`, `pp_divmas`, `PO_IndentAppUser`) not in schema. This is already handled correctly.

For stored procedures:
- All SPs go into `merged.sql` (SpinRiseSaranya standard) or `merged_jat.sql` (JAT)
- Extend to `merged_scmts.sql` for SCMTS
- `CREATE OR ALTER PROCEDURE` ensures re-runnable without drop

**Do not create client-specific SP forks.** If a client needs different SP behaviour, use a config-driven parameter to the SP (`@ClientCode` or `@FeatureFlag`), not a separate SP.

---

### 2.10 Summary — What to Implement Now vs Later

| Action | When | Owner |
|---|---|---|
| Create `Docs/Clients/JAT/` and `Docs/Clients/SCMTS/` folders | This week | Abinandan / Sasi |
| Move JAT + SCMTS config into `appsettings.jat.json` / `appsettings.scmts.json` | This sprint | Abinandan |
| Write `deploy_jat.ps1` and `deploy_scmts.ps1` | This sprint | Abinandan |
| Apply Git deployment tags retroactively for today's go-live | Today | Abinandan |
| Add `IClientFeatureService` skeleton | Before next client onboarded | Abinandan |
| `ClientFeatures` constants in frontend | Before next client onboarded | Abinandan |
| Per-client `deployment_history.md` — start tracking from today | Today | Abinandan |

**The critical rule:** Resist the temptation to fork code per client. Every code fork is a future merge debt. Configuration solves 90% of client variation at zero code cost.

---

*Plan prepared: 03 June 2026 | For discussion at 6 PM CEO Review Meeting*
