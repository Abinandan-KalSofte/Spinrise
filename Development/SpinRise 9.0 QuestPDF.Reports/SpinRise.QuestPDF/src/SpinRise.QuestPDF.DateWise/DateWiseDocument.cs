using System.Globalization;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace SpinRise.QuestPDF.DateWise;

/// <summary>
/// QuestPDF document for the Date-Wise PR report, rendered in the same Crystal-faithful
/// visual language as the Department-Wise / Item-Wise reports:
///  • Tahoma; title 11pt, unit 9pt, body 8pt.
///  • Centred title block: DIV_PRINTNAME, then "(Unit - DIV_UNITNAME)".
///  • Sub-header: "Purchase Requisition List From .. To .." (maroon) | "Option : Date wise"
///    (teal, page-centred) | date · time · "Page X of Y" (black).
///  • Purple single-row column header with FULL names (QA directive 7 June): PR No · Item Code ·
///    Item Description · Unit · Department Name · Indent Quantity · Required Quantity ·
///    Ordered Quantity · Received Quantity · Status.
///  • Each PR date is a group: a green "PR Date : dd/MM/yy" banner shown once with the PR
///    lines beneath. NO quantity totals anywhere — CEO direction (7 June): totals across
///    heterogeneous Units of Measure are meaningless, same ruling as Department-Wise.
///  • Plain-black status text. "@Kalsofte" footer. Dates render dd/MM/yy.
///
/// Data source mirrors <c>KSP_PR_DateWise</c> (including its extra qtyind column).
/// </summary>
public sealed class DateWiseDocument : IDocument
{
    // ---- Crystal palette ------------------------------------------------------------------
    private const string Navy    = "#000080";
    private const string Maroon  = "#800000";
    private const string Teal    = "#008080";
    private const string Purple  = "#800080";
    private const string Green   = "#008000";
    private const string Black   = "#000000";
    private const string Grey    = "#808080";
    private const string Font    = "Tahoma";
    private const string QtyFmt  = "#,##0.000";

    // ---- Column widths (pt) — landscape A4 minus margins. Sum = 813. ----------------------
    // Indent Quantity column dropped per user request (12 Jun); its 70pt is spread across
    // the qty + description columns so the grid still fills the printable width.
    private const float W1 = 48;    // PR No.
    private const float W2 = 68;    // Item Code
    private const float W3 = 220;   // Item Description
    private const float W4 = 40;    // Unit
    private const float W5 = 120;   // Department Name
    private const float W6 = 80;    // Required Quantity
    private const float W7 = 80;    // Ordered Quantity
    private const float W8 = 80;    // Received Quantity
    private const float W9 = 77;    // Status

    private readonly IReadOnlyList<DateWiseRow> _rows;
    private readonly DateWiseParameters _parameters;
    private readonly string _printName;
    private readonly string _unitName;

    public DateWiseDocument(IReadOnlyList<DateWiseRow> rows, DateWiseParameters parameters)
    {
        _rows = rows;
        _parameters = parameters;
        _printName = rows.Select(r => r.DivPrintName).FirstOrDefault(n => !string.IsNullOrWhiteSpace(n)) ?? "COMPANY NAME";
        _unitName  = rows.Select(r => r.DivUnitName).FirstOrDefault(n => !string.IsNullOrWhiteSpace(n)) ?? "";
    }

    public DocumentMetadata GetMetadata() => new()
    {
        Title  = "Purchase Requisition Report - Date Wise",
        Author = "SpinRise",
    };

    public void Compose(IDocumentContainer container)
    {
        container.Page(page =>
        {
            page.Size(PageSizes.A4.Landscape());
            page.MarginTop(10);
            page.MarginBottom(8);
            page.MarginLeft(17);
            page.MarginRight(11);
            page.DefaultTextStyle(t => t.FontFamily(Font).FontSize(8).FontColor(Black));

            page.Header().Element(ComposeTitle);
            page.Content().Element(ComposeContent);
            page.Footer().Element(ComposeFooter);
        });
    }

    // -------------------------------------------------------------------------- Title ------
    private void ComposeTitle(IContainer container)
    {
        container.Column(col =>
        {
            col.Item().Text(t => { t.AlignCenter(); t.Span(_printName).FontFamily(Font).FontSize(11).Bold().FontColor(Navy); });
            if (!string.IsNullOrWhiteSpace(_unitName))
                col.Item().Text(t => { t.AlignCenter(); t.Span(FormatUnit(_unitName)).FontFamily(Font).FontSize(9).Bold().FontColor(Navy); });

            // Period (left) + date/time/page (right); "Option : Date wise" page-centred overlay.
            col.Item().PaddingTop(4).Layers(layers =>
            {
                layers.PrimaryLayer().Row(r =>
                {
                    r.RelativeItem().Text(t =>
                    {
                        t.AlignLeft();
                        t.Span($"Purchase Requisition List  From {_parameters.FromDate:dd/MM/yy} To {_parameters.ToDate:dd/MM/yy}")
                         .FontSize(10).Bold().FontColor(Maroon);
                    });
                    r.RelativeItem().Text(t =>
                    {
                        t.AlignRight();
                        t.DefaultTextStyle(x => x.FontSize(8).FontColor(Black));
                        var now = DateTime.Now;
                        t.Span($"{now:dd/MM/yy}     {now:h:mm:ss tt}     Page ");
                        t.CurrentPageNumber();
                        t.Span(" of ");
                        t.TotalPages();
                    });
                });
                layers.Layer().AlignMiddle().Text(t =>
                {
                    t.AlignCenter();
                    t.Span("Option : Date wise").FontSize(8).Bold().FontColor(Teal);
                });
            });
            col.Item().PaddingTop(3).LineHorizontal(0.75f).LineColor(Black);
        });
    }

    // -------------------------------------------------------------------------- Content ----
    private void ComposeContent(IContainer container)
    {
        if (_rows.Count == 0)
        {
            container.PaddingVertical(20).AlignCenter()
                .Text("No purchase requisitions found for the selected criteria.")
                .Bold().FontColor(Navy);
            return;
        }

        var ordered = _rows
            .OrderBy(r => r.PrDate)
            .ThenBy(r => ParsePrNo(r.PrNo))
            .ThenBy(r => r.ItemCode, StringComparer.OrdinalIgnoreCase)
            .ToList();

        container.Table(table =>
        {
            table.ColumnsDefinition(c =>
            {
                c.ConstantColumn(W1);
                c.ConstantColumn(W2);
                c.ConstantColumn(W3);
                c.ConstantColumn(W4);
                c.ConstantColumn(W5);
                c.ConstantColumn(W6);
                c.ConstantColumn(W7);
                c.ConstantColumn(W8);
                c.ConstantColumn(W9);
            });

            // ---- Repeating purple column header (full names — QA directive 7 June) --------
            table.Header(h =>
            {
                HCell(h, "PR. No.");
                HCell(h, "Item Code");
                HCell(h, "Item Description");
                HCell(h, "Unit", Align.Center);
                HCell(h, "Department Name");
                HCell(h, "Required Quantity", Align.Right);
                HCell(h, "Ordered Quantity", Align.Right);
                HCell(h, "Received Quantity", Align.Right, padR: 8);
                HCell(h, "Status", Align.Center);

                // One continuous rule under the whole header — a single full line, not
                // per-column segments (whose differing cell heights read as a broken line).
                h.Cell().ColumnSpan(9).PaddingTop(1).LineHorizontal(0.75f).LineColor(Black);
            });

            // ---- PR-Date groups ------------------------------------------------------------
            foreach (var g in ordered.GroupBy(r => r.PrDate?.Date))
            {
                var label = g.Key.HasValue
                    ? g.Key.Value.ToString("dd/MM/yy", CultureInfo.InvariantCulture)
                    : "(no date)";
                table.Cell().ColumnSpan(9).PaddingLeft(2).PaddingTop(4).PaddingBottom(1)
                     .Text(t => t.Span($"PR Date :   {label}").FontFamily(Font).FontSize(8).Bold().FontColor(Maroon));

                foreach (var r in g)
                {
                    DCell(table, r.PrNo);
                    DCell(table, r.ItemCode, GreenStyle);
                    DCell(table, r.ItemName);
                    DCell(table, r.Uom, BodyStyle, Align.Center);
                    DCell(table, r.DepName);
                    DCell(table, r.QtyReqd.ToString(QtyFmt, CultureInfo.InvariantCulture), BodyStyle, Align.Right);
                    DCell(table, r.QtyOrdered.ToString(QtyFmt, CultureInfo.InvariantCulture), BodyStyle, Align.Right);
                    DCell(table, r.QtyReceived.ToString(QtyFmt, CultureInfo.InvariantCulture), BodyStyle, Align.Right, padR: 8);
                    DCell(table, r.PrStatus, BodyStyle, Align.Left, padL: 4);
                }
            }
            // ---- Grand Total row -----------------------------------------------------------
            var totReqd     = _rows.Sum(r => r.QtyReqd);
            var totOrdered  = _rows.Sum(r => r.QtyOrdered);
            var totReceived = _rows.Sum(r => r.QtyReceived);

            // Separator line after the last data row.
            table.Cell().ColumnSpan(9).PaddingTop(1).LineHorizontal(0.75f).LineColor(Black);

            // Label spans the first 5 non-qty columns; qty cells fill the remaining 3; Status blank.
            table.Cell().ColumnSpan(5)
                 .PaddingLeft(4).PaddingVertical(2)
                 .Text(t => { t.AlignRight(); t.Span("Grand Total :").FontFamily(Font).FontSize(8).Bold().FontColor(Black); });

            TCell(table, totReqd.ToString(QtyFmt, CultureInfo.InvariantCulture));
            TCell(table, totOrdered.ToString(QtyFmt, CultureInfo.InvariantCulture));
            TCell(table, totReceived.ToString(QtyFmt, CultureInfo.InvariantCulture), padR: 8);

            // Status column — blank in the grand total row.
            table.Cell().Height(0);

            // Closing line at the end of the report.
            table.Cell().ColumnSpan(9).PaddingTop(1).LineHorizontal(0.75f).LineColor(Black);
        });
    }

    // ---- Cell helpers ----------------------------------------------------------------------
    private enum Align { Left, Center, Right }

    private static void HCell(TableCellDescriptor h, string text, Align align = Align.Left,
                              float padL = 2, float padR = 2)
    {
        h.Cell().PaddingLeft(padL).PaddingRight(padR).PaddingVertical(1)
         .Text(t => { ApplyAlign(t, align); t.Span(text).FontFamily(Font).FontSize(8).Bold().FontColor(Purple); });
    }

    private static void DCell(TableDescriptor table, string text, Action<TextSpanDescriptor>? style = null,
                              Align align = Align.Left, float padL = 2, float padR = 2)
    {
        table.Cell().PaddingLeft(padL).PaddingRight(padR).PaddingTop(1).PaddingBottom(1)
             .Text(t => { ApplyAlign(t, align); var s = t.Span(text); (style ?? BodyStyle)(s); });
    }

    private static void ApplyAlign(TextDescriptor t, Align a)
    {
        if (a == Align.Right) t.AlignRight();
        else if (a == Align.Center) t.AlignCenter();
        else t.AlignLeft();
    }

    private static void GreenStyle(TextSpanDescriptor s) => s.FontFamily(Font).FontSize(8).Bold().FontColor(Green);
    private static void BodyStyle(TextSpanDescriptor s)  => s.FontFamily(Font).FontSize(8).FontColor(Black);

    private static void TCell(TableDescriptor table, string text, float padL = 2, float padR = 2)
    {
        table.Cell()
             .PaddingLeft(padL).PaddingRight(padR).PaddingVertical(2)
             .Text(t => { t.AlignRight(); t.Span(text).FontFamily(Font).FontSize(8).Bold().FontColor(Black); });
    }

    private static int ParsePrNo(string? prNo) =>
        int.TryParse(prNo, NumberStyles.Integer, CultureInfo.InvariantCulture, out var n) ? n : int.MaxValue;

    private static string FormatUnit(string unit)
    {
        var u = unit.Trim();
        return u.StartsWith("(Unit", StringComparison.OrdinalIgnoreCase) ? u : $"(Unit - {u})";
    }

    // -------------------------------------------------------------------------- Footer -----
    private static void ComposeFooter(IContainer container)
    {
        container.Text(t => t.Span("@Kalsofte").FontFamily(Font).FontSize(8).Bold().FontColor(Grey));
    }
}
