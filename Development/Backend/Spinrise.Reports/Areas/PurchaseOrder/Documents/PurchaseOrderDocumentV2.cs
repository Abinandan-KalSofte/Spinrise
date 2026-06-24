using System.Globalization;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using Spinrise.Application.Areas.PurchaseOrder.PoEntry.DTOs;
using Spinrise.Shared.Utilities;

namespace Spinrise.Reports.Areas.PurchaseOrder.Documents;

public sealed class PurchaseOrderDocumentV2 : IDocument
{
    private readonly PoPrintDto _po;

    private const float Margin = 6.3f;
    private const string Font = "Calibri";
    private const float FsCompany = 14f;
    private const float FsInfo = 10f;
    private const float FsData = 9f;
    private const float FsSmall = 8f;
    private const string Navy = "#185FA5";
    private const string Black = "#000000";
    private const float BdBox = 1.0f;
    private const float BdCell = 0.5f;

    // Item-table column widths (mm proportions; switched to RelativeColumn so the
    // table fills full container width). Order: S.No | Item Name | HSN | Order Qty
    // | Unit | Rate/Unit | Disc% | CGST | SGST | IGST | Value.
    // OA-02: Rate/Unit widened 19→23 to fit 12-char values like "5,00,000.0000"
    // without wrapping into the Disc column; Item Name compensated 54→50 so the
    // total (193) is unchanged.
    private static readonly float[] Cols = { 8f, 50f, 17f, 16f, 11f, 23f, 11f, 13f, 13f, 13f, 18f };

    private static readonly NumberFormatInfo InFmt = new()
    {
        NumberGroupSizes = new[] { 3, 2 },
        NumberGroupSeparator = ",",
        NumberDecimalSeparator = "."
    };

    private static string F2(decimal v) => v.ToString("N2", InFmt);
    private static string F3(decimal v) => v.ToString("N3", InFmt);
    private static string F4(decimal v) => v.ToString("N4", InFmt);

    public PurchaseOrderDocumentV2(PoPrintDto po) => _po = po;

    public static byte[] Generate(PoPrintDto po) => new PurchaseOrderDocumentV2(po).GeneratePdf();

    public DocumentMetadata GetMetadata() => DocumentMetadata.Default;
    public DocumentSettings GetSettings() => DocumentSettings.Default;

    public void Compose(IDocumentContainer container)
    {
        var totalLineValue = _po.Lines.Sum(l => l.Value);
        var totalDiscount = _po.Lines.Sum(l => l.LineDisAmt);
        var totalCgst = _po.Lines.Sum(l => l.CgstAmt);
        var totalSgst = _po.Lines.Sum(l => l.SgstAmt);
        var totalIgst = _po.Lines.Sum(l => l.IgstAmt);
        var totalTcs = _po.Lines.Sum(l => l.TcsAmt);

        var isIntraState = !string.IsNullOrWhiteSpace(_po.DivStateCode)
                           && _po.DivStateCode == _po.SlStateCode;
        var grandTotal = totalLineValue - totalDiscount
            + (isIntraState ? totalCgst + totalSgst : totalIgst)
            + _po.FreightAmt + _po.InsAmt + _po.PackAmt + _po.OtherCharges
            + totalTcs + _po.RoundOff;

        var companyName = string.IsNullOrWhiteSpace(_po.DivPrintName) ? _po.DivName : _po.DivPrintName;

        container.Page(page =>
        {
            page.Size(PageSizes.A4);
            page.MarginHorizontal(Margin, Unit.Millimetre);
            page.MarginVertical(Margin, Unit.Millimetre);
            page.DefaultTextStyle(x => x.FontFamily(Font).FontSize(FsData).FontColor(Black));

            page.Header().Element(c => ComposeLetterhead(c, companyName));

            page.Content().Column(col =>
            {
                col.Spacing(0);

                col.Item().Border(BdCell).BorderColor(Black)
                   .Element(c => ComposeVendorAndPoDetails(c));

                col.Item()
                   .Border(BdCell).BorderColor(Black).BorderTop(0)
                   .Padding(2)
                   .Text(t =>
                   {
                       t.AlignCenter();
                       t.Span("Please supply us the following materials as per the terms below and subject to our general conditions of purchase.")
                        .FontSize(FsSmall).Italic();
                   });

                col.Item().Element(c => ComposeItemsTable(c));

                col.Item().Border(BdCell).BorderColor(Black).BorderTop(0)
                   .Element(c => ComposeFooter(c, totalLineValue, totalDiscount, totalCgst, totalSgst, totalIgst, totalTcs, grandTotal, isIntraState));

                col.Item()
                   .Border(BdCell).BorderColor(Black).BorderTop(0)
                   .PaddingVertical(3).PaddingHorizontal(4)
                   .Text(t =>
                   {
                       t.AlignLeft();
                       t.Span("Total PO Value(In Words) : ").Bold().FontSize(FsData);
                       t.Span(AmountToWords.Convert(grandTotal)).FontSize(FsData);
                   });

                col.Item().Element(c => ComposeSignature(c, companyName));

                col.Item()
                   .PaddingTop(3).PaddingBottom(1)
                   .Text(t =>
                   {
                       t.AlignCenter();
                       t.Span("\"We Prefer ECO Friendly Practices and Packages\"")
                        .FontSize(FsSmall).Italic().FontColor(Black);
                   });
            });
        });
    }

    private void ComposeLetterhead(IContainer c, string companyName)
    {
        c.Border(BdBox).BorderColor(Black)
         .PaddingVertical(4).PaddingHorizontal(6)
         .Row(row =>
         {
             row.ConstantItem(45, Unit.Millimetre)
                .AlignMiddle()
                .Element(logoC =>
                {
                    if (_po.DivLogo is { Length: > 0 })
                        logoC.MaxHeight(28, Unit.Millimetre).Image(_po.DivLogo).FitHeight();
                    else
                        logoC.Height(28, Unit.Millimetre);
                });

             row.RelativeItem()
                .PaddingHorizontal(4)
                .AlignMiddle()
                .Column(col =>
                {
                    col.Item().Text(t =>
                    {
                        t.AlignLeft();
                        t.Span(companyName).Bold().FontSize(FsCompany).FontColor(Navy);
                    });

                    if (!string.IsNullOrWhiteSpace(_po.DivUnitName))
                    {
                        var unit = _po.DivUnitName.Trim();
                        var unitText = unit.StartsWith("(", StringComparison.Ordinal) ? unit : $"(Unit - {unit})";
                        col.Item().Text(t =>
                        {
                            t.AlignLeft();
                            t.Span(unitText).Bold().FontSize(FsInfo).FontColor(Navy);
                        });
                    }

                    if (!string.IsNullOrWhiteSpace(_po.DivAddress1))
                        col.Item().Text(t => { t.AlignLeft(); t.Span(_po.DivAddress1).FontSize(FsSmall); });

                    if (!string.IsNullOrWhiteSpace(_po.DivAddress2))
                        col.Item().Text(t => { t.AlignLeft(); t.Span(_po.DivAddress2).FontSize(FsSmall); });

                    if (!string.IsNullOrWhiteSpace(_po.DivAddress3))
                        col.Item().Text(t => { t.AlignLeft(); t.Span(_po.DivAddress3).FontSize(FsSmall); });

                    if (!string.IsNullOrWhiteSpace(_po.DivPinCode))
                        col.Item().Text(t => { t.AlignLeft(); t.Span(_po.DivPinCode).FontSize(FsSmall); });
                });

             row.ConstantItem(58, Unit.Millimetre)
                .AlignMiddle()
                .Column(col =>
                {
                    void RightLine(string label, string val)
                    {
                        if (string.IsNullOrWhiteSpace(val)) return;
                        col.Item().Row(r =>
                        {
                            r.ConstantItem(13, Unit.Millimetre)
                             .Text(t => { t.AlignLeft(); t.Span(label).Bold().FontSize(FsSmall); });
                            r.ConstantItem(3, Unit.Millimetre)
                             .Text(t => { t.AlignLeft(); t.Span(":").Bold().FontSize(FsSmall); });
                            r.RelativeItem()
                             .Text(t => { t.AlignLeft(); t.Span(val).FontSize(FsSmall); });
                        });
                    }

                    RightLine("GSTIN", _po.DivGstin);
                    RightLine("PAN", _po.DivPan);
                    RightLine("E-mail", _po.DivEmail);
                    RightLine("Web", _po.DivWeb);
                    RightLine("Phone", _po.DivPhone);
                });
         });
    }

    private void ComposeVendorAndPoDetails(IContainer c)
    {
        c.Row(row =>
        {
            row.RelativeItem()
               .BorderRight(BdCell).BorderColor(Black)
               .Padding(4)
               // Layers: PrimaryLayer holds "To :", supplier name, address at the
               // top (and sets the layer's natural size). The overlaid Layer with
               // AlignBottom pins GSTIN/State Code + Phone/Email to the bottom of
               // the row's height (driven by the taller PO-details column on the
               // right). Unlike ExtendVertical, this does not bleed into the page.
               .Layers(layers =>
               {
                   layers.PrimaryLayer().Column(top =>
                   {
                       top.Item().Text(t => { t.Span("To :").Bold().FontSize(FsData); });
                       top.Item().Text(t => { t.Span(_po.SlName).Bold().FontSize(FsInfo); });
                       if (!string.IsNullOrWhiteSpace(_po.SlAddress))
                           top.Item().Text(t => { t.Span(_po.SlAddress).FontSize(FsData); });
                   });

                   layers.Layer().AlignBottom().Column(bottom =>
                   {
                       // Contact rows — each field is a single left-aligned label+value
                       // text anchored to the left edge of its column. So "Phone"/"GSTIN"
                       // start at the same X (left column), and "Email"/"State Code" start
                       // at the same X (right column) — i.e. Email begins exactly where
                       // State Code begins. Label and value are suppressed together when
                       // the value is blank, leaving the column empty (positions stay
                       // fixed; nothing slides into a hidden slot).
                       void ContactPair(IContainer half, string label, string? value)
                       {
                           half.Text(t =>
                           {
                               t.AlignLeft();
                               if (!string.IsNullOrWhiteSpace(value))
                               {
                                   t.Span(label + " ").Bold().FontSize(FsSmall);
                                   t.Span(value).FontSize(FsSmall);
                               }
                           });
                       }

                       void ContactRow(string leftLabel, string? leftValue,
                                       string rightLabel, string? rightValue,
                                       bool padTop)
                       {
                           var hasLeft  = !string.IsNullOrWhiteSpace(leftValue);
                           var hasRight = !string.IsNullOrWhiteSpace(rightValue);
                           if (!hasLeft && !hasRight) return;

                           var item = padTop ? bottom.Item().PaddingTop(1) : bottom.Item();

                           // Fixed two-column layout: the left field sits in a fixed
                           // 38 mm column, the right field takes all remaining width.
                           // Left fields (Phone/GSTIN) are short; the right side holds
                           // the long values (emails ~30+ chars), so giving it the rest
                           // of the row keeps emails on one line. A blank field leaves
                           // its column empty — the populated field never slides over
                           // to fill the gap or jump into the hidden slot.
                           item.Row(r =>
                           {
                               ContactPair(r.ConstantItem(38, Unit.Millimetre), leftLabel,  leftValue);
                               ContactPair(r.RelativeItem(),                    rightLabel, rightValue);
                           });
                       }

                       ContactRow("Phone :", _po.SlPhone, "Email :",      _po.SlEmail,     padTop: false);
                       ContactRow("GSTIN :", _po.SlGstin, "State Code :", _po.SlStateCode, padTop: true);
                   });
               });

            row.ConstantItem(88, Unit.Millimetre)
               .Column(col =>
               {
                   col.Item()
                      .BorderBottom(BdCell).BorderColor(Black)
                      .PaddingVertical(4)
                      .Text(t =>
                      {
                          t.AlignCenter();
                          t.Span("PURCHASE ORDER").Bold().FontSize(12f).FontColor(Black);
                      });

                   void DetailRow(string label, string value)
                   {
                       if (string.IsNullOrWhiteSpace(value)) return;
                       col.Item().PaddingHorizontal(4).PaddingTop(2).Row(r =>
                       {
                           r.ConstantItem(36, Unit.Millimetre)
                            .Text(t => { t.Span(label).Bold().FontSize(FsData); });
                           r.RelativeItem()
                            .Text(t => { t.Span(": " + value).FontSize(FsData); });
                       });
                   }

                   // PO.NO. — rendered larger than the other detail rows so the
                   // order number is the most prominent value in this panel.
                   const float FsPoNo = 12f;
                   col.Item().PaddingHorizontal(4).PaddingTop(2).Row(r =>
                   {
                       r.ConstantItem(36, Unit.Millimetre)
                        .Text(t => { t.Span("PO.NO.").Bold().FontSize(FsPoNo); });
                       r.RelativeItem()
                        .Text(t => { t.Span(": " + ((long)_po.PoNo).ToString()).Bold().FontSize(FsPoNo); });
                   });
                   DetailRow("PO.Date", _po.PoDate.ToString("dd/MM/yy", CultureInfo.InvariantCulture));
                   DetailRow("Currency",
                       _po.Currency == "INR" || string.IsNullOrWhiteSpace(_po.Currency)
                           ? "INR"
                           : _po.CurrRate > 0m
                               ? $"{_po.Currency} @ {F4(_po.CurrRate)}"
                               : _po.Currency);

                   // Always render Ref. No. & Date — print empty value when both fields are blank
                   // rather than hiding the row (DetailRow itself short-circuits on empty value).
                   var refValue =
                       string.IsNullOrWhiteSpace(_po.RefNo) && string.IsNullOrWhiteSpace(_po.RefDate)
                           ? ""
                           : !string.IsNullOrWhiteSpace(_po.RefNo) && !string.IsNullOrWhiteSpace(_po.RefDate)
                               ? $"{_po.RefNo} & {_po.RefDate}"
                               : (_po.RefNo ?? "") + (_po.RefDate ?? "");
                   col.Item().PaddingHorizontal(4).PaddingTop(2).Row(r =>
                   {
                       r.ConstantItem(36, Unit.Millimetre)
                        .Text(t => { t.Span("Ref. No. & Date").Bold().FontSize(FsData); });
                       r.RelativeItem()
                        .Text(t => { t.Span(": " + refValue).FontSize(FsData); });
                   });

                   col.Item()
                      .PaddingTop(3)
                      .BorderTop(BdCell).BorderColor(Black)
                      .PaddingHorizontal(4).PaddingVertical(2)
                      .Text(t =>
                      {
                          t.AlignCenter();
                          t.Span("Please mention our order No. in all your invoices & DCs")
                           .Italic().FontSize(FsSmall);
                      });
               });
        });
    }

    private void ComposeItemsTable(IContainer c)
    {
        c.Border(BdCell).BorderColor(Black).BorderTop(0)
         .Table(table =>
         {
             table.ColumnsDefinition(cols =>
             {
                 // RelativeColumn (not ConstantColumn) so the table fills the full
                 // container width — otherwise the outer Border draws past the last
                 // column, leaving a stray vertical line after "Value (Rs.)".
                 foreach (var w in Cols)
                     cols.RelativeColumn(w);
             });

             table.Header(h =>
             {
                 static IContainer ThStyle(IContainer cell) =>
                     cell.Background(Colors.Grey.Lighten3)
                         .Border(BdCell).BorderColor(Black)
                         .PaddingVertical(2).PaddingHorizontal(2);

                 void ThText(string text, bool center = true) =>
                     h.Cell().Element(ThStyle).Text(t =>
                     {
                         if (center) t.AlignCenter(); else t.AlignLeft();
                         t.Span(text).Bold().FontSize(FsData).FontColor(Black);
                     });

                 ThText("S.No");
                 ThText("Item Name", center: false);
                 ThText("HSN Code");
                 ThText("Order\nQuantity");
                 ThText("Unit");
                 ThText("Rate/Unit\n(Rs.)");
                 ThText("Disc\n(%)");
                 ThText("CGST\nRate (%)");
                 ThText("SGST\nRate (%)");
                 ThText("IGST\nRate (%)");
                 ThText("Value\n(Rs.)");
             });

             for (var i = 0; i < _po.Lines.Count; i++)
             {
                 var line = _po.Lines[i];

                 static IContainer CellStyle(IContainer cell, bool last) =>
                     (last ? cell : cell.BorderRight(BdCell).BorderColor(Black))
                         .PaddingVertical(1).PaddingHorizontal(2);

                 void DataCell(string text, bool right = false, bool mono = false, bool last = false)
                 {
                     table.Cell().Element(cell => CellStyle(cell, last)).Text(t =>
                     {
                         if (right) t.AlignRight(); else t.AlignCenter();
                         var span = t.Span(text).FontSize(FsData);
                         if (mono) span.FontFamily("Courier New");
                     });
                 }

                 DataCell((i + 1).ToString());

                 table.Cell().Element(cell => CellStyle(cell, false)).Text(t =>
                 {
                     t.AlignLeft();
                     t.Span(line.ItemName ?? "").FontSize(FsData);
                 });

                 DataCell(line.HsnCode);
                 DataCell(line.Qty == 0m ? "" : F3(line.Qty), right: true);
                 DataCell(line.Uom);
                 DataCell(line.Rate == 0m ? "" : F4(line.Rate), right: true);
                 DataCell(F2(line.LineDis), right: true);
                 // OA-01 (line columns): tax-rate cells always print 0.00 when zero
                 // to match the footer's amount-summary rule — never blank.
                 DataCell(F2(line.CgstPer), right: true);
                 DataCell(F2(line.SgstPer), right: true);
                 DataCell(F2(line.IgstPer), right: true);
                 DataCell(line.Value == 0m ? "" : F2(line.Value), right: true, last: true);
             }

             // Pad up to MinRows so short POs (1-3 lines) don't leave a visible column-rule gap
             // between the last data row and the in-table Total band. The final padding row uses
             // a taller vertical padding to absorb residual page space, so the column rules read
             // as a single continuous box rather than ending short of the Total band.
             const int MinRows = 15;
             var padCount = MinRows - _po.Lines.Count;
             for (var pad = 0; pad < padCount; pad++)
             {
                 var isFiller = pad == padCount - 1;
                 static IContainer PadStyle(IContainer cell, bool last, bool filler) =>
                     (last ? cell : cell.BorderRight(BdCell).BorderColor(Black))
                         .PaddingVertical(filler ? 6 : 3).PaddingHorizontal(2);
                 for (var j = 0; j < Cols.Length; j++)
                     table.Cell().Element(cell => PadStyle(cell, j == Cols.Length - 1, isFiller)).Text("");
             }

             static IContainer TotStyle(IContainer cell) =>
                 cell.BorderTop(BdCell).BorderBottom(BdCell).BorderColor(Black)
                     .Background(Colors.Grey.Lighten4)
                     .PaddingVertical(2).PaddingHorizontal(2);

             table.Cell().ColumnSpan(3).Element(TotStyle)
                  .Text(t => { t.AlignRight(); t.Span("Total").Bold().FontSize(FsData); });

             table.Cell().Element(TotStyle)
                  .Text(t => { t.AlignRight(); t.Span(F3(_po.Lines.Sum(l => l.Qty))).Bold().FontSize(FsData); });

             table.Cell().ColumnSpan(2).Element(TotStyle);
             table.Cell().Element(TotStyle);
             table.Cell().ColumnSpan(3).Element(TotStyle);

             table.Cell().Element(TotStyle)
                  .Text(t => { t.AlignRight(); t.Span(F2(_po.Lines.Sum(l => l.Value))).Bold().FontSize(FsData).FontColor(Black); });
         });
    }

    private void ComposeFooter(
        IContainer c,
        decimal totalLineValue, decimal totalDiscount,
        decimal totalCgst, decimal totalSgst, decimal totalIgst, decimal totalTcs,
        decimal grandTotal, bool isIntraState)
    {
        c.Row(row =>
        {
            row.RelativeItem()
               .BorderRight(BdCell).BorderColor(Black)
               .Padding(4)
               .Column(col =>
               {
                   void TermRow(string label, string value)
                   {
                       if (string.IsNullOrWhiteSpace(value)) return;
                       col.Item().PaddingBottom(1).Row(r =>
                       {
                           r.ConstantItem(34, Unit.Millimetre)
                            .Text(t => { t.Span(label).Bold().FontSize(FsData); });
                           r.RelativeItem()
                            .Text(t => { t.Span(": " + value).FontSize(FsData); });
                       });
                   }

                   col.Item().PaddingBottom(1).Row(r =>
                   {
                       r.ConstantItem(34, Unit.Millimetre)
                        .Text(t => { t.Span("Payment Terms").Bold().FontSize(FsData); });
                       r.RelativeItem()
                        .Text(t => { t.Span(": " + (_po.PayTerms ?? "")).FontSize(FsData); });
                   });

                   TermRow("Delivery Date", _po.DeliveryDate);
                   TermRow("Transport", _po.Carrier);
                   TermRow("Purpose", _po.Purpose);

                   col.Item().PaddingBottom(1).Row(r =>
                   {
                       r.ConstantItem(34, Unit.Millimetre)
                        .Text(t => { t.Span("Remarks").Bold().FontSize(FsData); });
                       r.RelativeItem()
                        .Text(t => { t.Span(": " + (_po.Remarks ?? "")).FontSize(FsData); });
                   });

                   var addrParts = new[] { _po.DivAddress1, _po.DivAddress2, _po.DivAddress3 }
                       .Where(s => !string.IsNullOrWhiteSpace(s)).ToList();
                   if (!string.IsNullOrWhiteSpace(_po.DivPinCode)) addrParts.Add(_po.DivPinCode);
                   var deliveryAddr = string.Join(" ", addrParts);

                   col.Item().PaddingTop(2).PaddingBottom(1).Row(r =>
                   {
                       r.ConstantItem(34, Unit.Millimetre)
                        .Text(t => { t.Span("Delivery Address").Bold().FontSize(FsData); });
                       r.RelativeItem()
                        .Text(t => { t.Span(": " + deliveryAddr).FontSize(FsData); });
                   });

                   col.Item().PaddingTop(2).Text(t =>
                   {
                       t.Span("GSTIN : ").Bold().FontSize(FsSmall);
                       t.Span(_po.DivGstin).FontSize(FsSmall);
                       t.Span("    State Code : ").Bold().FontSize(FsSmall);
                       t.Span(_po.DivStateCode).FontSize(FsSmall);
                   });
               });

            row.ConstantItem(83, Unit.Millimetre)
               .Column(col =>
               {
                   void AmtRow(string label, string value, bool bold = false, bool topBorder = false)
                   {
                       var item = col.Item();
                       if (topBorder) item = item.BorderTop(BdCell).BorderColor(Black);
                       item.Row(r =>
                          {
                              r.RelativeItem()
                               .PaddingLeft(4).PaddingVertical(1)
                               .Text(t =>
                               {
                                   if (bold) t.Span(label).Bold().FontSize(FsData);
                                   else t.Span(label).FontSize(FsData);
                               });
                              r.ConstantItem(36, Unit.Millimetre)
                               .BorderLeft(BdCell).BorderColor(Black)
                               .PaddingRight(4).PaddingVertical(1)
                               .Text(t =>
                               {
                                   t.AlignRight();
                                   if (bold) t.Span(value).Bold().FontSize(FsData);
                                   else t.Span(value).FontSize(FsData);
                               });
                          });
                   }

                   AmtRow("Total", F2(totalLineValue));
                   // OA-01: charge rows always show 0.00 when zero — never blank.
                   // A blank field on a printed PO can be misread as "not calculated"
                   // rather than "zero". Tax rows (CGST/SGST/IGST) remain conditional
                   // because GST routing intentionally hides the non-applicable side.
                   AmtRow("Discount", F2(totalDiscount));
                   // OA-01 extension: all three tax rows are always rendered, with
                   // 0.00 substituted for the non-applicable side. GST routing is
                   // still authoritative for the grand-total calculation above —
                   // only the display has changed so no field on the printed PO
                   // can be misread as "not calculated".
                   AmtRow("CGST", F2(totalCgst));
                   AmtRow("SGST", F2(totalSgst));
                   AmtRow("IGST", F2(totalIgst));
                   AmtRow("Freight", F2(_po.FreightAmt));
                   AmtRow("Insurance Amt.", F2(_po.InsAmt));
                   AmtRow("Packing & Forwarding", F2(_po.PackAmt));
                   AmtRow("Other Charges", F2(_po.OtherCharges));
                   var tcsPer = _po.Lines.FirstOrDefault(l => l.TcsPer != 0m)?.TcsPer ?? 0m;
                   AmtRow($"TCS {F3(tcsPer)}%", F2(totalTcs));
                   AmtRow("Round off", F2(_po.RoundOff));
                   // Currency prefix sourced from PO_ORDH.CurrCode (SP alias: Currency).
                   // Falls back to "INR" when blank so the line never prints just a bare amount.
                   var totalCurr = string.IsNullOrWhiteSpace(_po.Currency) ? "INR" : _po.Currency;
                   AmtRow("Total Amount", $"{totalCurr}  {F2(grandTotal)}", bold: true, topBorder: true);
               });
        });
    }

    // Extracts a renderable image from a possibly OLE-wrapped legacy binary (e.g. an
    // Access/VB6 "image" column). Scans the first bytes for a known image header and
    // strips any wrapper; returns null when nothing renderable is found so QuestPDF
    // never throws on bad bytes.
    private static byte[]? ExtractImageBytes(byte[]? raw)
    {
        if (raw is null || raw.Length < 4) return null;

        static bool At(byte[] b, int i, params byte[] sig)
        {
            if (i + sig.Length > b.Length) return false;
            for (var k = 0; k < sig.Length; k++)
                if (b[i + k] != sig[k]) return false;
            return true;
        }

        // BMP only at offset 0 (its 2-byte signature is too weak to scan for safely).
        if (At(raw, 0, 0x42, 0x4D)) return raw;

        var limit = Math.Min(raw.Length - 4, 512);
        for (var i = 0; i <= limit; i++)
        {
            if (At(raw, i, 0xFF, 0xD8, 0xFF) ||             // JPEG
                At(raw, i, 0x89, 0x50, 0x4E, 0x47) ||       // PNG
                At(raw, i, 0x47, 0x49, 0x46, 0x38))         // GIF
            {
                if (i == 0) return raw;
                var clean = new byte[raw.Length - i];
                Array.Copy(raw, i, clean, 0, clean.Length);
                return clean;
            }
        }
        return null;
    }

    private void ComposeSignature(IContainer c, string companyName)
    {
        c.Border(BdCell).BorderColor(Black).BorderTop(0)
         .MinHeight(26, Unit.Millimetre)
         .Padding(4)
         .Column(col =>
         {
             // "For {Company}" — top right
             col.Item().AlignRight().Text(t =>
             {
                 t.Span($"For {companyName}").Bold().FontSize(FsData).FontColor(Black);
             });

             // Authorised-signatory signature (PO_ParaPOApproval.SIGNATURE → FinalAppSign).
             // Replaces the old company-logo stamp. Bytes are validated/cleaned because the
             // legacy column can be OLE-wrapped; unrecognised bytes render nothing so a bad
             // image never crashes the whole PDF. Blank box on an unapproved PO (matches legacy).
             var authSign = ExtractImageBytes(_po.AuthorisedSign);
             if (authSign is not null)
                 col.Item().AlignRight().PaddingTop(2)
                    .MaxHeight(15, Unit.Millimetre)
                    .Image(authSign).FitHeight();

             // Bottom row of signature labels — no vertical dividers
             col.Item().PaddingTop(6).Row(row =>
             {
                 row.RelativeItem().AlignBottom().Column(c2 =>
                 {
                     if (!string.IsNullOrWhiteSpace(_po.CreatedBy))
                         c2.Item().Text(t => { t.AlignLeft(); t.Span(_po.CreatedBy).FontSize(FsData); });
                     // Createddt timestamp under the creator name (legacy parity)
                     if (!string.IsNullOrWhiteSpace(_po.CreatedDt))
                         c2.Item().Text(t => { t.AlignLeft(); t.Span(_po.CreatedDt).FontSize(FsSmall); });
                     c2.Item().Text(t => { t.AlignLeft(); t.Span("Prepared by").Bold().FontSize(FsData); });
                 });
                 row.RelativeItem().AlignBottom().Text(t => { t.AlignCenter(); t.Span("Checked by").Bold().FontSize(FsData); });
                 row.RelativeItem().AlignBottom().Text(t => { t.AlignRight(); t.Span("Authorised Signatory").Bold().FontSize(FsData); });
             });
         });
    }
}
