using System.Globalization;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using Spinrise.Application.Areas.PurchaseOrder.PoReport.DTOs;

namespace Spinrise.Reports.Areas.PurchaseOrder.Documents;

public sealed class PoDeptWiseDocument : IDocument
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
    private const string ValFmt = "#,##0.00";

    private readonly IReadOnlyList<PoDeptWiseRowDto> _rows;
    private readonly PoReportRequest _request;
    private readonly string _printName;
    private readonly string _unitName;

    public PoDeptWiseDocument(IReadOnlyList<PoDeptWiseRowDto> rows, PoReportRequest request)
    {
        _rows = rows;
        _request = request;
        _printName = rows.Select(r => r.DivPrintName).FirstOrDefault(n => !string.IsNullOrWhiteSpace(n)) ?? "COMPANY NAME";
        _unitName  = rows.Select(r => r.DivUnitName).FirstOrDefault(n => !string.IsNullOrWhiteSpace(n)) ?? "";
    }

    public DocumentMetadata GetMetadata() => new()
    {
        Title  = "Purchase Order Report - Department Wise",
        Author = "SpinRise",
    };

    public void Compose(IDocumentContainer container)
    {
        container.Page(page =>
        {
            page.Size(PageSizes.A4.Landscape());
            page.MarginTop(7);
            page.MarginBottom(7);
            page.MarginLeft(8);
            page.MarginRight(8);
            page.DefaultTextStyle(t => t.FontFamily(Font).FontSize(6.5f).FontColor(Black));

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

            col.Item().PaddingTop(1.5f).Layers(layers =>
            {
                layers.PrimaryLayer().Row(r =>
                {
                    r.RelativeItem().Text(t =>
                    {
                        t.AlignLeft();
                        t.Span($"Purchase Order List from {_request.FromDate:dd/MM/yy} to {_request.ToDate:dd/MM/yy}")
                         .FontSize(8).Bold().FontColor(Maroon);
                    });
                    r.RelativeItem().Text(t =>
                    {
                        t.AlignRight();
                        var now = DateTime.Now;
                        t.Span($"{now:dd/MM/yy}  {now:HH:mm:ss}  Page ").FontSize(6.5f).FontColor(Black);
                        t.CurrentPageNumber().FontSize(6.5f);
                        t.Span(" of ").FontSize(6.5f);
                        t.TotalPages().FontSize(6.5f);
                    });
                });
                layers.Layer().AlignMiddle().Text(t =>
                {
                    t.AlignCenter();
                    t.Span("Option : Department wise").FontSize(7).Bold().FontColor(Teal);
                });
            });
            col.Item().PaddingTop(1).LineHorizontal(0.5f).LineColor(Black);
        });
    }

    private void ComposeContent(IContainer container)
    {
        if (_rows.Count == 0)
        {
            container.PaddingVertical(20).AlignCenter()
                .Text("No purchase orders found for the selected criteria.")
                .Bold().FontColor(Navy);
            return;
        }

        var ordered = _rows
            .OrderBy(r => r.DepName, StringComparer.OrdinalIgnoreCase)
            .ThenBy(r => r.PoDate)
            .ThenBy(r => ParsePoNo(r.PoNo))
            .ThenBy(r => r.ItemCode, StringComparer.OrdinalIgnoreCase)
            .ToList();

        container.Column(col =>
        {
            // Header Row
            col.Item().Row(r =>
            {
                r.ConstantItem(44).Text("Order\nDate").FontSize(6).Bold().FontColor(Purple).AlignCenter();
                r.ConstantItem(38).Text("Order\nNo.").FontSize(6).Bold().FontColor(Purple).AlignCenter();
                r.ConstantItem(44).Text("Item ID").FontSize(6).Bold().FontColor(Purple).AlignCenter();
                r.ConstantItem(64).Text("Item Name").FontSize(6).Bold().FontColor(Purple);
                r.ConstantItem(44).Text("Quotation\nNo.").FontSize(6).Bold().FontColor(Purple).AlignCenter();
                r.ConstantItem(51).Text("Carrier Name").FontSize(6).Bold().FontColor(Purple);
                r.ConstantItem(23).Text("Unit").FontSize(6).Bold().FontColor(Purple).AlignCenter();
                r.ConstantItem(36).Text("Rate /\nUnit").FontSize(6).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(38).Text("Ordered\nQty").FontSize(6).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(41).Text("Order\nValue").FontSize(6).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(25).Text("Adv.\n%").FontSize(6).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(45).Text("Advance\nAmount").FontSize(6).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(45).Text("Payment\nmode").FontSize(6).Bold().FontColor(Purple);
                r.ConstantItem(44).Text("Delivery\nInstruction").FontSize(6).Bold().FontColor(Purple);
                r.ConstantItem(44).Text("Special\nInstruction").FontSize(6).Bold().FontColor(Purple);
                r.ConstantItem(28).Text("Due\nDate").FontSize(6).Bold().FontColor(Purple).AlignCenter();
                r.ConstantItem(36).Text("GST\nAmount").FontSize(6).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(36).Text("Item\nValue").FontSize(6).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(25).Text("Crd-\nDays").FontSize(6).Bold().FontColor(Purple).AlignRight();
            });
            col.Item().LineHorizontal(0.5f).LineColor(Black);

            foreach (var deptGroup in ordered.GroupBy(r => new { r.DepCode, r.DepName }))
            {
                col.Item().Element(c => ComposeDeptGroup(c, deptGroup.ToList()));
            }

            // Grand Total Row
            var reportTotalValue = _rows.Sum(r => r.LineValue);
            var reportTotalQty = _rows.Sum(r => r.QtyOrdered);
            var reportTotalAdv = _rows.Sum(r => r.AdvanceAmount);
            var reportTotalTax = _rows.Sum(r => r.TaxAmount);

            col.Item().Row(r =>
            {
                r.ConstantItem(44).Text("");
                r.ConstantItem(38).Text("");
                r.ConstantItem(44).Text("");
                r.ConstantItem(64).Text("");
                r.ConstantItem(44).Text("");
                r.ConstantItem(51).Text("");
                r.ConstantItem(23).Text("");
                r.ConstantItem(36).Text("");
                r.ConstantItem(38).Text(reportTotalQty.ToString(QtyFmt, CultureInfo.InvariantCulture)).FontSize(6.5f).Bold().FontColor(Black).AlignRight();
                r.ConstantItem(41).Text(reportTotalValue.ToString(ValFmt, CultureInfo.InvariantCulture)).FontSize(6.5f).Bold().FontColor(Black).AlignRight();
                r.ConstantItem(25).Text("");
                r.ConstantItem(45).Text(reportTotalAdv.ToString(ValFmt, CultureInfo.InvariantCulture)).FontSize(6.5f).Bold().FontColor(Black).AlignRight();
                r.ConstantItem(45).Text("Grand Total").FontSize(6.5f).Bold().FontColor(Black);
                r.ConstantItem(44).Text("");
                r.ConstantItem(44).Text("");
                r.ConstantItem(28).Text("");
                r.ConstantItem(36).Text(reportTotalTax.ToString(ValFmt, CultureInfo.InvariantCulture)).FontSize(6.5f).Bold().FontColor(Black).AlignRight();
                r.ConstantItem(36).Text(reportTotalValue.ToString(ValFmt, CultureInfo.InvariantCulture)).FontSize(6.5f).Bold().FontColor(Black).AlignRight();
                r.ConstantItem(25).Text("");
            });
            col.Item().LineHorizontal(0.5f).LineColor(Black);

            // Abstract Section
            col.Item().PaddingTop(4).Text("Abstract").FontSize(7).Bold().FontColor(Maroon);
            ComposeAbstract(col, ordered);
        });
    }

    private void ComposeDeptGroup(IContainer container, List<PoDeptWiseRowDto> deptRows)
    {
        container.Column(col =>
        {
            // Department Header
            col.Item().PaddingTop(1).Row(r =>
            {
                r.ConstantItem(35).Text(deptRows[0].DepName).FontSize(6.5f).Bold().FontColor(Navy);
                r.RelativeItem().Text("").FontSize(6.5f);
            });

            decimal deptTotalValue = 0;
            decimal deptTotalQty = 0;
            decimal deptTotalAdv = 0;
            decimal deptTotalTax = 0;

            // Detail Rows
            foreach (var row in deptRows)
            {
                col.Item().Row(r =>
                {
                    r.ConstantItem(44).Text(row.PoDate?.ToString("dd/MM/yy") ?? "").FontSize(6.5f).FontColor(Black).AlignCenter();
                    r.ConstantItem(38).Text(row.PoNo).FontSize(6.5f).FontColor(Black).AlignCenter();
                    r.ConstantItem(44).Text(row.ItemCode).FontSize(6.5f).Bold().FontColor(Green).AlignCenter();
                    r.ConstantItem(64).Text(row.ItemName ?? "").FontSize(6.5f).FontColor(Black);
                    r.ConstantItem(44).Text(row.QuotationNo ?? "").FontSize(6.5f).FontColor(Black).AlignCenter();
                    r.ConstantItem(51).Text(row.CarrierName ?? "").FontSize(6.5f).FontColor(Black);
                    r.ConstantItem(23).Text(row.Uom ?? "").FontSize(6.5f).FontColor(Black).AlignCenter();
                    r.ConstantItem(36).Text(row.Rate.ToString(ValFmt, CultureInfo.InvariantCulture)).FontSize(6.5f).FontColor(Black).AlignRight();
                    r.ConstantItem(38).Text(row.QtyOrdered.ToString(QtyFmt, CultureInfo.InvariantCulture)).FontSize(6.5f).FontColor(Black).AlignRight();
                    r.ConstantItem(41).Text(row.LineValue.ToString(ValFmt, CultureInfo.InvariantCulture)).FontSize(6.5f).FontColor(Black).AlignRight();
                    var advPct = row.AdvancePercent > 0 ? row.AdvancePercent.ToString(ValFmt, CultureInfo.InvariantCulture) : "0.00";
                    r.ConstantItem(25).Text(advPct).FontSize(6.5f).FontColor(Black).AlignRight();
                    r.ConstantItem(45).Text(row.AdvanceAmount.ToString(ValFmt, CultureInfo.InvariantCulture)).FontSize(6.5f).FontColor(Black).AlignRight();
                    r.ConstantItem(45).Text(row.PaymentMode ?? "").FontSize(6.5f).FontColor(Black);
                    r.ConstantItem(44).Text(row.DeliveryInstructions ?? "").FontSize(6).FontColor(Black);
                    r.ConstantItem(44).Text(row.SpecialInstructions ?? "").FontSize(6).FontColor(Black);
                    r.ConstantItem(28).Text(row.DueDate?.ToString("dd/MM/yy") ?? "").FontSize(6.5f).FontColor(Black).AlignCenter();
                    r.ConstantItem(36).Text(row.TaxAmount.ToString(ValFmt, CultureInfo.InvariantCulture)).FontSize(6.5f).FontColor(Black).AlignRight();
                    r.ConstantItem(36).Text(row.LineValue.ToString(ValFmt, CultureInfo.InvariantCulture)).FontSize(6.5f).FontColor(Black).AlignRight();
                    r.ConstantItem(25).Text(row.CrdDays.ToString()).FontSize(6.5f).FontColor(Black).AlignRight();
                });

                deptTotalValue += row.LineValue;
                deptTotalQty += row.QtyOrdered;
                deptTotalAdv += row.AdvanceAmount;
                deptTotalTax += row.TaxAmount;
            }

            // Department Total Row
            col.Item().Row(r =>
            {
                r.ConstantItem(44).Text("");
                r.ConstantItem(38).Text("");
                r.ConstantItem(44).Text("");
                r.ConstantItem(64).Text("");
                r.ConstantItem(44).Text("");
                r.ConstantItem(51).Text("");
                r.ConstantItem(23).Text("");
                r.ConstantItem(36).Text("");
                r.ConstantItem(38).Text(deptTotalQty.ToString(QtyFmt, CultureInfo.InvariantCulture)).FontSize(6.5f).Bold().FontColor(Maroon).AlignRight();
                r.ConstantItem(41).Text(deptTotalValue.ToString(ValFmt, CultureInfo.InvariantCulture)).FontSize(6.5f).Bold().FontColor(Maroon).AlignRight();
                r.ConstantItem(25).Text("");
                r.ConstantItem(45).Text(deptTotalAdv.ToString(ValFmt, CultureInfo.InvariantCulture)).FontSize(6.5f).Bold().FontColor(Maroon).AlignRight();
                r.ConstantItem(45).Text("Departmentwise Total").FontSize(6.5f).Bold().FontColor(Maroon);
                r.ConstantItem(44).Text("");
                r.ConstantItem(44).Text("");
                r.ConstantItem(28).Text("");
                r.ConstantItem(36).Text(deptTotalTax.ToString(ValFmt, CultureInfo.InvariantCulture)).FontSize(6.5f).Bold().FontColor(Maroon).AlignRight();
                r.ConstantItem(36).Text(deptTotalValue.ToString(ValFmt, CultureInfo.InvariantCulture)).FontSize(6.5f).Bold().FontColor(Maroon).AlignRight();
                r.ConstantItem(25).Text("");
            });
            col.Item().LineHorizontal(0.5f).LineColor(Black);
        });
    }

    private void ComposeAbstract(ColumnDescriptor col, List<PoDeptWiseRowDto> ordered)
    {
        var abstractData = ordered
            .GroupBy(r => new { r.DepCode, r.DepName })
            .Select(g => new
            {
                g.Key.DepName,
                OrderValue = g.Sum(r => r.LineValue),
                OrderedQty = g.Sum(r => r.QtyOrdered),
                ItemValue = g.Sum(r => r.LineValue),
                GSTAmount = g.Sum(r => r.TaxAmount)
            })
            .ToList();

        col.Item().PaddingTop(2).Row(r =>
        {
            r.ConstantItem(25).Text("S.No.").FontSize(6.5f).Bold().FontColor(Purple).AlignCenter();
            r.ConstantItem(100).Text("Department Name").FontSize(6.5f).Bold().FontColor(Purple);
            r.ConstantItem(60).Text("Order Value").FontSize(6.5f).Bold().FontColor(Purple).AlignRight();
            r.ConstantItem(60).Text("Ordered Qty").FontSize(6.5f).Bold().FontColor(Purple).AlignRight();
            r.ConstantItem(60).Text("Item Value").FontSize(6.5f).Bold().FontColor(Purple).AlignRight();
            r.ConstantItem(60).Text("GST Amount").FontSize(6.5f).Bold().FontColor(Purple).AlignRight();
        });

        int sno = 1;
        foreach (var item in abstractData)
        {
            col.Item().Row(r =>
            {
                r.ConstantItem(25).Text(sno.ToString()).FontSize(6.5f).FontColor(Black).AlignCenter();
                r.ConstantItem(100).Text(item.DepName).FontSize(6.5f).FontColor(Black);
                r.ConstantItem(60).Text(item.OrderValue.ToString(ValFmt, CultureInfo.InvariantCulture)).FontSize(6.5f).FontColor(Black).AlignRight();
                r.ConstantItem(60).Text(item.OrderedQty.ToString(QtyFmt, CultureInfo.InvariantCulture)).FontSize(6.5f).FontColor(Black).AlignRight();
                r.ConstantItem(60).Text(item.ItemValue.ToString(ValFmt, CultureInfo.InvariantCulture)).FontSize(6.5f).FontColor(Black).AlignRight();
                r.ConstantItem(60).Text(item.GSTAmount.ToString(ValFmt, CultureInfo.InvariantCulture)).FontSize(6.5f).FontColor(Black).AlignRight();
            });
            sno++;
        }

        // Grand total in abstract
        var gtValue = ordered.Sum(r => r.LineValue);
        var gtQty = ordered.Sum(r => r.QtyOrdered);
        var gtTax = ordered.Sum(r => r.TaxAmount);

        col.Item().Row(r =>
        {
            r.ConstantItem(25).Text("");
            r.ConstantItem(100).Text("Grand Total").FontSize(6.5f).Bold().FontColor(Black);
            r.ConstantItem(60).Text(gtValue.ToString(ValFmt, CultureInfo.InvariantCulture)).FontSize(6.5f).Bold().FontColor(Black).AlignRight();
            r.ConstantItem(60).Text(gtQty.ToString(QtyFmt, CultureInfo.InvariantCulture)).FontSize(6.5f).Bold().FontColor(Black).AlignRight();
            r.ConstantItem(60).Text(gtValue.ToString(ValFmt, CultureInfo.InvariantCulture)).FontSize(6.5f).Bold().FontColor(Black).AlignRight();
            r.ConstantItem(60).Text(gtTax.ToString(ValFmt, CultureInfo.InvariantCulture)).FontSize(6.5f).Bold().FontColor(Black).AlignRight();
        });
    }

    private static int ParsePoNo(string? poNo) =>
        int.TryParse(poNo, NumberStyles.Integer, CultureInfo.InvariantCulture, out var n) ? n : int.MaxValue;

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
