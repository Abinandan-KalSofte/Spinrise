# SpinRise Reports

Standalone .NET 8 solution that re-implements the SpinRise Crystal reports as **EPPlus** (Excel `.xlsx`) reports. Each report is its own project; shared plumbing lives in `SpinRise.Reports.Common`.

```
SpinRise.Reports.sln
├── SpinRise.Reports.Common/          shared: DB connection, IReport/ReportResult, CompanyHeader,
│                                       Excel/PrReportStyle (palette, fonts, status colours)
├── SpinRise.Reports.DepartmentWise/   Purchase Requisition – Department Wise (direct table query)
└── SpinRise.Reports.ItemWise/         Purchase Requisition – Item Wise (dbo.KSP_PR_ITEMWISE proc)
```

Run any report by swapping the project name in the commands below
(`SpinRise.Reports.DepartmentWise` ↔ `SpinRise.Reports.ItemWise`).

* **EPPlus 4.5.3.3** (last LGPL release — free for commercial use; no license key needed).
* No server is hard-coded — the connection string is configuration only.

---

## Prerequisites

* .NET 8 SDK (`dotnet --version` ≥ 8.0)

## 1. Generate a sample WITHOUT a database (quick look)

From the solution folder:

```powershell
dotnet run --project SpinRise.Reports.DepartmentWise -- --demo
```

This writes `PRDeptwise_<from>_<to>.xlsx` (built-in sample data) into the current folder. Use it to review colours/layout instantly.

## 2. Generate against the real database

1. Edit `SpinRise.Reports.DepartmentWise/appsettings.json` and set the connection string:

   ```json
   "ConnectionStrings": {
     "ScmMills": "Data Source=YOURSERVER\\SQL2016;Initial Catalog=scmmills;User ID=sa;Password=***;TrustServerCertificate=True;Encrypt=False;"
   },
   "DivCode": "01",
   "FromDate": "2026-04-01",
   "ToDate":   "2026-04-24",
   "DepCode":  null
   ```
   *(Catalog was `scmmills` / `JATNEW` in the original `.rpt` — point it at whichever is live.)*

2. Run:

   ```powershell
   dotnet run --project SpinRise.Reports.DepartmentWise
   ```

   Optional output path:

   ```powershell
   dotnet run --project SpinRise.Reports.DepartmentWise -- --out C:\Temp\DeptWise.xlsx
   ```

## 3. Call it from your ASP.NET API later

The report returns bytes — no files, no `HttpContext` dependency:

```csharp
var report = new DepartmentWiseReport(
    new DepartmentWiseRepository(new SqlConnectionFactory(connectionString)));

ReportResult result = await report.GenerateAsync(new DepartmentWiseParameters
{
    DivCode = "01", FromDate = from, ToDate = to, DepCode = null
});

return File(result.Content, result.ContentType, result.FileName); // ASP.NET controller
```

(Or register `IDbConnectionFactory`, `DepartmentWiseRepository`, `DepartmentWiseReport` in DI.)

---

## ItemWise specifics

* Data comes from the **`dbo.KSP_PR_ITEMWISE`** stored proc (joins + status decode live in the SP).
* `ItemFilter` parameter: **`"A"` = all items**, or a **comma-separated list** of item codes (e.g. `"320B006,9002001"`). The SP ignores any "to item".
* Grouped by **Item**, with a per-item subtotal band and a grand total (`SUBTOTAL(9,…)`, which ignores the nested subtotals).
* Status text is **already decoded by the SP** — note its `prstatus` CASE maps **`X` → "Requested"** and does not handle null/`secondapp`, which differs from DepartmentWise's formula (`X` → "Cancelled"). If you want them identical, reconcile inside the SP.

## Status mapping (DepartmentWise / DateWise)

`PrStatus.cs` replicates the owner-supplied Crystal formula: null→Requested, O→Ordered, C→Received,
Z→"Fore Closed", D→Final Level Approved, secondapp='Y'→Second Level Approved, F→First Level Approved, X→Cancelled.

## Open items

* **Selection parameters** — DepartmentWise uses Division + PR-date range + optional Department; ItemWise uses Division + date range + item filter. Adjust the `*Parameters` / repository if a real prompt differs.
* **DepartmentWise status column width** — DepartmentWise can take the same widened Status column ItemWise uses (one line in `SetColumnWidths`) if long labels clip.
