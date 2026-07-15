using System.Globalization;
using System.Text;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using Spinrise.Application.Areas.PurchaseOrder.PoReport.DTOs;

namespace Spinrise.Reports.Areas.PurchaseOrder.Documents;

// Design (page setup, title block, fonts, colors, separator line) mirrors
// PoSupplierWiseDocument.cs — same report family; only the data columns/rows differ.
public sealed class PoDateWiseDocument : IDocument
{
    private const string Font   = "Tahoma";
    private const string Navy   = "#000080";
    private const string Maroon = "#800000";
    private const string Teal   = "#008080";
    private const string Black  = "#000000";
    private const string Purple = "#800080";
    private const string Green  = "#008000";

    // ── Row-1 (summary line) column widths (pt), derived from reppo-datewise.pdf header
    //    x-positions; numeric columns anchored to right-edges (SupplierWise-proven), not
    //    label x0 deltas. 13 cols, sum = 811.6 (A4-landscape content width, 18/11.4 margins).
    private const float R1OrderDate   = 43.4f;   // x0=18.0
    private const float R1OrderNo     = 34.6f;   // x0=61.4
    private const float R1SupplierName = 155.3f; // x0=96.0
    private const float R1QuotationNo = 36.7f;   // x0=251.3
    private const float R1CarrierName = 129.1f;  // x0=288.0, end=417.1
    private const float R1OrderValue  = 57.1f;   // x0=417.1, end=474.2 (right-aligned)
    private const float R1AdvPct      = 34.9f;   // end=509.1
    private const float R1AdvanceAmt  = 48.9f;   // end=558.0
    private const float R1BalanceAmt  = 42.0f;   // end=600.0
    private const float R1BalPayGap   = 6.0f;    // visible spacer column between Balance Amount & Payment mode
    private const float R1PaymentMode = 36.0f;   // was 42.0; -6.0 funds the Balance/Payment spacer (Payment mode is left-aligned, shifts right to open the gap)
    private const float R1DeliveryIns = 84.0f;   // x0=642.0
    private const float R1SpecialIns  = 67.8f;   // x0=726.0
    private const float R1DueDate     = 35.8f;   // x0=793.8, end=829.6

    // ── Row-2 (detail line) column widths (pt), independent grid. Front (blank/PR.No/Item ID/
    //    Item Name) sums to 354.0; Unit-onward matches SupplierWise's tuned R2 values exactly
    //    (same physical columns). 10 items incl. leading blank, sum = 811.6.
    private const float R2BlankLead  = 43.4f;    // under Order Date
    private const float R2PrNo       = 34.6f;    // under Order No.
    private const float R2ItemId     = 60.0f;    // x0=96.0
    private const float R2ItemName   = 216.0f;   // x0=156.0, end=372.0
    private const float R2Unit       = 26.0f;    // x0=372.0, end=398.0
    private const float R2Rate       = 56.8f;    // end=454.8
    private const float R2OrderedQty = 58.6f;    // end=513.4
    private const float R2ItemValue  = 93.5f;    // end=606.9
    private const float R2GstAmount  = 75.9f;    // end=682.8
    private const float R2CrdDays    = 146.8f;   // end=829.6

    // ── Day Total row column widths (pt). Right-edges from reppo-datewise.pdf day-total
    //    row: Order Value end=444.2, Qty end=513.3, Item Value end=606.9, GST end=682.8.
    //    Sum = 811.6.
    private const float DtBlank1     = 282.0f;   // 18 -> 300 (label starts at 300)
    private const float DtLabel      = 86.2f;    // "Day Total"
    private const float DtOrderValue = 58.0f;    // end=444.2 (right)
    private const float DtBlank2     = 39.1f;
    private const float DtQty        = 30.0f;    // end=513.3 (right)
    private const float DtItemValue  = 93.6f;    // end=606.9 (right)
    private const float DtGst        = 75.9f;    // end=682.8 (right)
    private const float DtTrail      = 146.8f;   // end=829.6

    private readonly IReadOnlyList<PoDateWiseRowDto> _rows;
    private readonly PoReportRequest _request;
    private readonly string _printName;
    private readonly string _unitName;

    public PoDateWiseDocument(IReadOnlyList<PoDateWiseRowDto> rows, PoReportRequest request)
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

            // Line order within a PO must match legacy Crystal: PR number, then item code. The
            // Date-Wise "Order Value" is the FIRST line's value (Crystal group-header shows the
            // group's first record), so this ordering directly drives that figure — sorting by
            // ItemCode alone picked the wrong first line (the 03-Jul ₹233,200 Day-Total defect:
            // CA/1253 took item 1111002 = 200 instead of PR-first 120E015 = 2,33,400).
            var ordered = _rows
                .OrderBy(r => r.PoDate)
                .ThenBy(r => ParsePoNo(r.PoNo))
                .ThenBy(r => ParsePrNo(r.PrNo))
                .ThenBy(r => r.ItemCode, StringComparer.OrdinalIgnoreCase)
                .ToList();

            // Group by Order Date; within each date, one PO-summary line (Row-1 grid) per PO
            // then a detail line (Row-2 grid) per item; a "Day Total" row closes each date group.
            decimal grandOrderValue = 0, grandQty = 0, grandItemValue = 0, grandGst = 0;

            foreach (var dateGroup in ordered.GroupBy(r => r.PoDate?.Date))
            {
                decimal dayOrderValue = 0, dayQty = 0, dayItemValue = 0, dayGst = 0;

                foreach (var poGroup in dateGroup.GroupBy(r => new { r.OrderType, r.PoNo }))
                {
                    var first = poGroup.First();
                    // Order Value = the PO HEADER order value (PO_ORDH.ORDVAL). The true source
                    // (Reports_Vb6\new\PO-Datewise.rpt) binds this column to {ORDVAL}, which the
                    // legacy SP selects from PO_ORDH — NOT the line value. It is a per-PO figure,
                    // so the Day Total counts it once per PO. The Item Value column is the separate
                    // per-line {poitemvalue} = PO_ORDL.ORDVAL (= LineValue), summed across lines.
                    // Being header-sourced, this is constant across the PO's lines — so it no
                    // longer depends on which line sorts first (the old ₹233,200 Day-Total defect).
                    var poOrderValue = first.HeaderOrderValue;

                    col.Item().PaddingTop(1).Column(rc =>
                    {
                        // Summary line — Row-1 grid
                        rc.Item().Row(r =>
                        {
                            r.ConstantItem(R1OrderDate).Text(Dt(first.PoDate)).Bold().FontColor(Green).AlignCenter();
                            r.ConstantItem(R1OrderNo).Text(FormatPoNo(first)).Bold().FontColor(Green).AlignCenter();
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

                        // Detail lines — Row-2 grid, one per item
                        foreach (var row in poGroup)
                        {
                            rc.Item().Row(r =>
                            {
                                r.ConstantItem(R2BlankLead).Text("");
                                r.ConstantItem(R2PrNo).Text(row.PrNo ?? "").FontColor(Black).AlignCenter();
                                r.ConstantItem(R2ItemId).Text(row.ItemCode ?? "").FontColor(Black).AlignCenter();
                                r.ConstantItem(R2ItemName).Text(row.ItemName ?? "").FontColor(Black);
                                r.ConstantItem(R2Unit).Text(row.Uom ?? "").FontColor(Black).AlignCenter();
                                r.ConstantItem(R2Rate).Text(Ind(row.Rate, 2)).FontColor(Black).AlignRight();
                                r.ConstantItem(R2OrderedQty).Text(Ind(row.QtyOrdered, 3)).FontColor(Black).AlignRight();
                                r.ConstantItem(R2ItemValue).Text(Ind(row.LineValue, 2)).FontColor(Black).AlignRight();
                                r.ConstantItem(R2GstAmount).Text(row.TaxAmount != 0 ? Ind(row.TaxAmount, 2) : "").FontColor(Black).AlignRight();
                                r.ConstantItem(R2CrdDays).Text(Ind(row.CrdDays, 2)).FontColor(Black).AlignRight();
                            });
                        }
                    });

                    dayOrderValue += poOrderValue;
                    dayQty        += poGroup.Sum(r => r.QtyOrdered);
                    dayItemValue  += poGroup.Sum(r => r.LineValue);
                    dayGst        += poGroup.Sum(r => r.TaxAmount);
                }

                // Day Total row — line above, the total, line below (SupplierWise group-total technique).
                col.Item().PaddingTop(1).LineHorizontal(0.5f).LineColor(Black);
                col.Item().PaddingVertical(1).Row(r =>
                {
                    r.ConstantItem(DtBlank1).Text("");
                    r.ConstantItem(DtLabel).Text("Day Total").Bold().FontColor(Maroon);
                    r.ConstantItem(DtOrderValue).Text(Western(dayOrderValue, 2)).Bold().FontColor(Maroon).AlignRight();
                    r.ConstantItem(DtBlank2).Text("");
                    r.ConstantItem(DtQty).Text(Ind(dayQty, 3)).Bold().FontColor(Maroon).AlignRight();
                    r.ConstantItem(DtItemValue).Text(Ind(dayItemValue, 2)).Bold().FontColor(Maroon).AlignRight();
                    r.ConstantItem(DtGst).Text(Ind(dayGst, 2)).Bold().FontColor(Maroon).AlignRight();
                    r.ConstantItem(DtTrail).Text("");
                });
                col.Item().LineHorizontal(0.5f).LineColor(Black);

                grandOrderValue += dayOrderValue;
                grandQty        += dayQty;
                grandItemValue  += dayItemValue;
                grandGst        += dayGst;
            }

            // Report-level Grand Total — Purple in the reference (vs Maroon Day Total).
            col.Item().PaddingTop(2).LineHorizontal(0.75f).LineColor(Black);
            col.Item().PaddingVertical(1).Row(r =>
            {
                r.ConstantItem(DtBlank1).Text("");
                r.ConstantItem(DtLabel).Text("Grand Total").Bold().FontColor(Purple);
                r.ConstantItem(DtOrderValue).Text(Western(grandOrderValue, 2)).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(DtBlank2).Text("");
                r.ConstantItem(DtQty).Text(Ind(grandQty, 3)).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(DtItemValue).Text(Ind(grandItemValue, 2)).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(DtGst).Text(Ind(grandGst, 2)).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(DtTrail).Text("");
            });
            col.Item().LineHorizontal(0.75f).LineColor(Black);

            // Abstract (per-date summary sub-table) — same boxed design as PoSupplierWiseDocument.
            col.Item().PaddingTop(4).Text(t => { t.AlignCenter(); t.Span("Abstract").FontSize(9.95f).Bold().FontColor(Maroon); });
            ComposeAbstract(col, ordered);
        });
    }

    private static void ComposeAbstract(ColumnDescriptor col, List<PoDateWiseRowDto> ordered)
    {
        const float A1 = 44f;   // S.No.
        const float A2 = 80f;   // Order Date
        const float A3 = 59f;   // Order Value (Western)
        const float A4 = 75f;   // Ordered Quantity
        const float A5 = 78f;   // Item Value (Indian)
        const float A6 = 78f;   // GST Amount (Indian)

        // One row per date; per-date Order Value = each PO's HEADER order value counted ONCE per
        // PO, matching the Day Total. Group by OrderType+PoNo so same-number POs (AD/1254 vs
        // CR/1254) don't merge; HeaderOrderValue is constant within a PO, so pg.First() is exact.
        var abstractData = ordered
            .GroupBy(r => r.PoDate?.Date)
            .Select((g, i) => new
            {
                SlNo       = i + 1,
                Date       = g.Key,
                OrderValue = g.GroupBy(r => new { r.OrderType, r.PoNo }).Sum(pg => pg.First().HeaderOrderValue),
                Qty        = g.Sum(r => r.QtyOrdered),
                ItemValue  = g.Sum(r => r.LineValue),
                GstAmount  = g.Sum(r => r.TaxAmount),
            })
            .ToList();

        const float AbstractWidth = A1 + A2 + A3 + A4 + A5 + A6 + 4f;
        const float AbstractInset = 166f;  // matches reference box left edge (page x=184)
        col.Item().Row(outer =>
        {
            outer.ConstantItem(AbstractInset);
            outer.ConstantItem(AbstractWidth).Border(1f).BorderColor(Black).Column(box =>
            {
                box.Item().PaddingHorizontal(2).PaddingTop(2).Row(r =>
                {
                    r.ConstantItem(A1).Text("S.No.").FontSize(6.6f).Bold().FontColor(Purple).AlignCenter();
                    r.ConstantItem(A2).Text("Order Date").FontSize(6.6f).Bold().FontColor(Purple);
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
                        r.ConstantItem(A2).Text(Dt(item.Date)).FontColor(Black);
                        r.ConstantItem(A3).Text(item.OrderValue != 0 ? Western(item.OrderValue, 2) : "").FontColor(Black).AlignRight();
                        r.ConstantItem(A4).Text(Ind(item.Qty, 3)).FontColor(Black).AlignRight();
                        r.ConstantItem(A5).Text(Ind(item.ItemValue, 2)).FontColor(Black).AlignRight();
                        r.ConstantItem(A6).Text(Ind(item.GstAmount, 2)).FontColor(Black).AlignRight();
                    });
                }

                var totQty      = abstractData.Sum(a => a.Qty);
                var totOrderVal = abstractData.Sum(a => a.OrderValue);
                var totItemVal  = abstractData.Sum(a => a.ItemValue);
                var totGst      = abstractData.Sum(a => a.GstAmount);

                box.Item().PaddingHorizontal(2).LineHorizontal(1f).LineColor(Black);
                box.Item().PaddingHorizontal(2).Row(r =>
                {
                    r.ConstantItem(A1 + A2).Text("");
                    r.ConstantItem(A3).Text("");
                    r.ConstantItem(A4).Text(Ind(totQty, 3)).Bold().FontColor(Purple).AlignRight();
                    r.ConstantItem(A5).Text("");
                    r.ConstantItem(A6).Text(Ind(totGst, 2)).Bold().FontColor(Purple).AlignRight();
                });
                // Blank row before the Grand Total (matches the reference gap).
                box.Item().Height(9f);
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

    // Two header label rows, aligned with the same Layers() technique as
    // PoSupplierWiseDocument.ComposeHeader: Row-1 grid on the primary layer, Row-2 grid
    // overlaid on a second layer pushed down (PaddingTop) to the lower label line.
    private static void ComposeHeader(ColumnDescriptor col)
    {
        col.Item().Layers(layers =>
        {
            layers.PrimaryLayer().Row(r =>
            {
                r.ConstantItem(R1OrderDate).Text("Order\nDate\n\n\n").FontSize(5.8f).Bold().FontColor(Purple).AlignCenter();
                r.ConstantItem(R1OrderNo).Text("Order No.").FontSize(5.8f).Bold().FontColor(Purple).AlignCenter();
                r.ConstantItem(R1SupplierName).Text("Supplier Name").FontSize(5.8f).Bold().FontColor(Purple);
                r.ConstantItem(R1QuotationNo).Text("Quotation\nNo.").FontSize(5.8f).Bold().FontColor(Purple).AlignCenter();
                r.ConstantItem(R1CarrierName).Text("Carrier Name").FontSize(5.8f).Bold().FontColor(Purple);
                r.ConstantItem(R1OrderValue).Text("Order\nValue").FontSize(5.8f).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(R1AdvPct).Text("Adv. %").FontSize(5.8f).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(R1AdvanceAmt).Text("Advance\nAmount").FontSize(5.8f).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(R1BalanceAmt).Text("Balance\nAmount").FontSize(5.8f).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(R1BalPayGap).Text("");
                r.ConstantItem(R1PaymentMode).Text("Payment\nmode").FontSize(5.8f).Bold().FontColor(Purple);
                r.ConstantItem(R1DeliveryIns).Text("Delivery\nInstruction").FontSize(5.8f).Bold().FontColor(Purple);
                r.ConstantItem(R1SpecialIns).Text("Special\nInstruction").FontSize(5.8f).Bold().FontColor(Purple);
                r.ConstantItem(R1DueDate).Text("Due\nDate").FontSize(5.8f).Bold().FontColor(Purple).AlignCenter();
            });
            layers.Layer().PaddingTop(21f).Row(r =>
            {
                r.ConstantItem(R2BlankLead).Text("");
                r.ConstantItem(R2PrNo).Text("PR. No.").FontSize(5.8f).Bold().FontColor(Purple).AlignCenter();
                r.ConstantItem(R2ItemId).Text("Item ID").FontSize(5.8f).Bold().FontColor(Purple).AlignCenter();
                r.ConstantItem(R2ItemName).Text("Item Name").FontSize(5.8f).Bold().FontColor(Purple);
                r.ConstantItem(R2Unit).Text("Unit").FontSize(5.8f).Bold().FontColor(Purple).AlignCenter();
                r.ConstantItem(R2Rate).Text("Rate/Unit").FontSize(5.8f).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(R2OrderedQty).Text("Ordered\nQuantity").FontSize(5.8f).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(R2ItemValue).Text("Item\nValue").FontSize(5.8f).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(R2GstAmount).Text("GST\nAmount").FontSize(5.8f).Bold().FontColor(Purple).AlignRight();
                r.ConstantItem(R2CrdDays).Text("Crd-Days").FontSize(5.8f).Bold().FontColor(Purple).AlignRight();
            });
        });
        col.Item().LineHorizontal(1f).LineColor(Black);
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
                        t.Span($"Purchase Order List from {Dt(_request.FromDate)} To {Dt(_request.ToDate)}")
                         .FontSize(8.3f).Bold().FontColor(Maroon);
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
                    t.Span("Option : Date wise").FontSize(6.6f).Bold().FontColor(Teal);
                });
            });
            col.Item().PaddingTop(1).LineHorizontal(1f).LineColor(Black);
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
    private static string FormatPoNo(PoDateWiseRowDto row) =>
        string.IsNullOrWhiteSpace(row.OrderType) ? row.PoNo : $"{row.OrderType}/{row.PoNo}";

    // Indian lakh/crore grouping (12,34,567.89) — matches the legacy Crystal totext formulas.
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

    // Order Value totals use Western grouping (7,779,738.90) while every other figure uses
    // Indian (1,36,15,725.90) — a legacy Crystal quirk, same as PoSupplierWiseDocument.
    private static string Western(decimal value, int decimals) =>
        value.ToString("N" + decimals, CultureInfo.InvariantCulture);

    private static string FormatPct(decimal value) =>
        value == 0 ? "" : $"{Ind(value, 2)}%";

    // PoNo may carry a "AD/"/"CR/" prefix — sort on the numeric part after the last '/'.
    private static int ParsePoNo(string? poNo)
    {
        var numeric = poNo?.Contains('/') == true ? poNo[(poNo.LastIndexOf('/') + 1)..] : poNo;
        return int.TryParse(numeric, NumberStyles.Integer, CultureInfo.InvariantCulture, out var n) ? n : int.MaxValue;
    }

    // PR number used only for line ordering within a PO (legacy line sequence). A blank/direct-PO
    // PR (PRNO 0/null in the source) sorts first, matching the legacy natural order.
    private static long ParsePrNo(string? prNo)
        => long.TryParse(prNo, NumberStyles.Integer, CultureInfo.InvariantCulture, out var n) ? n : 0;
}
