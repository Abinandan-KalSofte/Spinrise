using System.Globalization;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using Spinrise.Application.Areas.PurchaseOrder.PrReport.DTOs;

namespace Spinrise.API.Areas.PurchaseOrder.Reports;

public sealed class PrDeptWiseDocument : IDocument
{
    private const string Navy   = "#000080";
    private const string Maroon = "#800000";
    private const string Teal   = "#008080";
    private const string Purple = "#800080";
    private const string Green  = "#008000";
    private const string Black  = "#000000";
    private const string Grey   = "#808080";
    private const string Font   = "Tahoma";
    private const string QtyFmt = "#,##0.000";

    private const float W1 = 48;    // PR No.
    private const float W2 = 58;    // PR Date
    private const float W3 = 70;    // Item Code
    private const float W4 = 226;   // Item Name
    private const float W5 = 44;    // Unit
    private const float W6 = 80;    // Required Quantity
    private const float W7 = 80;    // Ordered Quantity
    private const float W8 = 80;    // Received Quantity
    private const float W9 = 127;   // Status

    private readonly IReadOnlyList<PrDeptWiseRowDto> _rows;
    private readonly PrReportRequest _request;
    private readonly string _printName;
    private readonly string _unitName;

    public PrDeptWiseDocument(IReadOnlyList<PrDeptWiseRowDto> rows, PrReportRequest request)
    {
        _rows = rows;
        _request = request;
        _printName = rows.Select(r => r.DivPrintName).FirstOrDefault(n => !string.IsNullOrWhiteSpace(n)) ?? "COMPANY NAME";
        _unitName  = rows.Select(r => r.DivUnitName).FirstOrDefault(n => !string.IsNullOrWhiteSpace(n)) ?? "";
    }

    public DocumentMetadata GetMetadata() => new()
    {
        Title  = "Purchase Requisition Report - Department Wise",
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

    private void ComposeTitle(IContainer container)
    {
        container.Column(col =>
        {
            col.Item().Text(t => { t.AlignCenter(); t.Span(_printName).FontFamily(Font).FontSize(11).Bold().FontColor(Navy); });
            if (!string.IsNullOrWhiteSpace(_unitName))
                col.Item().Text(t => { t.AlignCenter(); t.Span(FormatUnit(_unitName)).FontFamily(Font).FontSize(9).Bold().FontColor(Navy); });

            col.Item().PaddingTop(4).Layers(layers =>
            {
                layers.PrimaryLayer().Row(r =>
                {
                    r.RelativeItem().Text(t =>
                    {
                        t.AlignLeft();
                        t.Span($"Purchase Requisition List  From {_request.FromDate:dd/MM/yy} To {_request.ToDate:dd/MM/yy}")
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
                    t.Span("Option : Department wise").FontSize(8).Bold().FontColor(Teal);
                });
            });
            col.Item().PaddingTop(3).LineHorizontal(0.75f).LineColor(Black);
        });
    }

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
            .OrderBy(r => r.DepName, StringComparer.OrdinalIgnoreCase)
            .ThenBy(r => ParsePrNo(r.PrNo))
            .ThenBy(r => r.PrDate)
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

            table.Header(h =>
            {
                HCell(h, "PR. No.");
                HCell(h, "PR. Date");
                HCell(h, "Item Code");
                HCell(h, "Item Description");
                HCell(h, "Unit", Align.Center);
                HCell(h, "Required Quantity", Align.Right);
                HCell(h, "Ordered Quantity", Align.Right);
                HCell(h, "Received Quantity", Align.Right, padR: 8);
                HCell(h, "Status", Align.Center);
                h.Cell().ColumnSpan(9).PaddingTop(1).LineHorizontal(0.75f).LineColor(Black);
            });

            foreach (var g in ordered.GroupBy(r => (r.DepCode, r.DepName)))
            {
                var dep = string.IsNullOrWhiteSpace(g.Key.DepCode)
                    ? g.Key.DepName
                    : $"{g.Key.DepCode}  —  {g.Key.DepName}";
                table.Cell().ColumnSpan(9).PaddingLeft(2).PaddingTop(4).PaddingBottom(1)
                     .Text(t => t.Span($"Department :   {dep}").FontFamily(Font).FontSize(8).Bold().FontColor(Green));

                foreach (var r in g)
                {
                    DCell(table, r.PrNo);
                    DCell(table, r.PrDate?.ToString("dd/MM/yy", CultureInfo.InvariantCulture) ?? "");
                    DCell(table, r.ItemCode, GreenStyle);
                    DCell(table, r.ItemName);
                    DCell(table, r.Uom, BodyStyle, Align.Center);
                    DCell(table, r.QtyReqd.ToString(QtyFmt, CultureInfo.InvariantCulture), BodyStyle, Align.Right);
                    DCell(table, r.QtyOrdered.ToString(QtyFmt, CultureInfo.InvariantCulture), BodyStyle, Align.Right);
                    DCell(table, r.QtyReceived.ToString(QtyFmt, CultureInfo.InvariantCulture), BodyStyle, Align.Right, padR: 8);
                    DCell(table, r.PrStatus, BodyStyle, Align.Left, padL: 4);
                }
            }

            table.Cell().ColumnSpan(9).PaddingTop(2).LineHorizontal(0.75f).LineColor(Black);
        });
    }

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

    private static int ParsePrNo(string? prNo) =>
        int.TryParse(prNo, NumberStyles.Integer, CultureInfo.InvariantCulture, out var n) ? n : int.MaxValue;

    private static string FormatUnit(string unit)
    {
        var u = unit.Trim();
        return u.StartsWith("(Unit", StringComparison.OrdinalIgnoreCase) ? u : $"(Unit - {u})";
    }

    private static void ComposeFooter(IContainer container)
    {
        container.Text(t => t.Span("@Kalsofte").FontFamily(Font).FontSize(8).Bold().FontColor(Grey));
    }
}
