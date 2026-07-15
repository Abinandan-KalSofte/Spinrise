using System.Globalization;
using System.Text;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using Spinrise.Application.Areas.PurchaseOrder.PoReport.DTOs;

namespace Spinrise.Reports.Areas.PurchaseOrder.Documents;

// Design is a clone of PoDateWiseDocument / PoSupplierWiseDocument (same report family) —
// only the data grouping/columns differ: ItemWise groups by ITEM (Item ID + Item Name as a
// green group header), summary grid = DateWise Row-1, detail grid = SupplierWise Row-2.
public sealed class PoItemWiseDocument : IDocument
{
    private const string Font   = "Tahoma";
    private const string Navy   = "#000080";
    private const string Maroon = "#800000";
    private const string Teal   = "#008080";
    private const string Black  = "#000000";
    private const string Purple = "#800080";
    private const string Green  = "#008000";

    // Summary (Row-1) grid — same 13 columns/widths as DateWise. Sum = 811.6.
    private const float R1OrderDate    = 43.4f;
    private const float R1OrderNo      = 34.6f;
    private const float R1SupplierName = 155.3f;
    private const float R1QuotationNo  = 36.7f;
    private const float R1CarrierName  = 129.1f;
    private const float R1OrderValue   = 57.1f;
    private const float R1AdvPct       = 34.9f;
    private const float R1AdvanceAmt   = 48.9f;   // original width (restored)
    private const float R1BalanceAmt   = 42.0f;
    private const float R1BalPayGap    = 6.0f;    // visible spacer column between Balance Amount & Payment mode
    private const float R1PaymentMode  = 36.0f;   // was 42.0; -6.0 funds the Balance/Payment spacer (Payment mode is left-aligned short text, so it shifts right and opens a visible gap)
    private const float R1DeliveryIns  = 84.0f;
    private const float R1SpecialIns   = 67.8f;
    private const float R1DueDate      = 35.8f;

    // Detail (Row-2) grid — same as SupplierWise (Item ID/Item Name are the group header, not
    // a detail column, so BlankTail spans that area). Sum = 811.6.
    private const float R2BlankLead  = 43.4f;
    private const float R2PrNo       = 34.6f;
    private const float R2BlankTail  = 276.0f;
    private const float R2Unit       = 26.0f;
    private const float R2Rate       = 56.8f;
    private const float R2OrderedQty = 58.6f;
    private const float R2ItemValue  = 93.5f;
    private const float R2GstAmount  = 75.9f;
    private const float R2CrdDays    = 146.8f;

    // Item-group header column (Item ID width; Item Name takes the rest).
    private const float GItemId = 60.0f;

    // Total row (Itemwise Total / Grand Total) — right-edges Order Value 444.2, Qty 513.3,
    // Item Value 606.9, GST 682.8; label starts at x=288. Sum = 811.6.
    private const float TotBlank1     = 270.0f;  // 18 -> 288
    private const float TotLabel      = 98.2f;
    private const float TotOrderValue = 58.0f;   // end 444.2
    private const float TotBlank2     = 39.1f;
    private const float TotQty        = 30.0f;   // end 513.3
    private const float TotItemValue  = 93.6f;   // end 606.9
    private const float TotGst        = 75.9f;   // end 682.8
    private const float TotTrail      = 146.8f;

    private readonly IReadOnlyList<PoItemWiseRowDto> _rows;
    private readonly PoReportRequest _request;
    private readonly string _printName;
    private readonly string _unitName;

    public PoItemWiseDocument(IReadOnlyList<PoItemWiseRowDto> rows, PoReportRequest request)
    {
        _rows = rows;
        _request = request;
        _printName = rows.Select(r => r.DivPrintName).FirstOrDefault(n => !string.IsNullOrWhiteSpace(n)) ?? "COMPANY NAME";
        _unitName  = rows.Select(r => r.DivUnitName).FirstOrDefault(n => !string.IsNullOrWhiteSpace(n)) ?? "";
    }

    public DocumentMetadata GetMetadata() => DocumentMetadata.Default;

    public void Compose(IDocumentContainer container)
    {
        container.Page(page =>
        {
            page.Size(PageSizes.A4.Landscape());
            page.MarginTop(7);
            page.MarginBottom(7);
            page.MarginLeft(18);
            page.MarginRight(11.4f);
            page.DefaultTextStyle(t => t.FontFamily(Font).FontSize(5.8f).FontColor(Black));

            page.Header().Element(ComposeTitle);
            page.Content().Element(ComposeContent);
            page.Footer().Dynamic(new PoListPageFooter());
        });
    }

    private void ComposeTitle(IContainer container)
    {
        var from = Dt(_request.FromDate);
        var to   = Dt(_request.ToDate);

        container.Column(col =>
        {
            col.Item().Text(t => { t.AlignCenter(); t.Span(_printName).FontFamily(Font).FontSize(9.1f).Bold().FontColor(Navy); });
            if (!string.IsNullOrWhiteSpace(_unitName))
                col.Item().Text(t => { t.AlignCenter(); t.Span(FormatUnit(_unitName)).FontFamily(Font).FontSize(6.6f).Bold().FontColor(Navy); });

            col.Item().PaddingTop(1.5f).Layers(layers =>
            {
                layers.PrimaryLayer().Row(r =>
                {
                    r.RelativeItem().Text(t =>
                    {
                        t.AlignLeft();
                        t.Span($"Purchase Order List from {from} To {to}").FontSize(8.3f).Bold().FontColor(Maroon);
                    });
                    r.RelativeItem().Text(t =>
                    {
                        t.AlignRight();
                        var now = DateTime.Now;
                        t.Span($"{Dt(now)}   {now:HH:mm:ss}   Page ").FontSize(6.6f).FontColor(Black);
                        t.CurrentPageNumber().FontSize(6.6f);
                        t.Span(" of ").FontSize(6.6f);
                        t.TotalPages().FontSize(6.6f);
                    });
                });
                layers.Layer().AlignMiddle().Text(t =>
                {
                    t.AlignCenter();
                    t.Span("Option : Item wise").FontSize(6.6f).Bold().FontColor(Teal);
                });
            });
            col.Item().PaddingTop(1).LineHorizontal(1f).LineColor(Black);
        });
    }

    private void ComposeContent(IContainer container)
    {
        container.Column(col =>
        {
            ComposeHeader(col);

            if (_rows.Count == 0)
            {
                col.Item().PaddingVertical(20).AlignCenter()
                    .Text("No purchase orders found for the selected criteria.").Bold().FontColor(Navy);
                return;
            }

            var ordered = _rows
                .OrderBy(r => r.ItemCode, StringComparer.OrdinalIgnoreCase)
                .ThenBy(r => r.PoDate)
                .ThenBy(r => ParsePoNo(r.PoNo))
                .ToList();

            decimal grandOrderValue = 0, grandQty = 0, grandItemValue = 0, grandGst = 0;

            // Group by ITEM; green group header per item, then its POs (summary R1 + detail R2),
            // closed by an "Itemwise Total" row.
            foreach (var itemGroup in ordered.GroupBy(r => new { r.ItemCode, r.ItemName }))
            {
                decimal itemOrderValue = 0, itemQty = 0, itemItemValue = 0, itemGst = 0;

                col.Item().PaddingTop(1).Row(r =>
                {
                    r.ConstantItem(GItemId).Text(itemGroup.Key.ItemCode).Bold().FontSize(5.8f).FontColor(Green);
                    r.RelativeItem().Text(itemGroup.Key.ItemName ?? "").Bold().FontSize(5.8f).FontColor(Green);
                });

                foreach (var poGroup in itemGroup.GroupBy(r => new { r.OrderType, r.PoNo }))
                {
                    var first = poGroup.First();
                    // True source (Reports_Vb6\new\PO-Itemwise.rpt + the legacy SP): "Order Value"
                    // binds to {ORDVAL} = the HEADER PO_ORDH.ORDVAL, so it is a per-PO figure and
                    // the Itemwise Total counts it ONCE per PO. "Item Value" binds to the separate
                    // {poitemvalue} = line PO_ORDL.ORDVAL, summed per line. (LANDCOST is NOT used
                    // by this report — the 11-Jul 12:31 script update replaced it with the header
                    // value, so all three PO List reports now follow the same rule.)
                    var poOrderValue = first.HeaderOrderValue;

                    col.Item().Column(rc =>
                    {
                        rc.Item().Row(r =>
                        {
                            r.ConstantItem(R1OrderDate).Text(Dt(first.PoDate)).FontColor(Black).AlignCenter();
                            r.ConstantItem(R1OrderNo).Text(FormatPoNo(first)).FontColor(Black).AlignCenter();
                            r.ConstantItem(R1SupplierName).Text(first.SupplierName ?? "").FontColor(Black);
                            r.ConstantItem(R1QuotationNo).Text(first.QuotationNo ?? "").FontColor(Black).AlignCenter();
                            r.ConstantItem(R1CarrierName).Text(first.CarrierName ?? "").FontColor(Black);
                            r.ConstantItem(R1OrderValue).Text(Ind(poOrderValue, 2)).FontColor(Black).AlignRight();
                            r.ConstantItem(R1AdvPct).Text(FormatPct(first.AdvancePercent)).FontColor(Black).AlignRight();
                            r.ConstantItem(R1AdvanceAmt).Text(first.AdvanceAmount != 0 ? Ind(first.AdvanceAmount, 2) : "").FontColor(Black).AlignRight();
                            r.ConstantItem(R1BalanceAmt).Text(first.BalanceAmount != 0 ? Ind(first.BalanceAmount, 2) : "").FontColor(Black).AlignRight();
                            r.ConstantItem(R1BalPayGap).Text("");
                            r.ConstantItem(R1PaymentMode).Text(first.PaymentMode ?? "").FontColor(Black);
                            r.ConstantItem(R1DeliveryIns).Text(first.DeliveryInstructions ?? "").FontColor(Black);
                            r.ConstantItem(R1SpecialIns).Text(first.SpecialInstructions ?? "").FontColor(Black);
                            r.ConstantItem(R1DueDate).Text(Dt(first.DueDate)).FontColor(Black).AlignCenter();
                        });

                        foreach (var row in poGroup)
                        {
                            rc.Item().Row(r =>
                            {
                                r.ConstantItem(R2BlankLead).Text("");
                                r.ConstantItem(R2PrNo).Text(row.PrNo ?? "").FontColor(Black).AlignCenter();
                                r.ConstantItem(R2BlankTail).Text("");
                                r.ConstantItem(R2Unit).Text(row.Uom ?? "").FontColor(Black).AlignCenter();
                                r.ConstantItem(R2Rate).Text(Ind(row.Rate, 2)).FontColor(Black).AlignRight();
                                r.ConstantItem(R2OrderedQty).Text(Ind(row.QtyOrdered, 3)).FontColor(Black).AlignRight();
                                r.ConstantItem(R2ItemValue).Text(Ind(row.LineValue, 2)).FontColor(Black).AlignRight();
                                r.ConstantItem(R2GstAmount).Text(row.TaxAmount != 0 ? Ind(row.TaxAmount, 2) : "").FontColor(Black).AlignRight();
                                r.ConstantItem(R2CrdDays).Text(Ind(row.CrdDays, 2)).FontColor(Black).AlignRight();
                            });
                        }
                    });

                    // Order Value is the PO HEADER value -> counted ONCE per PO. Item Value is the
                    // per-line value -> summed across the item's lines. The two columns bind to
                    // different fields, so they aggregate differently.
                    itemOrderValue += poOrderValue;
                    itemQty        += poGroup.Sum(r => r.QtyOrdered);
                    itemItemValue  += poGroup.Sum(r => r.LineValue);
                    itemGst        += poGroup.Sum(r => r.TaxAmount);
                }

                // Itemwise Total (maroon), line above + below.
                col.Item().PaddingTop(1).LineHorizontal(0.5f).LineColor(Black);
                TotalRow(col, "Itemwise Total", itemOrderValue, itemQty, itemItemValue, itemGst, Maroon);
                col.Item().LineHorizontal(0.5f).LineColor(Black);

                grandOrderValue += itemOrderValue;
                grandQty        += itemQty;
                grandItemValue  += itemItemValue;
                grandGst        += itemGst;
            }

            // Report-level Grand Total (purple).
            col.Item().PaddingTop(2).LineHorizontal(0.75f).LineColor(Black);
            TotalRow(col, "Grand Total", grandOrderValue, grandQty, grandItemValue, grandGst, Purple);
            col.Item().LineHorizontal(0.75f).LineColor(Black);

            // Abstract.
            col.Item().PaddingTop(4).Text(t => { t.AlignCenter(); t.Span("Abstract").FontSize(9.95f).Bold().FontColor(Maroon); });
            ComposeAbstract(col, ordered);
        });
    }

    private static void TotalRow(ColumnDescriptor col, string label, decimal orderValue, decimal qty, decimal itemValue, decimal gst, string color)
    {
        col.Item().PaddingVertical(1).Row(r =>
        {
            r.ConstantItem(TotBlank1).Text("");
            r.ConstantItem(TotLabel).Text(label).Bold().FontColor(color);
            r.ConstantItem(TotOrderValue).Text(Western(orderValue, 2)).Bold().FontColor(color).AlignRight();
            r.ConstantItem(TotBlank2).Text("");
            r.ConstantItem(TotQty).Text(Ind(qty, 3)).Bold().FontColor(color).AlignRight();
            r.ConstantItem(TotItemValue).Text(Ind(itemValue, 2)).Bold().FontColor(color).AlignRight();
            r.ConstantItem(TotGst).Text(Ind(gst, 2)).Bold().FontColor(color).AlignRight();
            r.ConstantItem(TotTrail).Text("");
        });
    }

    // Header label rows aligned with Layers() (SupplierWise technique): summary grid on the
    // primary layer (Order Date/Order No./Supplier Name pushed down below the Item ID/Item Name
    // group labels), the group labels overlaid at top, the detail grid overlaid + pushed down.
    private static void ComposeHeader(ColumnDescriptor col)
    {
        col.Item().Layers(layers =>
        {
            layers.PrimaryLayer().Row(r =>
            {
                r.ConstantItem(R1OrderDate).Text("\n\nOrder\nDate\n").FontSize(5.8f).Bold().FontColor(Purple).AlignCenter();
                r.ConstantItem(R1OrderNo).Text("\n\nOrder No.").FontSize(5.8f).Bold().FontColor(Purple).AlignCenter();
                r.ConstantItem(R1SupplierName).Text("\n\nSupplier Name").FontSize(5.8f).Bold().FontColor(Purple);
                r.ConstantItem(R1QuotationNo).Text("Quotation\nNo.").FontSize(5.8f).Bold().FontColor(Purple).AlignCenter();
                r.ConstantItem(R1CarrierName).Text("Carrier Name").FontSize(5.8f).Bold().FontColor(Purple);
                r.ConstantItem(R1OrderValue).Text("Order\nValue").FontSize(5.8f).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(R1AdvPct).Text("Adv. %").FontSize(5.8f).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(R1AdvanceAmt).Text("Advance Amount").FontSize(5.8f).Bold().FontColor(Purple).AlignRight();                
                r.ConstantItem(R1BalanceAmt).Text("Balance Amount").FontSize(5.8f).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(R1BalPayGap).Text("");
                r.ConstantItem(R1PaymentMode).Text("Payment mode").FontSize(5.8f).Bold().FontColor(Purple);
                r.ConstantItem(R1DeliveryIns).Text("Delivery Instruction").FontSize(5.8f).Bold().FontColor(Purple);
                r.ConstantItem(R1SpecialIns).Text("Special\nInstruction").FontSize(5.8f).Bold().FontColor(Purple);
                r.ConstantItem(R1DueDate).Text("Due\nDate").FontSize(5.8f).Bold().FontColor(Purple).AlignCenter();
            });
            layers.Layer().Row(r =>
            {
                r.ConstantItem(GItemId).Text("Item ID").FontSize(5.8f).Bold().FontColor(Purple);
                r.RelativeItem().Text("Item Name").FontSize(5.8f).Bold().FontColor(Purple);
            });
            layers.Layer().PaddingTop(21f).Row(r =>
            {
                r.ConstantItem(R2BlankLead).Text("");
                r.ConstantItem(R2PrNo).Text("PR. No.").FontSize(5.8f).Bold().FontColor(Purple).AlignCenter();
                r.ConstantItem(R2BlankTail).Text("");
                r.ConstantItem(R2Unit).Text("Unit").FontSize(5.8f).Bold().FontColor(Purple).AlignCenter();
                r.ConstantItem(R2Rate).Text("Rate/\nUnit").FontSize(5.8f).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(R2OrderedQty).Text("Ordered\nQuantity").FontSize(5.8f).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(R2ItemValue).Text("Item\nValue").FontSize(5.8f).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(R2GstAmount).Text("GST\nAmount").FontSize(5.8f).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(R2CrdDays).Text("Crd-Days").FontSize(5.8f).Bold().FontColor(Purple).AlignRight();
            });
        });
        col.Item().LineHorizontal(1f).LineColor(Black);
    }

    private static void ComposeAbstract(ColumnDescriptor col, List<PoItemWiseRowDto> ordered)
    {
        const float A1 = 40.5f;  // S.No.
        const float A2 = 64.0f;  // Item ID
        const float A3 = 268.0f; // Item Name
        const float A4 = 50.6f;  // Order Value (Western)
        const float A5 = 79.4f;  // Ordered Quantity
        const float A6 = 78.0f;  // Item Value (Indian)
        const float A7 = 78.0f;  // GST Amount (Indian)

        var abstractData = ordered
            .GroupBy(r => new { r.ItemCode, r.ItemName })
            .Select((g, i) => new
            {
                SlNo       = i + 1,
                g.Key.ItemCode,
                g.Key.ItemName,
                // Mirrors the Itemwise Total rows above: Order Value = header value ONCE per PO
                // (group by OrderType+PoNo so AD/1254 and CR/1254 don't merge); Item Value = the
                // per-line value summed across the item's lines.
                OrderValue = g.GroupBy(r => new { r.OrderType, r.PoNo }).Sum(pg => pg.First().HeaderOrderValue),
                Qty        = g.Sum(r => r.QtyOrdered),
                ItemValue  = g.Sum(r => r.LineValue),
                GstAmount  = g.Sum(r => r.TaxAmount),
            })
            .ToList();

        const float AbstractWidth = A1 + A2 + A3 + A4 + A5 + A6 + A7 + 4f;
        const float AbstractInset = 49.5f;  // matches reference box left edge (page x=67.5)
        col.Item().Row(outer =>
        {
            outer.ConstantItem(AbstractInset);
            outer.ConstantItem(AbstractWidth).Border(1f).BorderColor(Black).Column(box =>
            {
                box.Item().PaddingHorizontal(2).PaddingTop(2).Row(r =>
                {
                    r.ConstantItem(A1).Text("S.No.").FontSize(6.6f).Bold().FontColor(Purple).AlignCenter();
                    r.ConstantItem(A2).Text("Item ID").FontSize(6.6f).Bold().FontColor(Purple);
                    r.ConstantItem(A3).Text("Item Name").FontSize(6.6f).Bold().FontColor(Purple);
                    r.ConstantItem(A4).Text("Order Value").FontSize(6.6f).Bold().FontColor(Purple).AlignRight();
                    r.ConstantItem(A5).Text("Ordered Quantity").FontSize(6.6f).Bold().FontColor(Purple).AlignRight();
                    r.ConstantItem(A6).Text("Item Value").FontSize(6.6f).Bold().FontColor(Purple).AlignRight();
                    r.ConstantItem(A7).Text("GST Amount").FontSize(6.6f).Bold().FontColor(Purple).AlignRight();
                });
                box.Item().PaddingHorizontal(2).LineHorizontal(1f).LineColor(Black);

                foreach (var item in abstractData)
                {
                    box.Item().PaddingHorizontal(2).Row(r =>
                    {
                        r.ConstantItem(A1).Text(item.SlNo.ToString()).FontColor(Black).AlignCenter();
                        r.ConstantItem(A2).Text(item.ItemCode).FontColor(Black);
                        r.ConstantItem(A3).Text(item.ItemName ?? "").FontColor(Black);
                        r.ConstantItem(A4).Text(item.OrderValue != 0 ? Western(item.OrderValue, 2) : "").FontColor(Black).AlignRight();
                        r.ConstantItem(A5).Text(Ind(item.Qty, 3)).FontColor(Black).AlignRight();
                        r.ConstantItem(A6).Text(Ind(item.ItemValue, 2)).FontColor(Black).AlignRight();
                        r.ConstantItem(A7).Text(Ind(item.GstAmount, 2)).FontColor(Black).AlignRight();
                    });
                }

                var totQty      = abstractData.Sum(a => a.Qty);
                var totOrderVal = abstractData.Sum(a => a.OrderValue);
                var totItemVal  = abstractData.Sum(a => a.ItemValue);
                var totGst      = abstractData.Sum(a => a.GstAmount);

                box.Item().PaddingHorizontal(2).LineHorizontal(1f).LineColor(Black);
                box.Item().PaddingHorizontal(2).Row(r =>
                {
                    r.ConstantItem(A1 + A2 + A3 + A4).Text("");
                    r.ConstantItem(A5).Text(Ind(totQty, 3)).Bold().FontColor(Purple).AlignRight();
                    r.ConstantItem(A6).Text("");
                    r.ConstantItem(A7).Text(Ind(totGst, 2)).Bold().FontColor(Purple).AlignRight();
                });
                // "Grand Total" label on its own row, then Order Value + Item Value on the next.
                box.Item().PaddingHorizontal(2).Row(r =>
                {
                    r.ConstantItem(A1 + A2 + A3).Text("Grand Total").Bold().FontColor(Purple).AlignCenter();
                    r.ConstantItem(A4 + A5 + A6 + A7).Text("");
                });
                box.Item().PaddingHorizontal(2).PaddingBottom(2).Row(r =>
                {
                    r.ConstantItem(A1 + A2 + A3).Text("");
                    r.ConstantItem(A4).Text(totOrderVal != 0 ? Western(totOrderVal, 2) : "").Bold().FontColor(Purple).AlignRight();
                    r.ConstantItem(A5).Text("");
                    r.ConstantItem(A6).Text(Ind(totItemVal, 2)).Bold().FontColor(Purple).AlignRight();
                    r.ConstantItem(A7).Text("");
                });
            });
        });
    }

    private static string Dt(DateTime? value) =>
        value?.ToString("dd/MM/yy", CultureInfo.InvariantCulture) ?? "";

    private static string FormatUnit(string unit)
    {
        var u = unit.Trim();
        return u.StartsWith("(Unit", StringComparison.OrdinalIgnoreCase) ? u : $"(Unit - {u})";
    }

    // Crystal formula: IsNull(POGRP) ? PORDNO : POGRP + "/" + PORDNO.
    // OrderType = POGRP, PoNo = PORDNO (both returned separately by the SP).
    private static string FormatPoNo(PoItemWiseRowDto row) =>
        string.IsNullOrWhiteSpace(row.OrderType) ? row.PoNo : $"{row.OrderType}/{row.PoNo}";

    private static string Ind(decimal value, int decimals)
    {
        bool neg = value < 0;
        string fixedStr = Math.Abs(value).ToString("F" + decimals, CultureInfo.InvariantCulture);
        string intPart = fixedStr, frac = "";
        int dot = fixedStr.IndexOf('.');
        if (dot >= 0) { intPart = fixedStr.Substring(0, dot); frac = fixedStr.Substring(dot); }
        if (intPart.Length <= 3) return (neg ? "-" : "") + intPart + frac;
        string last3 = intPart.Substring(intPart.Length - 3);
        string rest = intPart.Substring(0, intPart.Length - 3);
        var sb = new StringBuilder();
        while (rest.Length > 2) { sb.Insert(0, "," + rest.Substring(rest.Length - 2)); rest = rest.Substring(0, rest.Length - 2); }
        sb.Insert(0, rest);
        return (neg ? "-" : "") + sb + "," + last3 + frac;
    }

    private static string Western(decimal value, int decimals) =>
        value.ToString("N" + decimals, CultureInfo.InvariantCulture);

    private static string FormatPct(decimal value) =>
        value == 0 ? "" : $"{Ind(value, 2)}%";

    private static int ParsePoNo(string? poNo)
    {
        var numeric = poNo?.Contains('/') == true ? poNo[(poNo.LastIndexOf('/') + 1)..] : poNo;
        return int.TryParse(numeric, NumberStyles.Integer, CultureInfo.InvariantCulture, out var n) ? n : int.MaxValue;
    }
}
