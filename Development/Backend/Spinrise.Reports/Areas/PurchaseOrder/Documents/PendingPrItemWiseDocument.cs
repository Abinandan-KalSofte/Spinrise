using System.Globalization;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using Spinrise.Application.Areas.PurchaseOrder.PendingPrReport.DTOs;
using Spinrise.Application.Areas.PurchaseOrder.PrReport.DTOs;

namespace Spinrise.Reports.Areas.PurchaseOrder.Documents;

public sealed class PendingPrItemWiseDocument : IDocument
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

    private const float Indent = 30f;

    private const float W1 = 90;
    private const float W2 = 186;
    private const float W3 = 63;
    private const float W4 = 64;
    private const float W5 = 70;
    private const float W6 = 70;
    private const float W7 = 52;
    private const float W8 = 114;
    private const float W9 = 104;

    private readonly IReadOnlyList<PendingPrItemWiseRowDto> _rows;
    private readonly PrReportRequest _request;
    private readonly string _printName;
    private readonly string _unitName;

    public PendingPrItemWiseDocument(IReadOnlyList<PendingPrItemWiseRowDto> rows, PrReportRequest request)
    {
        _rows      = rows;
        _request   = request;
        _printName = rows.Select(r => r.DivPrintName)
                        .Concat(rows.Select(r => r.DivName))
                        .FirstOrDefault(n => !string.IsNullOrWhiteSpace(n)) ?? "COMPANY NAME";
        _unitName  = rows.Select(r => r.DivUnitName).FirstOrDefault(n => !string.IsNullOrWhiteSpace(n)) ?? "";
    }

    public DocumentMetadata GetMetadata() => new()
    {
        Title  = "Pending Purchase Requisition Report - Item Wise",
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
                        t.Span($"Pending Purchase Requisition List  From {_request.FromDate:dd/MM/yy} To {_request.ToDate:dd/MM/yy}")
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
                    t.Span("Option : Pending PR  —  Item wise").FontSize(8).Bold().FontColor(Teal);
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
                .Text("No pending purchase requisitions found for the selected criteria.")
                .Bold().FontColor(Navy);
            return;
        }

        var ordered = _rows
            .OrderBy(r => r.ItemCode, StringComparer.OrdinalIgnoreCase)
            .ThenBy(r => ParsePrNo(r.IndentNo))
            .ThenBy(r => r.IndentDt)
            .ToList();

        decimal totReqd = ordered.Sum(r => r.QtyReqd ?? 0m);
        decimal totOrd  = ordered.Sum(r => r.QtyOrd  ?? 0m);
        decimal totRec  = ordered.Sum(r => r.QtyRec  ?? 0m);

        container.Table(table =>
        {
            table.ColumnsDefinition(c =>
            {
                c.ConstantColumn(W1); c.ConstantColumn(W2); c.ConstantColumn(W3);
                c.ConstantColumn(W4); c.ConstantColumn(W5); c.ConstantColumn(W6);
                c.ConstantColumn(W7); c.ConstantColumn(W8); c.ConstantColumn(W9);
            });

            table.Header(h =>
            {
                HCell(h, "Item Code"); HCell(h, "Item Description"); HCell(h, ""); HCell(h, "");
                HCell(h, ""); HCell(h, ""); HCell(h, ""); HCell(h, ""); HCell(h, "");
                HCell(h, "PR. No.", padL: Indent); HCell(h, "PR. Date"); HCell(h, "Ref. No.");
                HCell(h, ""); HCell(h, ""); HCell(h, ""); HCell(h, "");
                HCell(h, "Remarks"); HCell(h, "Status", Align.Center);
                HCell(h, "Dept.Code", padL: Indent); HCell(h, "Department Name");
                HCell(h, "Unit", Align.Right);
                HCell(h, "Required Quantity", Align.Right);
                HCell(h, "Ordered Quantity", Align.Right);
                HCell(h, "Received Quantity", Align.Right, padR: 8);
                HCell(h, "Required Date", Align.Center);
                HCell(h, ""); HCell(h, "");
                h.Cell().ColumnSpan(9).PaddingTop(1).LineHorizontal(0.75f).LineColor(Black);
            });

            foreach (var g in ordered.GroupBy(r => (r.ItemCode ?? "").Trim().ToUpperInvariant()))
            {
                decimal iReqd = 0, iOrd = 0, iRec = 0;
                bool firstRecord = true;
                int recordCount = 0;
                foreach (var r in g)
                {
                    RecordCell(table, r, withItemHeader: firstRecord);
                    firstRecord = false;
                    recordCount++;
                    iReqd += r.QtyReqd ?? 0m;
                    iOrd  += r.QtyOrd  ?? 0m;
                    iRec  += r.QtyRec  ?? 0m;
                }

                if (recordCount >= 2)
                {
                    table.Cell().ColumnSpan(9).PaddingTop(1).LineHorizontal(0.75f).LineColor(Black);
                    TotalRow(table, "Item Total", iReqd, iOrd, iRec);
                    table.Cell().ColumnSpan(9).PaddingTop(1).LineHorizontal(0.75f).LineColor(Black);
                }
            }

            table.Cell().ColumnSpan(9).PaddingTop(1).LineHorizontal(0.75f).LineColor(Black);
            TotalRow(table, "Grand Total", totReqd, totOrd, totRec);
            table.Cell().ColumnSpan(9).PaddingTop(1).LineHorizontal(0.75f).LineColor(Black);
        });
    }

    private enum Align { Left, Center, Right }

    private static void HCell(TableCellDescriptor h, string text, Align align = Align.Left, float padL = 2, float padR = 2)
    {
        h.Cell().PaddingLeft(padL).PaddingRight(padR).PaddingVertical(1)
         .Text(t => { ApplyAlign(t, align); t.Span(text).FontFamily(Font).FontSize(8).Bold().FontColor(Purple); });
    }

    private static void RecordCell(TableDescriptor table, PendingPrItemWiseRowDto r, bool withItemHeader)
    {
        table.Cell().ColumnSpan(9).ShowEntire().PaddingBottom(3).Column(col =>
        {
            if (withItemHeader)
            {
                col.Item().PaddingTop(3).Row(row =>
                {
                    Seg(row, W1, (r.ItemCode ?? "").Trim(), GreenStyle);
                    Seg(row, W2 + W3 + W4 + W5 + W6 + W7 + W8 + W9, r.ItemName, GreenStyle);
                });
            }

            col.Item().PaddingTop(1).Row(row =>
            {
                Seg(row, W1, r.IndentNo, BodyStyle, Align.Left, padL: Indent);
                Seg(row, W2, r.IndentDt?.ToString("dd/MM/yy", CultureInfo.InvariantCulture) ?? "", BodyStyle);
                Seg(row, W3, r.RefNo ?? "", BodyStyle);
                Seg(row, W4 + W5 + W6 + W7 + W8 + W9, "", BodyStyle);
            });

            col.Item().PaddingTop(1).Row(row =>
            {
                Seg(row, W1, r.DepCode ?? "", BodyStyle, Align.Left, padL: Indent);
                Seg(row, W2, r.DepName ?? "", BodyStyle);
                Seg(row, W3, r.Unit ?? "", BodyStyle, Align.Right);
                Seg(row, W4, (r.QtyReqd ?? 0m).ToString(QtyFmt, CultureInfo.InvariantCulture), BodyStyle, Align.Right);
                Seg(row, W5, (r.QtyOrd  ?? 0m).ToString(QtyFmt, CultureInfo.InvariantCulture), BodyStyle, Align.Right);
                Seg(row, W6, (r.QtyRec  ?? 0m).ToString(QtyFmt, CultureInfo.InvariantCulture), BodyStyle, Align.Right, padR: 8);
                Seg(row, W7, r.ReqdDate?.ToString("dd/MM/yy", CultureInfo.InvariantCulture) ?? "", BodyStyle, Align.Left, padL: 6);
                Seg(row, W8, r.Remarks ?? "", BodyStyle);
                Seg(row, W9, r.PrStatus, BodyStyle);
            });
        });
    }

    private static void Seg(RowDescriptor row, float width, string text,
                            Action<TextSpanDescriptor> style, Align align = Align.Left,
                            float padL = 2, float padR = 2)
    {
        row.ConstantItem(width).PaddingLeft(padL).PaddingRight(padR)
           .Text(t => { ApplyAlign(t, align); var s = t.Span(text); style(s); });
    }

    private static void TotalRow(TableDescriptor table, string label, decimal req, decimal ord, decimal rec)
    {
        PCell(table, "", Align.Left);
        PCell(table, label, Align.Right);
        PCell(table, "", Align.Left);
        PCell(table, req.ToString(QtyFmt, CultureInfo.InvariantCulture), Align.Right);
        PCell(table, ord.ToString(QtyFmt, CultureInfo.InvariantCulture), Align.Right);
        PCell(table, rec.ToString(QtyFmt, CultureInfo.InvariantCulture), Align.Right, 8);
        PCell(table, "", Align.Left);
        PCell(table, "", Align.Left);
        PCell(table, "", Align.Left);
    }

    private static void PCell(TableDescriptor table, string text, Align align, float padR = 2)
    {
        table.Cell().PaddingLeft(2).PaddingRight(padR).PaddingVertical(2)
             .Text(t => { ApplyAlign(t, align); t.Span(text).FontFamily(Font).FontSize(8).Bold().FontColor(Purple); });
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
