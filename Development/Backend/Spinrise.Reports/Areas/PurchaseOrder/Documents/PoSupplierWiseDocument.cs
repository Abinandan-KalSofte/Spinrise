using System.Globalization;
using System.Text;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using Spinrise.Application.Areas.PurchaseOrder.PoReport.DTOs;

namespace Spinrise.Reports.Areas.PurchaseOrder.Documents;

// Layout matches Reports_Vb6\supplier_wise.pdf (Crystal Report SupplierWise.rpt), pixel-derived via
// Tools\pdf_layout\extract_layout.py + profile_columns.py (see Tools\pdf_layout\output\supplier_wise\).
//  - Detail rows grouped by supplier; two independent column grids (physical line 1 / line 2 of each
//    record use DIFFERENT, non-aligned column boundaries in the reference - not a shared grid).
//  - Per-supplier "Supplierwise Total" subtotal row after each group; report-level Grand Total at the end.
//  - Order-Value totals (subtotal + grand total only) render with Western digit grouping; every other
//    figure (incl. per-line Order Value) uses Indian grouping - a genuine formatting inconsistency in the
//    legacy report, replicated bug-for-bug per explicit decision (pixel parity over house style here).
//  - Abstract subreport: S.No. | Supplier Name | Order Value (Western) | Ordered Quantity | Item Value | GST Amount, boxed.
public sealed class PoSupplierWiseDocument : IDocument
{
    private const string Navy   = "#000080";
    private const string Maroon = "#800000";
    private const string Teal   = "#008080";
    private const string Purple = "#800080";
    private const string Green  = "#008000";
    private const string Black  = "#000000";
    private const string Grey   = "#808080";
    private const string Font   = "Tahoma";

    // Line-1 grid (13 cols, x0=18.0..829.6, sums to content width 811.6).
    // Widths re-derived 06-Jul against REAL JAT data + profile_columns.py, anchored to confirmed
    // right-edges of right-aligned numeric spans (not just header-label x0 deltas, which understate
    // real width needs - see Tools\pdf_layout\output\profile_ref_p1_wide.md).
    private const float R1OrderDate   = 43.4f;  // x0=18.0
    private const float R1PrNo        = 34.6f;  // x0=61.4  (holds Order No. on line 1; PR No. now rendered on line 2 at same x0)
    private const float R1ItemId      = 48.0f;  // x0=96.0
    private const float R1ItemName    = 107.3f; // x0=144.0
    private const float R1QuotationNo = 35.9f;  // x0=251.3
    private const float R1CarrierName = 129.9f; // x0=287.2, end=417.1
    private const float R1OrderValue  = 57.1f;  // x0=417.1, end=474.2 (confirmed real right-edge)
    private const float R1AdvPct      = 34.9f;  // x0=474.2, end=509.1 (confirmed real right-edge, 06-Jul single-supplier finding)
    private const float R1AdvanceAmt  = 48.9f;  // x0=509.1, end=558.0 (confirmed: must not overlap Payment mode)
    private const float R1AdvPayGap   = 6.0f;   // visible spacer column between Advance Amount & Payment mode
    private const float R1PaymentMode = 78.0f;  // was 84.0; -6.0 funds the Advance/Payment spacer (Payment mode is left-aligned, shifts right to open the gap)
    private const float R1DeliveryIns = 84.0f;  // x0=642.0, end=726.0
    private const float R1SpecialIns  = 67.8f;  // x0=726.0, end=793.8
    private const float R1DueDate     = 35.8f;  // x0=793.8, end=829.6

    // Line-2 grid (7 cols, x0=18.0..829.6, independent from line-1's grid per the reference - sums to 811.6).
    // Right edges confirmed directly from real numeric data spans (Rate/Qty/ItemValue/GstAmount/CrdDays),
    // not header positions - header labels sit narrower than the real column needs.
    private const float R2BlankLead  = 43.4f;  // width of R1OrderDate, so PR No. lines up under Order No. (was wrongly 61.4 - an absolute x-coordinate, not the width needed here)
    private const float R2PrNo       = 34.6f;  // x0=61.4, end=96.0 (under Order No. on line 1 - PR No. value)
    private const float R2BlankTail  = 276.0f; // x0=96.0, end=372.0 (adjusted so BlankLead+PrNo+BlankTail still totals 354.0 - Unit's start must stay at x=372.0)
    private const float R2Unit       = 26.0f;  // x0=372.0, end=398.0
    private const float R2Rate       = 56.8f;  // x0=398.0, end=454.8 (confirmed real right-edge)
    private const float R2OrderedQty = 58.6f;  // x0=454.8, end=513.4 (confirmed real right-edge)
    private const float R2ItemValue  = 93.5f;  // x0=513.4, end=606.9 (confirmed real right-edge)
    private const float R2GstAmount  = 75.9f;  // x0=606.9, end=682.8 (confirmed real right-edge)
    private const float R2CrdDays    = 146.8f; // x0=682.8, end=829.6 (confirmed real right-edge ~817.5 within box)

    // Supplierwise-Total / Grand-Total row - right edges reused from the per-line R1/R2 grids above
    // (confirmed identical in the reference: Order Value totals end at 474.2, Qty at 513.4, Item
    // Value at 606.9, GST Amount at 682.8).
    private const float TotBlank1     = 252.0f; // x0=18.0
    private const float TotLabel      = 134.5f; // x0=270.0, end=404.5
    private const float TotOrderValue = 69.7f;  // x0=404.5, end=474.2
    private const float TotBlank2     = 16.0f;  // x0=474.2, end=490.2
    private const float TotQty        = 23.2f;  // x0=490.2, end=513.4
    private const float TotBlank3     = 0f;     // chained directly, no gap
    private const float TotItemValue  = 93.5f;  // x0=513.4, end=606.9
    private const float TotBlank4     = 0f;     // spacer removed - GST placed directly after Item Value
    private const float TotGstAmount  = 75.9f;  // x0=606.9, end=682.8

    private readonly IReadOnlyList<PoSupplierWiseRowDto> _rows;
    private readonly PoReportRequest _request;
    private readonly string _printName;
    private readonly string _unitName;

    public PoSupplierWiseDocument(IReadOnlyList<PoSupplierWiseRowDto> rows, PoReportRequest request)
    {
        _rows = rows;
        _request = request;
        _printName = rows.Select(r => r.DivPrintName).FirstOrDefault(n => !string.IsNullOrWhiteSpace(n)) ?? "COMPANY NAME";
        _unitName  = rows.Select(r => r.DivUnitName).FirstOrDefault(n => !string.IsNullOrWhiteSpace(n)) ?? "";
    }

    public DocumentMetadata GetMetadata() => new()
    {
        Title  = "Purchase Order Report - Supplier Wise",
        Author = "SpinRise",
    };

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
                        t.Span($"Purchase Order List from {Dt(_request.FromDate)} to {Dt(_request.ToDate)}")
                         .FontSize(8.3f).Bold().FontColor(Maroon);
                    });
                    r.RelativeItem().Text(t =>
                    {
                        t.AlignRight();
                        var now = DateTime.Now;
                        // Reference uses a 24-hour clock ("17:17:14"), not 12-hour AM/PM.
                        t.Span($"{Dt(now)}   {now:HH:mm:ss}   Page ").FontSize(6.6f).FontColor(Black);
                        t.CurrentPageNumber().FontSize(6.6f);
                        t.Span(" of ").FontSize(6.6f);
                        t.TotalPages().FontSize(6.6f);
                    });
                });
                layers.Layer().AlignMiddle().Text(t =>
                {
                    t.AlignCenter();
                    t.Span("Option : Supplier wise").FontSize(6.6f).Bold().FontColor(Teal);
                });
            });
            col.Item().PaddingTop(1).LineHorizontal(1f).LineColor(Black);
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
            .OrderBy(r => r.SupplierCode, StringComparer.OrdinalIgnoreCase)
            .ThenBy(r => r.PoDate)
            .ThenBy(r => ParsePoNo(r.PoNo))
            .ThenBy(r => r.ItemCode, StringComparer.OrdinalIgnoreCase)
            .ToList();

        var groups = ordered
            .GroupBy(r => new { r.SupplierCode, r.SupplierName })
            .ToList();

        container.Column(col =>
        {
            ComposeHeader(col);

            foreach (var group in groups)
            {
                col.Item().Text(group.Key.SupplierName).Bold().FontSize(5.8f).FontColor(Green);

                foreach (var row in group)
                {
                    col.Item().PaddingBottom(1.5f).Column(rc =>
                    {
                        rc.Item().Row(r =>
                        {
                            r.ConstantItem(R1OrderDate).Text(Dt(row.PoDate)).FontColor(Black).AlignCenter();
                            r.ConstantItem(R1PrNo).Text(row.PoNo).FontColor(Black).AlignCenter();
                            r.ConstantItem(R1ItemId).Text(row.ItemCode).FontColor(Black).AlignCenter();
                            r.ConstantItem(R1ItemName).Text(row.ItemName ?? "").FontColor(Black);
                            r.ConstantItem(R1QuotationNo).Text(row.QuotationNo ?? "").FontColor(Black).AlignCenter();
                            r.ConstantItem(R1CarrierName).Text(row.CarrierName ?? "").FontColor(Black);
                            r.ConstantItem(R1OrderValue).Text(Ind(row.OrderValue, 2)).FontColor(Black).AlignRight();
                            r.ConstantItem(R1AdvPct).Text(FormatPct(row.AdvancePercent)).FontColor(Black).AlignRight();
                            r.ConstantItem(R1AdvanceAmt).PaddingRight(2).Text(row.AdvanceAmount != 0 ? Ind(row.AdvanceAmount, 2) : "").FontColor(Black).AlignRight();
                            r.ConstantItem(R1AdvPayGap).Text("");
                            r.ConstantItem(R1PaymentMode).Text(row.PaymentMode ?? "").FontColor(Black);
                            r.ConstantItem(R1DeliveryIns).Text(row.DeliveryInstructions ?? "").FontColor(Black);
                            r.ConstantItem(R1SpecialIns).Text(row.SpecialInstructions ?? "").FontColor(Black);
                            r.ConstantItem(R1DueDate).Text(Dt(row.DueDate)).FontColor(Black).AlignCenter();
                        });
                        rc.Item().Row(r =>
                        {
                            r.ConstantItem(R2BlankLead).Text("");
                            r.ConstantItem(R2PrNo).Text(row.PrNo ?? "").FontColor(Black).AlignCenter();
                            r.ConstantItem(R2BlankTail).Text("");
                            r.ConstantItem(R2Unit).Text(row.Uom ?? "").FontColor(Black).AlignCenter();
                            r.ConstantItem(R2Rate).Text(Ind(row.Rate, 2)).FontColor(Black).AlignRight();
                            r.ConstantItem(R2OrderedQty).Text(Ind(row.QtyOrdered, 3)).FontColor(Black).AlignRight();
                            // True source (Reports_Vb6\new\PO-Supplierwise.rpt): the Item Value column
                            // binds to {poitemvalue} = line PO_ORDL.ORDVAL — NOT the header order
                            // value. Only the Order Value column binds to {ORDVAL} = PO_ORDH.ORDVAL.
                            r.ConstantItem(R2ItemValue).Text(Ind(row.LineValue, 2)).FontColor(Black).AlignRight();
                            r.ConstantItem(R2GstAmount).Text(Ind(row.TaxAmount, 2)).FontColor(Black).AlignRight();
                            r.ConstantItem(R2CrdDays).Text(row.CrdDays.ToString()).FontColor(Black).AlignRight();
                        });
                    });
                }

                // Order Value total = the PO HEADER value ({ORDVAL} = h.ORDVAL) counted ONCE per PO.
                // Item Value total = the per-line value ({poitemvalue} = l.ORDVAL) summed per line.
                // The two columns bind to DIFFERENT fields — see the detail rows above.
                var groupOrderValue = group.GroupBy(r => r.PoNo).Sum(pg => pg.First().OrderValue);
                var groupQty        = group.Sum(r => r.QtyOrdered);
                var groupItemValue  = group.Sum(r => r.LineValue);
                var groupGst        = group.Sum(r => r.TaxAmount);

                col.Item().LineHorizontal(1f).LineColor(Black);
                col.Item().PaddingVertical(1).Row(r =>
                {
                    r.ConstantItem(TotBlank1).Text("");
                    r.ConstantItem(TotLabel).Text("Supplierwise Total").Bold().FontColor(Maroon);
                    r.ConstantItem(TotOrderValue).Text(Western(groupOrderValue, 2)).Bold().FontColor(Maroon).AlignRight();
                    r.ConstantItem(TotBlank2).Text("");
                    r.ConstantItem(TotQty).Text(Ind(groupQty, 3)).Bold().FontColor(Maroon).AlignRight();
                    r.ConstantItem(TotBlank3).Text("");
                    r.ConstantItem(TotItemValue).Text(Ind(groupItemValue, 2)).Bold().FontColor(Maroon).AlignRight();
                    r.ConstantItem(TotGstAmount).Text(Ind(groupGst, 2)).Bold().FontColor(Maroon).AlignRight();
                });
                col.Item().LineHorizontal(1f).LineColor(Black);
            }

            // Report-level Grand Total: Order Value (Western) + Item Value (Indian) only, per extracted last-page total row.
            var grandOrderValue = _rows.GroupBy(r => r.PoNo).Sum(pg => pg.First().OrderValue);
            var grandItemValue  = _rows.Sum(r => r.LineValue);
            col.Item().PaddingTop(2).Row(r =>
            {
                // Report-level Grand Total is Purple in the reference, unlike the per-supplier
                // "Supplierwise Total" (Maroon) - confirmed via span color extraction, 06-Jul.
                r.ConstantItem(TotBlank1).Text("");
                r.ConstantItem(TotLabel).Text("Grand Total").Bold().FontColor(Purple);
                r.ConstantItem(TotOrderValue).Text(Western(grandOrderValue, 2)).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(TotBlank2 + TotQty + TotBlank3).Text("");
                r.ConstantItem(TotItemValue).Text(Ind(grandItemValue, 2)).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(TotGstAmount).Text("");
            });

            // Abstract (Report Footer b subreport).
            // .AlignCenter() directly on a plain-string Text() call doesn't center it (renders hard
            // right - confirmed via span position, 06-Jul) - the lambda form used elsewhere in this
            // file for centered text is the pattern that actually works.
            col.Item().PaddingTop(4).Text(t => { t.AlignCenter(); t.Span("Abstract").FontSize(9.95f).Bold().FontColor(Maroon); });
            ComposeAbstract(col, ordered);
        });
    }

    private static void ComposeHeader(ColumnDescriptor col)
    {
        // The reference header is a single interleaved 5-line band, not two stacked full-width rows:
        // "Carrier Name"/"Order Value"/"Adv. %"/"Advance Amount"/"Payment mode"/"Delivery Instruction"/
        // "Special Instruction"/"Due Date" sit on lines A-B, while "Order Date"/"Order No. PR. No."/
        // "Item ID"/"Item Name"/"Quotation No." sit one/two lines lower (C-D), and the R2 grid's own
        // labels (Unit/Rate/Ordered Qty/Item Value/GST Amount/Crd-Days) interleave at lines D-E, at
        // x-positions that genuinely overlap the R1 grid's line A-B columns - confirmed via span
        // extraction, 06-Jul. QuestPDF Row items can't overlap, so this uses Layers() (same technique
        // as ComposeTitle's "Option : Supplier wise" overlay) to stack the R1 row, a "Supplier Name"
        // label, and the R2 row at their correct relative vertical offsets.
        col.Item().Layers(layers =>
        {
            layers.PrimaryLayer().Row(r =>
            {
                r.ConstantItem(R1OrderDate).Text("\n\nOrder\nDate\n").FontSize(5.8f).Bold().FontColor(Purple).AlignCenter();
                r.ConstantItem(R1PrNo).Text("\n\nOrder No.\nPR. No.").FontSize(5.8f).Bold().FontColor(Purple).AlignCenter();
                r.ConstantItem(R1ItemId).Text("\n\nItem ID").FontSize(5.8f).Bold().FontColor(Purple).AlignCenter();
                r.ConstantItem(R1ItemName).Text("\n\nItem Name").FontSize(5.8f).Bold().FontColor(Purple);
                r.ConstantItem(R1QuotationNo).Text("\n\nQuotation\nNo.").FontSize(5.8f).Bold().FontColor(Purple).AlignCenter();
                r.ConstantItem(R1CarrierName).Text("Carrier Name").FontSize(5.8f).Bold().FontColor(Purple);
                r.ConstantItem(R1OrderValue).Text("Order\nValue").FontSize(5.8f).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(R1AdvPct).Text("Adv. %").FontSize(5.8f).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(R1AdvanceAmt).PaddingRight(2).Text("Advance\nAmount").FontSize(5.8f).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(R1AdvPayGap).Text("");
                r.ConstantItem(R1PaymentMode).Text("Payment mode").FontSize(5.8f).Bold().FontColor(Purple);
                r.ConstantItem(R1DeliveryIns).Text("Delivery\nInstruction").FontSize(5.8f).Bold().FontColor(Purple);
                r.ConstantItem(R1SpecialIns).Text("Special\nInstruction").FontSize(5.8f).Bold().FontColor(Purple);
                r.ConstantItem(R1DueDate).Text("Due\nDate").FontSize(5.8f).Bold().FontColor(Purple).AlignCenter();
            });
            layers.Layer().Row(r =>
            {
                r.ConstantItem(R1OrderDate + R1PrNo).Text("Supplier Name").FontSize(5.8f).Bold().FontColor(Purple);
            });
            layers.Layer().PaddingTop(21f).Row(r =>
            {
                r.ConstantItem(R2BlankLead + R2PrNo + R2BlankTail).Text("");
                r.ConstantItem(R2Unit).Text("Unit").FontSize(5.8f).Bold().FontColor(Purple).AlignCenter();
                r.ConstantItem(R2Rate).Text("Rate /\nUnit").FontSize(5.8f).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(R2OrderedQty).Text("Ordered\nQuantity").FontSize(5.8f).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(R2ItemValue).Text("Item\nValue").FontSize(5.8f).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(R2GstAmount).Text("GST\nAmount").FontSize(5.8f).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(R2CrdDays).Text("Crd-Days").FontSize(5.8f).Bold().FontColor(Purple).AlignRight();
            });
        });
        col.Item().LineHorizontal(1f).LineColor(Black);
    }

    private static void ComposeAbstract(ColumnDescriptor col, List<PoSupplierWiseRowDto> ordered)
    {
        const float A1 = 46.5f;  // S.No.
        const float A2 = 337.2f; // Supplier Name
        const float A3 = 91.9f;  // Order Value (Western)
        const float A4 = 68.4f;  // Ordered Quantity
        const float A5 = 73.5f;  // Item Value (Indian)
        const float A6 = 47.0f;  // GST Amount (Indian)

        var abstractData = ordered
            .GroupBy(r => new { r.SupplierCode, r.SupplierName })
            .OrderBy(g => g.Key.SupplierCode, StringComparer.OrdinalIgnoreCase)
            .Select((g, i) => new
            {
                SlNo = i + 1,
                g.Key.SupplierName,
                OrderValue = g.GroupBy(r => r.PoNo).Sum(pg => pg.First().OrderValue),
                Qty        = g.Sum(r => r.QtyOrdered),
                ItemValue  = g.Sum(r => r.LineValue),
                GstAmount  = g.Sum(r => r.TaxAmount),
            })
            .ToList();

        // A Border/Column doesn't shrink-wrap to its content's width - it stretches to fill whatever
        // space is available, so a plain PaddingLeft() left the box ~764pt wide (nearly full page)
        // instead of the intended 664.5pt, with almost no gap on the right - confirmed via
        // border-rectangle extraction after the user reported it looking right-shifted. Wrapping in a
        // Row with a ConstantItem forces the exact width; equal left/right ConstantItem spacers center
        // it in the page content width (811.6 - 664.5 = 147.1, split evenly).
        // +4f accounts for the PaddingHorizontal(2) applied inside every row below (2pt each side) -
        // without it, the fixed-width outer ConstantItem is 4pt narrower than what the padded rows
        // actually need, which QuestPDF reports as a layout constraint conflict.
        const float AbstractWidth = A1 + A2 + A3 + A4 + A5 + A6 + 4f;
        const float AbstractInset = (811.6f - AbstractWidth) / 2f;
        col.Item().Row(outer =>
        {
            outer.ConstantItem(AbstractInset);
            outer.ConstantItem(AbstractWidth).Border(1f).BorderColor(Black).Column(box =>
        {
            box.Item().PaddingHorizontal(2).PaddingTop(2).Row(r =>
            {
                r.ConstantItem(A1).Text("S.No.").FontSize(6.6f).Bold().FontColor(Purple).AlignCenter();
                r.ConstantItem(A2).Text("Supplier Name").FontSize(6.6f).Bold().FontColor(Purple);
                r.ConstantItem(A3).Text("Order Value").FontSize(6.6f).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(A4).Text("Ordered Quantity").FontSize(6.6f).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(A5).Text("Item Value").FontSize(6.6f).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(A6).Text("GST Amount").FontSize(6.6f).Bold().FontColor(Purple).AlignRight();
            });
            box.Item().PaddingHorizontal(2).LineHorizontal(1f).LineColor(Black);

            foreach (var item in abstractData)
            {
                box.Item().PaddingHorizontal(2).Row(r =>
                {
                    r.ConstantItem(A1).Text(item.SlNo.ToString()).FontColor(Black).AlignCenter();
                    r.ConstantItem(A2).Text(item.SupplierName).FontColor(Black);
                    r.ConstantItem(A3).Text(item.OrderValue != 0 ? Western(item.OrderValue, 2) : "").FontColor(Black).AlignRight();
                    r.ConstantItem(A4).Text(Ind(item.Qty, 3)).FontColor(Black).AlignRight();
                    r.ConstantItem(A5).Text(Ind(item.ItemValue, 2)).FontColor(Black).AlignRight();
                    r.ConstantItem(A6).Text(Ind(item.GstAmount, 2)).FontColor(Black).AlignRight();
                });
            }

            var totQty       = abstractData.Sum(a => a.Qty);
            var totOrderVal  = abstractData.Sum(a => a.OrderValue);
            var totItemVal   = abstractData.Sum(a => a.ItemValue);
            var totGst       = abstractData.Sum(a => a.GstAmount);

            box.Item().PaddingHorizontal(2).LineHorizontal(1f).LineColor(Black);
            box.Item().PaddingHorizontal(2).Row(r =>
            {
                r.ConstantItem(A1 + A2).Text("");
                r.ConstantItem(A3).Text("");
                r.ConstantItem(A4).Text(Ind(totQty, 3)).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(A5).Text("");
                r.ConstantItem(A6).Text(Ind(totGst, 2)).Bold().FontColor(Purple).AlignRight();
            });
            box.Item().PaddingHorizontal(2).PaddingBottom(2).Row(r =>
            {
                r.ConstantItem(A1).Text("");
                r.ConstantItem(A2).Text("Grand Total").Bold().FontColor(Purple);
                r.ConstantItem(A3).Text(totOrderVal != 0 ? Western(totOrderVal, 2) : "").Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(A4).Text("");
                r.ConstantItem(A5).Text(Ind(totItemVal, 2)).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(A6).Text("");
            });
        });
        });
    }

    // Indian digit grouping (e.g. 5180376.36 -> "51,80,376.36") to match the RPT '##,##,##,###.##' masks.
    private static string Ind(decimal value, int decimals)
    {
        bool neg = value < 0;
        string fixedStr = Math.Abs(value).ToString("F" + decimals, CultureInfo.InvariantCulture);
        int dot = fixedStr.IndexOf('.');
        string intPart  = dot >= 0 ? fixedStr[..dot] : fixedStr;
        string fracPart = dot >= 0 ? fixedStr[dot..] : "";

        string grouped;
        if (intPart.Length <= 3)
        {
            grouped = intPart;
        }
        else
        {
            string last3 = intPart[^3..];
            string rest  = intPart[..^3];
            var sb = new StringBuilder();
            int count = 0;
            for (int i = rest.Length - 1; i >= 0; i--)
            {
                sb.Insert(0, rest[i]);
                count++;
                if (count % 2 == 0 && i != 0) sb.Insert(0, ',');
            }
            grouped = sb.ToString() + "," + last3;
        }
        return (neg ? "-" : "") + grouped + fracPart;
    }

    // Western (3-digit) grouping - reference report uses this ONLY for Order-Value subtotal/grand-total
    // figures, while every other value (incl. per-line Order Value) uses Indian grouping via Ind(). This
    // is a genuine legacy Crystal Report formatting inconsistency, replicated bug-for-bug per project decision.
    private static string Western(decimal value, int decimals) =>
        value.ToString("N" + decimals, CultureInfo.InvariantCulture);

    // "dd/MM/yy" left unescaped would use the CURRENT CULTURE's date separator (e.g. "-" on this
    // machine), not a literal "/" - the reference report always uses "/" regardless of locale.
    private static string Dt(DateTime? value) =>
        value?.ToString("dd/MM/yy", CultureInfo.InvariantCulture) ?? "";

    private static string FormatPct(decimal value) =>
        value == 0 ? "" : $"{Ind(value, 2)}%";

    // PoNo may now carry a "AD/"/"CR/" prefix (see PoNo CASE expression in the SP) - sort on the
    // numeric part after the last '/' so PO order is preserved regardless of prefix.
    private static int ParsePoNo(string? poNo)
    {
        var numeric = poNo?.Contains('/') == true ? poNo[(poNo.LastIndexOf('/') + 1)..] : poNo;
        return int.TryParse(numeric, NumberStyles.Integer, CultureInfo.InvariantCulture, out var n) ? n : int.MaxValue;
    }

    private static string FormatUnit(string unit)
    {
        var u = unit.Trim();
        return u.StartsWith("(Unit", StringComparison.OrdinalIgnoreCase) ? u : $"(Unit - {u})";
    }

    private static void ComposeFooter(IContainer container)
    {
        container.Text(t => t.Span("@Kalsofte").FontSize(6.5f).Bold().FontColor(Grey));
    }
}
