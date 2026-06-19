using System.Globalization;
using OfficeOpenXml;
using OfficeOpenXml.Style;
using SpinRise.Reports.Common.Abstractions;
using static SpinRise.Reports.Common.Excel.PrReportStyle;
using Color = System.Drawing.Color;

namespace SpinRise.Reports.ItemWise;

/// <summary>
/// Renders the Item-Wise PR report (dbo.KSP_PR_ITEMWISE) to Excel with EPPlus, in the shared
/// PR-report style. Rows are grouped by ITEM, each item gets a subtotal band, and a grand total
/// closes the sheet. Status text arrives already decoded by the SP — we only colour-code it.
/// </summary>
public sealed class ItemWiseReport : IReport<ItemWiseParameters>
{
    public string Code => "PR-ITEMWISE";

    private readonly ItemWiseRepository _repository;
    public ItemWiseReport(ItemWiseRepository repository) => _repository = repository;

    // same 13-column grid (A..M) as the other PR reports
    private const int CIndentNo = 1, CIndentDt = 2, CDept = 3 /* :F */, CUnit = 7,
                      CReqdDate = 8 /* :I */, CReqd = 10, COrd = 11, CRec = 12,
                      CStatus = 13, CLast = 13;
    private const int FirstDataRow = 8;

    public async Task<ReportResult> GenerateAsync(ItemWiseParameters parameters, CancellationToken cancellationToken = default)
    {
        var rows = await _repository.GetRowsAsync(parameters, cancellationToken);
        return Render(rows, parameters);
    }

    /// <summary>Pure rendering (no DB) so output can be produced/verified from any data set.</summary>
    public ReportResult Render(IReadOnlyList<ItemWiseRow> rows, ItemWiseParameters parameters)
    {
        using var package = new ExcelPackage();
        var ws = package.Workbook.Worksheets.Add("PR Itemwise Report");

        var company = rows.Select(r => r.DivName).FirstOrDefault(n => !string.IsNullOrWhiteSpace(n)) ?? "COMPANY NAME";

        SetColumnWidths(ws);
        WriteHead(ws, company!, parameters);
        ws.View.FreezePanes(FirstDataRow, 1);

        var row = FirstDataRow;
        var detailIndex = 0;
        var lineCount = 0;

        var ordered = rows.OrderBy(r => r.ItemCode, StringComparer.OrdinalIgnoreCase)
                          .ThenBy(r => r.IndentNo)
                          .ToList();

        foreach (var group in ordered.GroupBy(r => (r.ItemCode, r.ItemName)))
        {
            WriteGroupBanner(ws, row, group.Key.ItemCode, group.Key.ItemName);
            row++;

            var groupFirst = row;
            foreach (var line in group)
            {
                WriteDetail(ws, row, line, zebra: detailIndex % 2 == 1);
                row++; detailIndex++; lineCount++;
            }

            WriteSubtotal(ws, row, groupFirst, row - 1);
            row++;
        }

        if (lineCount == 0)
        {
            var none = ws.Cells[row, 1, row, CLast];
            none.Merge = true;
            none.Value = "No purchase requisitions found for the selected criteria.";
            SetFont(none, 9, true, Navy);
            none.Style.HorizontalAlignment = ExcelHorizontalAlignment.Center;
        }
        else
        {
            WriteGrandTotal(ws, row, FirstDataRow, row - 1, lineCount);
        }

        return new ReportResult
        {
            Content  = package.GetAsByteArray(),
            FileName = $"PRItemwise_{parameters.FromDate:yyyy-MM-dd}_{parameters.ToDate:yyyy-MM-dd}.xlsx",
            RowCount = lineCount,
        };
    }

    private static void SetColumnWidths(ExcelWorksheet ws)
    {
        ws.Column(1).Width  = 9.71;   // Indent No
        ws.Column(2).Width  = 11.71;  // Indent Date
        ws.Column(3).Width  = 14.71;  // Department (merged C:F)
        ws.Column(5).Width  = 6.71;
        ws.Column(7).Width  = 7.71;   // Unit
        ws.Column(8).Width  = 11.71;  // Reqd Date (merged H:I)
        ws.Column(9).Width  = 8.71;
        // CEO #4: widened to fit the full header names "Required/Ordered/Received Quantity".
        ws.Column(10).Width = 17.71;  // Required Quantity
        ws.Column(11).Width = 17.71;  // Ordered Quantity
        ws.Column(12).Width = 17.71;  // Received Quantity
        ws.Column(13).Width = 19.71;  // Status (fits "Second Level Approved")
    }

    private static void WriteHead(ExcelWorksheet ws, string company, ItemWiseParameters p)
    {
        ws.Row(1).Height = 24;
        var c1 = ws.Cells[1, 1, 1, CLast]; c1.Merge = true; c1.Value = company;
        SetFont(c1, 13, true, Color.White); Fill(c1, Navy); Center(c1, true);

        ws.Row(2).Height = 18;
        var title = ws.Cells[2, 1, 2, CLast]; title.Merge = true;
        title.Value = "PURCHASE REQUISITION REPORT — ITEM WISE";
        SetFont(title, 11, true, Color.White); Fill(title, TitleBg); Center(title, true);

        ws.Row(3).Height = 15;
        var period = ws.Cells[3, 1, 3, 7]; period.Merge = true;
        var allItems = string.IsNullOrWhiteSpace(p.ItemFilter) || string.Equals(p.ItemFilter, "A", StringComparison.OrdinalIgnoreCase);
        period.Value = $"Period :  {p.FromDate:dd-MM-yyyy}  –  {p.ToDate:dd-MM-yyyy}" + (allItems ? "" : $"     Items :  {p.ItemFilter}");
        SetFont(period, 9, false, Color.White); Fill(period, BandBg);
        period.Style.HorizontalAlignment = ExcelHorizontalAlignment.Left;
        period.Style.VerticalAlignment = ExcelVerticalAlignment.Center;

        var printed = ws.Cells[3, 8, 3, CLast]; printed.Merge = true;
        printed.Value = $"Printed :  {DateTime.Now:dd-MM-yyyy  HH:mm}";
        SetFont(printed, 9, false, Color.White); Fill(printed, BandBg);
        printed.Style.HorizontalAlignment = ExcelHorizontalAlignment.Right;
        printed.Style.VerticalAlignment = ExcelVerticalAlignment.Center;

        ws.Row(4).Height = 3; Fill(ws.Cells[4, 1, 4, CLast], Navy);

        ws.Row(5).Height = 14; Fill(ws.Cells[5, 1, 5, CLast], BandBg);
        var qty = ws.Cells[5, CReqd, 5, CRec]; qty.Merge = true; qty.Value = "◄──────── Quantity ────────►";
        SetFont(qty, 9, true, Color.White); Center(qty, true);

        ws.Row(6).Height = 20;
        var header = ws.Cells[6, 1, 6, CLast]; Fill(header, BandBg); SetFont(header, 9, true, Color.White);
        header.Style.Border.Bottom.Style = ExcelBorderStyle.Medium;
        // CEO #4: full descriptive headers, no abbreviations.
        HeaderCell(ws, CIndentNo, CIndentNo, "PR No.", ExcelHorizontalAlignment.Center);
        HeaderCell(ws, CIndentDt, CIndentDt, "PR Date", ExcelHorizontalAlignment.Center);
        HeaderCell(ws, CDept, 6, "Department", ExcelHorizontalAlignment.Left);
        HeaderCell(ws, CUnit, CUnit, "Unit", ExcelHorizontalAlignment.Center);
        HeaderCell(ws, CReqdDate, 9, "Required Date", ExcelHorizontalAlignment.Center);
        HeaderCell(ws, CReqd, CReqd, "Required Quantity", ExcelHorizontalAlignment.Right);
        HeaderCell(ws, COrd, COrd, "Ordered Quantity", ExcelHorizontalAlignment.Right);
        HeaderCell(ws, CRec, CRec, "Received Quantity", ExcelHorizontalAlignment.Right);
        HeaderCell(ws, CStatus, CStatus, "Status", ExcelHorizontalAlignment.Center);

        ws.Row(7).Height = 3; Fill(ws.Cells[7, 1, 7, CLast], Navy);
    }

    private static void HeaderCell(ExcelWorksheet ws, int from, int to, string text, ExcelHorizontalAlignment h)
    {
        var cell = ws.Cells[6, from, 6, to];
        if (to > from) cell.Merge = true;
        cell.Value = text;
        cell.Style.HorizontalAlignment = h;
        cell.Style.VerticalAlignment = ExcelVerticalAlignment.Center;
        cell.Style.WrapText = true;
    }

    private static void WriteGroupBanner(ExcelWorksheet ws, int row, string itemCode, string itemName)
    {
        ws.Row(row).Height = 15;
        var band = ws.Cells[row, 1, row, CLast]; band.Merge = true;
        band.Value = $"  Item :   {itemCode}   —   {itemName}";
        SetFont(band, 9, true, Navy); Fill(band, GroupBg);
        band.Style.HorizontalAlignment = ExcelHorizontalAlignment.Left;
        band.Style.VerticalAlignment = ExcelVerticalAlignment.Center;
        band.Style.WrapText = true;
        band.Style.Border.Bottom.Style = ExcelBorderStyle.Thin;
    }

    private static void WriteDetail(ExcelWorksheet ws, int row, ItemWiseRow line, bool zebra)
    {
        ws.Row(row).Height = 14;
        ws.Cells[row, CDept, row, 6].Merge = true;      // Department C:F
        ws.Cells[row, CReqdDate, row, 9].Merge = true;  // Reqd Date  H:I

        var full = ws.Cells[row, 1, row, CLast];
        SetFont(full, 9, false, Color.Black);
        Fill(full, zebra ? ZebraBg : Color.White);
        full.Style.Border.Bottom.Style = ExcelBorderStyle.Thin;

        var no = ws.Cells[row, CIndentNo]; no.Value = line.IndentNo;
        SetFont(no, 9, true, Navy);
        no.Style.HorizontalAlignment = ExcelHorizontalAlignment.Center;
        no.Style.VerticalAlignment = ExcelVerticalAlignment.Bottom;

        var dt = ws.Cells[row, CIndentDt];
        dt.Value = line.IndentDt?.ToString("dd-MM-yyyy", CultureInfo.InvariantCulture);
        Center(dt, false);

        var dep = ws.Cells[row, CDept]; dep.Value = line.DepName;
        dep.Style.HorizontalAlignment = ExcelHorizontalAlignment.Left;
        dep.Style.VerticalAlignment = ExcelVerticalAlignment.Center;

        var unit = ws.Cells[row, CUnit]; unit.Value = line.Unit; Center(unit, false);

        var rd = ws.Cells[row, CReqdDate];
        rd.Value = line.ReqdDate?.ToString("dd-MM-yyyy", CultureInfo.InvariantCulture);
        Center(rd, false);

        // CEO #3 belt-and-braces: coalesce NULL -> 0 here so the cell always shows "0.000",
        // independent of whether the KSP_PR_ITEMWISE SP has been ALTERed to ISNULL the qtys.
        QtyCell(ws, row, CReqd, line.QtyReqd ?? 0m);
        QtyCell(ws, row, COrd,  line.QtyOrd  ?? 0m);
        QtyCell(ws, row, CRec,  line.QtyRec  ?? 0m);

        // CEO #2: rename legacy SP labels ("Fore Closed", "Indent", NULL) to SPINRISE standards
        // BEFORE writing + colour-coding, so both the value and the colour use the new label.
        var statusLabel = NormalizeStatus(line.PrStatus);
        var st = ws.Cells[row, CStatus]; st.Value = statusLabel;
        SetFont(st, 9, true, StatusColor(statusLabel)); Center(st, false);
    }

    /// <summary>
    /// Normalises status text coming from the <c>KSP_PR_ITEMWISE</c> stored proc to the
    /// SPINRISE standard labels mandated by the CEO. Also surfaces a sensible label when
    /// the SP returns NULL / blank (legacy ERP rendered that as visually empty / "Indent";
    /// SPINRISE renders it as "Requested").
    /// </summary>
    private static string NormalizeStatus(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw)) return "Requested";
        return raw switch
        {
            "Fore Closed" => "Force Closed",
            "Indent"      => "Requested",
            _             => raw,
        };
    }

    private static void QtyCell(ExcelWorksheet ws, int row, int col, decimal value)
    {
        var cell = ws.Cells[row, col];
        cell.Value = value;                              // CEO #3: always render, never blank — 0 → "0.000"
        SetFont(cell, 9, false, QtyText);
        cell.Style.Numberformat.Format = QtyFormat;
        cell.Style.HorizontalAlignment = ExcelHorizontalAlignment.Right;
        cell.Style.VerticalAlignment = ExcelVerticalAlignment.Center;
    }

    private static void WriteSubtotal(ExcelWorksheet ws, int row, int firstDetail, int lastDetail)
    {
        ws.Row(row).Height = 15;
        var label = ws.Cells[row, 1, row, 9]; label.Merge = true; label.Value = "Item Total";
        SetFont(label, 9, true, Navy); Fill(label, GroupBg);
        label.Style.HorizontalAlignment = ExcelHorizontalAlignment.Right;
        label.Style.VerticalAlignment = ExcelVerticalAlignment.Center;

        foreach (var (col, letter) in new[] { (CReqd, "J"), (COrd, "K"), (CRec, "L") })
        {
            var cell = ws.Cells[row, col];
            cell.Formula = $"SUBTOTAL(9,{letter}{firstDetail}:{letter}{lastDetail})";
            SetFont(cell, 9, true, Navy); Fill(cell, GroupBg);
            cell.Style.Numberformat.Format = QtyFormat;
            cell.Style.HorizontalAlignment = ExcelHorizontalAlignment.Right;
            cell.Style.VerticalAlignment = ExcelVerticalAlignment.Center;
        }
        Fill(ws.Cells[row, CStatus], GroupBg);
        ws.Cells[row, 1, row, CLast].Style.Border.Top.Style = ExcelBorderStyle.Thin;
    }

    private static void WriteGrandTotal(ExcelWorksheet ws, int row, int firstDataRow, int lastRow, int lineCount)
    {
        ws.Row(row).Height = 16;
        var label = ws.Cells[row, 1, row, 9]; label.Merge = true; label.Value = $"Grand Total :  {lineCount} line(s)";
        SetFont(label, 9, true, Navy); Fill(label, TotalBg);
        label.Style.HorizontalAlignment = ExcelHorizontalAlignment.Right;
        label.Style.VerticalAlignment = ExcelVerticalAlignment.Center;
        label.Style.WrapText = true;

        // SUBTOTAL(9,...) ignores the per-item SUBTOTAL rows inside the range, so totals don't double count.
        foreach (var (col, letter) in new[] { (CReqd, "J"), (COrd, "K"), (CRec, "L") })
        {
            var cell = ws.Cells[row, col];
            cell.Formula = $"SUBTOTAL(9,{letter}{firstDataRow}:{letter}{lastRow})";
            SetFont(cell, 9, true, Navy); Fill(cell, TotalBg);
            cell.Style.Numberformat.Format = QtyFormat;
            cell.Style.HorizontalAlignment = ExcelHorizontalAlignment.Right;
            cell.Style.VerticalAlignment = ExcelVerticalAlignment.Center;
        }
        Fill(ws.Cells[row, CStatus], TotalBg);
        ws.Cells[row, 1, row, CLast].Style.Border.Top.Style = ExcelBorderStyle.Medium;
    }
}
