using System.Drawing;
using System.Globalization;
using OfficeOpenXml;
using OfficeOpenXml.Style;
using SpinRise.Reports.Common.Abstractions;
using SpinRise.Reports.Common.Models;

namespace SpinRise.Reports.DepartmentWise;

/// <summary>
/// Renders the Department-Wise PR report to Excel with EPPlus, matching the visual style of the
/// PR Date-Wise sample (colours / fonts / bands / zebra striping / grand total).
///
/// The only structural difference from DateWise: rows are grouped by DEPARTMENT, and the per-row
/// "Department" column is replaced by "PR Date" (since the department is now the group banner).
/// </summary>
public sealed class DepartmentWiseReport : IReport<DepartmentWiseParameters>
{
    public string Code => "PR-DEPTWISE";

    private readonly DepartmentWiseRepository _repository;

    public DepartmentWiseReport(DepartmentWiseRepository repository) => _repository = repository;

    // --- palette (ARGB lifted directly from the sample workbook) ---
    private static readonly Color Navy    = Color.FromArgb(0x1F, 0x38, 0x64); // banner / labels / PR No
    private static readonly Color TitleBg = Color.FromArgb(0x2F, 0x54, 0x96); // report title row
    private static readonly Color BandBg  = Color.FromArgb(0x44, 0x72, 0xC4); // period strip + col headers
    private static readonly Color GroupBg = Color.FromArgb(0xBD, 0xD7, 0xEE); // group banner
    private static readonly Color ZebraBg = Color.FromArgb(0xEB, 0xF3, 0xFB); // alternate detail row
    private static readonly Color TotalBg = Color.FromArgb(0xD6, 0xE4, 0xF0); // grand total
    private static readonly Color QtyText = Color.FromArgb(0x1F, 0x49, 0x7D); // quantity numerals
    private static readonly Color Orange  = Color.FromArgb(0xFF, 0xA5, 0x00); // "Ordered" status

    private const string FontName  = "Calibri";
    private const string QtyFormat = "#,##0.000";

    // --- columns (A..M) ---
    private const int CPrNo = 1, CItemCode = 2, CItemName = 3 /* :F */, CUnit = 7,
                      CDate = 8 /* :I */, CReqd = 10, COrdered = 11, CReceived = 12,
                      CStatus = 13, CLast = 13;

    private const int FirstDataRow = 8; // first group banner sits on row 8 (rows 1-7 are frozen head)

    public async Task<ReportResult> GenerateAsync(
        DepartmentWiseParameters parameters, CancellationToken cancellationToken = default)
    {
        var company = await _repository.GetCompanyAsync(parameters.DivCode, cancellationToken);
        var rows    = await _repository.GetRowsAsync(parameters, cancellationToken);
        return Render(company, rows, parameters);
    }

    /// <summary>
    /// Pure rendering with no database dependency, so the exact output can be produced/verified
    /// from any data set (see the <c>--demo</c> path in Program.cs).
    /// </summary>
    public ReportResult Render(
        CompanyHeader? company, IReadOnlyList<DepartmentWiseRow> rows, DepartmentWiseParameters parameters)
    {
        using var package = new ExcelPackage();
        var ws = package.Workbook.Worksheets.Add("PR Deptwise Report");

        SetColumnWidths(ws);
        WriteHead(ws, company, parameters);
        ws.View.FreezePanes(FirstDataRow, 1);

        var row = FirstDataRow;
        var detailIndex = 0;
        var lineCount = 0;

        foreach (var group in rows.GroupBy(r => (r.DepCode, r.DepName)))
        {
            WriteGroupBanner(ws, row++, group.Key.DepCode, group.Key.DepName);

            string? previousPrNo = null;
            foreach (var line in group)
            {
                WriteDetail(ws, row++, line, zebra: detailIndex % 2 == 1, suppressPrNo: line.PrNo == previousPrNo);
                previousPrNo = line.PrNo;
                detailIndex++;
                lineCount++;
            }
        }

        if (lineCount == 0)
        {
            var none = ws.Cells[row, 1, row, CLast];
            none.Merge = true;
            none.Value = "No purchase requisitions found for the selected criteria.";
            SetFont(none, 9, bold: true, Navy);
            none.Style.HorizontalAlignment = ExcelHorizontalAlignment.Center;
        }
        // CEO #9: Department-Wise has NO totals (department-level or grand).
        // Different items under a department carry different UOMs (NOS / LTR / BOX / SET / ...),
        // so summing their quantities would be meaningless. Report ends with the last detail row.

        return new ReportResult
        {
            Content  = package.GetAsByteArray(),
            FileName = $"PRDeptwise_{parameters.FromDate:yyyy-MM-dd}_{parameters.ToDate:yyyy-MM-dd}.xlsx",
            RowCount = lineCount,
        };
    }

    private static void SetColumnWidths(ExcelWorksheet ws)
    {
        ws.Column(1).Width  = 7.71;   // PR No.
        ws.Column(2).Width  = 11.71;  // Item Code
        ws.Column(3).Width  = 14.71;  // Item Name (merged C:F)
        ws.Column(5).Width  = 6.71;
        ws.Column(7).Width  = 7.71;   // Unit
        ws.Column(8).Width  = 14.71;  // PR Date (merged H:I)
        ws.Column(9).Width  = 8.71;
        // CEO #4: widened to fit the full header names "Required/Ordered/Received Quantity".
        ws.Column(10).Width = 17.71;  // Required Quantity
        ws.Column(11).Width = 17.71;  // Ordered Quantity
        ws.Column(12).Width = 17.71;  // Received Quantity
    }

    private static void WriteHead(ExcelWorksheet ws, CompanyHeader? company, DepartmentWiseParameters p)
    {
        // Row 1 — company name
        ws.Row(1).Height = 24;
        var company1 = ws.Cells[1, 1, 1, CLast];
        company1.Merge = true;
        company1.Value = string.IsNullOrWhiteSpace(company?.DivName) ? "COMPANY NAME" : company!.DivName;
        SetFont(company1, 13, bold: true, Color.White);
        Fill(company1, Navy);
        Center(company1, wrap: true);

        // Row 2 — report title
        ws.Row(2).Height = 18;
        var title = ws.Cells[2, 1, 2, CLast];
        title.Merge = true;
        title.Value = "PURCHASE REQUISITION REPORT — DEPARTMENT WISE";
        SetFont(title, 11, bold: true, Color.White);
        Fill(title, TitleBg);
        Center(title, wrap: true);

        // Row 3 — period (left) + printed (right)
        ws.Row(3).Height = 15;
        var period = ws.Cells[3, 1, 3, 7];
        period.Merge = true;
        period.Value = $"Period :  {p.FromDate:dd-MM-yyyy}  –  {p.ToDate:dd-MM-yyyy}"
                       + (string.IsNullOrWhiteSpace(p.DepCode) ? "" : $"     Department :  {p.DepCode}");
        SetFont(period, 9, bold: false, Color.White);
        Fill(period, BandBg);
        period.Style.HorizontalAlignment = ExcelHorizontalAlignment.Left;
        period.Style.VerticalAlignment = ExcelVerticalAlignment.Center;

        var printed = ws.Cells[3, 8, 3, CLast];
        printed.Merge = true;
        printed.Value = $"Printed :  {DateTime.Now:dd-MM-yyyy  HH:mm}";
        SetFont(printed, 9, bold: false, Color.White);
        Fill(printed, BandBg);
        printed.Style.HorizontalAlignment = ExcelHorizontalAlignment.Right;
        printed.Style.VerticalAlignment = ExcelVerticalAlignment.Center;

        // Row 4 — thin navy rule
        ws.Row(4).Height = 3;
        Fill(ws.Cells[4, 1, 4, CLast], Navy);

        // Row 5 — blue band + "Quantity" super-header over J:L
        ws.Row(5).Height = 14;
        Fill(ws.Cells[5, 1, 5, CLast], BandBg);
        var qtyHead = ws.Cells[5, CReqd, 5, CReceived];
        qtyHead.Merge = true;
        qtyHead.Value = "◄──────── Quantity ────────►";
        SetFont(qtyHead, 9, bold: true, Color.White);
        Center(qtyHead, wrap: true);

        // Row 6 — column headers
        ws.Row(6).Height = 20;
        var header = ws.Cells[6, 1, 6, CLast];
        Fill(header, BandBg);
        SetFont(header, 9, bold: true, Color.White);
        header.Style.Border.Bottom.Style = ExcelBorderStyle.Medium;

        HeaderCell(ws, 6, CPrNo, CPrNo, "PR No.", ExcelHorizontalAlignment.Center);
        HeaderCell(ws, 6, CItemCode, CItemCode, "Item Code", ExcelHorizontalAlignment.Left);
        HeaderCell(ws, 6, CItemName, 6, "Item Name", ExcelHorizontalAlignment.Left);
        HeaderCell(ws, 6, CUnit, CUnit, "Unit", ExcelHorizontalAlignment.Center);
        HeaderCell(ws, 6, CDate, 9, "PR Date", ExcelHorizontalAlignment.Left);
        // CEO #4: full descriptive headers, no abbreviations.
        HeaderCell(ws, 6, CReqd, CReqd, "Required Quantity", ExcelHorizontalAlignment.Right);
        HeaderCell(ws, 6, COrdered, COrdered, "Ordered Quantity", ExcelHorizontalAlignment.Right);
        HeaderCell(ws, 6, CReceived, CReceived, "Received Quantity", ExcelHorizontalAlignment.Right);
        HeaderCell(ws, 6, CStatus, CStatus, "Status", ExcelHorizontalAlignment.Center);

        // Row 7 — thin navy rule
        ws.Row(7).Height = 3;
        Fill(ws.Cells[7, 1, 7, CLast], Navy);
    }

    private static void HeaderCell(ExcelWorksheet ws, int row, int from, int to, string text, ExcelHorizontalAlignment h)
    {
        var cell = ws.Cells[row, from, row, to];
        if (to > from) cell.Merge = true;
        cell.Value = text;
        cell.Style.HorizontalAlignment = h;
        cell.Style.VerticalAlignment = ExcelVerticalAlignment.Center;
        cell.Style.WrapText = true;
    }

    private static void WriteGroupBanner(ExcelWorksheet ws, int row, string depCode, string depName)
    {
        ws.Row(row).Height = 15;
        var band = ws.Cells[row, 1, row, CLast];
        band.Merge = true;
        band.Value = $"  Department :   {depCode}   —   {depName}";
        SetFont(band, 9, bold: true, Navy);
        Fill(band, GroupBg);
        band.Style.HorizontalAlignment = ExcelHorizontalAlignment.Left;
        band.Style.VerticalAlignment = ExcelVerticalAlignment.Center;
        band.Style.WrapText = true;
        band.Style.Border.Bottom.Style = ExcelBorderStyle.Thin;
    }

    private static void WriteDetail(ExcelWorksheet ws, int row, DepartmentWiseRow line, bool zebra, bool suppressPrNo)
    {
        ws.Row(row).Height = 14;
        ws.Cells[row, CItemName, row, 6].Merge = true; // Item Name C:F
        ws.Cells[row, CDate, row, 9].Merge = true;     // PR Date  H:I

        var full = ws.Cells[row, 1, row, CLast];
        SetFont(full, 9, bold: false, Color.Black);
        Fill(full, zebra ? ZebraBg : Color.White);
        full.Style.Border.Bottom.Style = ExcelBorderStyle.Thin;

        // CEO #10: PR No. shown only on the first line of each PR (bold navy, centred);
        // continuation lines remain BLANK — per direct CEO guidance, no marker character.
        var prNo = ws.Cells[row, CPrNo];
        prNo.Value = suppressPrNo ? null : line.PrNo;
        SetFont(prNo, 9, bold: true, Navy);
        prNo.Style.HorizontalAlignment = ExcelHorizontalAlignment.Center;
        prNo.Style.VerticalAlignment = ExcelVerticalAlignment.Bottom;

        // Item Code
        var itemCode = ws.Cells[row, CItemCode];
        itemCode.Value = line.ItemCode;
        itemCode.Style.HorizontalAlignment = ExcelHorizontalAlignment.Left;
        itemCode.Style.VerticalAlignment = ExcelVerticalAlignment.Center;

        // Item Name
        var itemName = ws.Cells[row, CItemName];
        itemName.Value = line.ItemName;
        itemName.Style.HorizontalAlignment = ExcelHorizontalAlignment.Left;
        itemName.Style.VerticalAlignment = ExcelVerticalAlignment.Center;
        itemName.Style.WrapText = true;

        // Unit
        var unit = ws.Cells[row, CUnit];
        unit.Value = line.Uom;
        Center(unit, wrap: false);

        // PR Date (replaces Department, which is now the group)
        var date = ws.Cells[row, CDate];
        date.Value = line.PrDate?.ToString("dd-MM-yyyy", CultureInfo.InvariantCulture);
        date.Style.HorizontalAlignment = ExcelHorizontalAlignment.Left;
        date.Style.VerticalAlignment = ExcelVerticalAlignment.Center;

        // Quantities — dark-blue numerals, blanked when zero (matches the sample)
        QtyCell(ws, row, CReqd, line.QtyReqd);
        QtyCell(ws, row, COrdered, line.QtyOrdered);
        QtyCell(ws, row, CReceived, line.QtyReceived);

        // Status — bold, colour-coded
        var status = ws.Cells[row, CStatus];
        status.Value = line.PrStatus;
        SetFont(status, 9, bold: true, StatusColor(line.PrStatus));
        Center(status, wrap: false);
    }

    private static void QtyCell(ExcelWorksheet ws, int row, int col, decimal value)
    {
        var cell = ws.Cells[row, col];
        cell.Value = value;                              // CEO #3: always render, never blank — 0 → "0.000"
        cell.Style.Numberformat.Format = QtyFormat;
        cell.Style.Font.Color.SetColor(QtyText);
        cell.Style.HorizontalAlignment = ExcelHorizontalAlignment.Right;
        cell.Style.VerticalAlignment = ExcelVerticalAlignment.Center;
    }

    // CEO #9: WriteTotal removed by design — no quantity totals on Department-Wise.

    private static Color StatusColor(string status) => status switch
    {
        "Ordered"                        => Orange,                           // confirmed
        "Received"                       => Color.FromArgb(0x2E, 0x7D, 0x32), // green
        "Fore Closed" or "Force Closed"  => Color.FromArgb(0xC0, 0x39, 0x2B), // red
        "Cancelled"                      => Color.FromArgb(0xC0, 0x39, 0x2B), // red
        "Requested"                      => Color.FromArgb(0x70, 0x70, 0x70), // grey
        _                                => Navy,                             // approval levels
    };

    // --- tiny styling helpers ---
    private static void SetFont(ExcelRange r, float size, bool bold, Color color)
    {
        r.Style.Font.Name = FontName;
        r.Style.Font.Size = size;
        r.Style.Font.Bold = bold;
        r.Style.Font.Color.SetColor(color);
    }

    private static void Fill(ExcelRange r, Color color)
    {
        r.Style.Fill.PatternType = ExcelFillStyle.Solid;
        r.Style.Fill.BackgroundColor.SetColor(color);
    }

    private static void Center(ExcelRange r, bool wrap)
    {
        r.Style.HorizontalAlignment = ExcelHorizontalAlignment.Center;
        r.Style.VerticalAlignment = ExcelVerticalAlignment.Center;
        r.Style.WrapText = wrap;
    }
}
