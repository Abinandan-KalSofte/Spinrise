# SpinRise.QuestPDF

QuestPDF re-implementation of the SpinRise (Kalsofte ERP) reporting suite. Replaces the legacy Crystal Reports 8.5 `.rpt` definitions with a clean, multi-project .NET 8 solution.

## Solution structure

```
SpinRise.QuestPDF/
├── SpinRise.QuestPDF.sln
├── Directory.Build.props
└── src/
    ├── SpinRise.QuestPDF/                  # Main runner — dispatches to any report by code
    ├── SpinRise.QuestPDF.Common/           # Shared library: style, db, models, abstractions
    ├── SpinRise.QuestPDF.DepartmentWise/   # Department-Wise PR report (library)
    ├── SpinRise.QuestPDF.ItemWise/         # Item-Wise PR report (library)
    └── SpinRise.QuestPDF.DateWise/         # Date-Wise PR report (library)
```

The main project (`SpinRise.QuestPDF`) is the only executable; each report ships as a library so it can be embedded in the API host or driven from the runner.

## Reports

| Code                | Source `.rpt`           | Project                                  |
| ------------------- | ----------------------- | ---------------------------------------- |
| `PR-DEPTWISE`       | `DepartmentWise.rpt`    | `SpinRise.QuestPDF.DepartmentWise`       |
| `PR-ITEMWISE`       | `ItemWise.rpt`          | `SpinRise.QuestPDF.ItemWise`             |
| `PR-DATEWISE`       | `DateWise.rpt`          | `SpinRise.QuestPDF.DateWise`             |

## Running

```
dotnet run --project src/SpinRise.QuestPDF -- --report PR-DEPTWISE
dotnet run --project src/SpinRise.QuestPDF -- --report PR-DEPTWISE --demo
dotnet run --project src/SpinRise.QuestPDF -- --report PR-DEPTWISE --from 2026-05-01 --to 2026-05-31 --div 01 --out out.pdf

dotnet run --project src/SpinRise.QuestPDF -- --report PR-ITEMWISE
dotnet run --project src/SpinRise.QuestPDF -- --report PR-ITEMWISE --demo
dotnet run --project src/SpinRise.QuestPDF -- --report PR-ITEMWISE --from 2026-05-01 --to 2026-05-31 --div 01 --items 1104001,340A001 --out out.pdf

dotnet run --project src/SpinRise.QuestPDF -- --report PR-DATEWISE
dotnet run --project src/SpinRise.QuestPDF -- --report PR-DATEWISE --demo
dotnet run --project src/SpinRise.QuestPDF -- --report PR-DATEWISE --from 2025-05-01 --to 2025-05-31 --div 01 --fromdep 100 --todep 300 --out out.pdf
```

### CLI flags

| Flag        | Applies to     | Meaning                                              |
| ----------- | -------------- | --------------------------------------------------- |
| `--report`  | all            | Report code (`PR-DEPTWISE`, `PR-ITEMWISE`, `PR-DATEWISE`) |
| `--from`    | all            | Period start `yyyy-MM-dd`                           |
| `--to`      | all            | Period end `yyyy-MM-dd`                             |
| `--div`     | all            | Division code (e.g. `01`)                           |
| `--dep`     | Dept-/Date-Wise| Single department code (sets both ends of the range)|
| `--fromdep` | Dept-/Date-Wise| Department-range start (`@FrmDep`); omit = all      |
| `--todep`   | Dept-/Date-Wise| Department-range end (`@ToDep`); omit = all         |
| `--items`   | Item-Wise      | `A` = all, or CSV of item codes                     |
| `--out`     | all            | Output file path                                    |
| `--demo`    | all            | Use built-in sample data (no database)              |

## Visual language

Palette, font and column layout are taken from the customer-approved EPPlus reference
(`PRDeptwise_2026-05-01_2026-05-31.xlsx`):

| Token       | Hex       | Use                                  |
| ----------- | --------- | ------------------------------------ |
| Navy        | `#1F3864` | Company banner, PR No., labels       |
| TitleBg     | `#2F5496` | Report title row                     |
| BandBg      | `#4472C4` | Period strip + column header row     |
| GroupBg     | `#BDD7EE` | Department group banner              |
| ZebraBg     | `#EBF3FB` | Alternate detail row                 |
| QtyText     | `#1F497D` | Quantity numerals                    |
| Orange      | `#FFA500` | Status: Ordered                      |
| Green       | `#2E7D32` | Status: Received                     |
| Red         | `#C0392B` | Status: Force Closed / Cancelled     |
| Grey        | `#707070` | Status: Requested                    |

Font is Calibri throughout: 13pt company name, 11pt title, 9pt body. Quantity is rendered `#,##0.000`.
