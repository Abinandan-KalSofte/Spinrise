using System.Globalization;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using Spinrise.Application.Areas.PurchaseOrder.PoEntry.DTOs;
using Spinrise.Shared.Utilities;

namespace Spinrise.API.Areas.PurchaseOrder.Print;

internal sealed class PurchaseOrderDocumentV2 : IDocument
{
    private readonly PoPrintDto _po;

    // ── Page ──────────────────────────────────────────────────────────────────────
    private const float Margin = 6.3f;

    // ── Font ──────────────────────────────────────────────────────────────────────
    private const string Font     = "Calibri";
    private const float FsCompany = 14f;
    private const float FsInfo    = 10f;
    private const float FsData    = 9f;
    private const float FsSmall   = 8f;

    // ── Colours ───────────────────────────────────────────────────────────────────
    private const string Navy  = "#185FA5";
    private const string Black = "#000000";

    // ── Borders ───────────────────────────────────────────────────────────────────
    private const float BdBox  = 1.0f;
    private const float BdCell = 0.5f;

    // ── Column widths (mm) — 11 cols ─────────────────────────────────────────────
    private static readonly float[] Cols = { 8f, 54f, 17f, 16f, 11f, 19f, 11f, 13f, 13f, 13f, 18f };

    // ── Indian number format ──────────────────────────────────────────────────────
    private static readonly NumberFormatInfo InFmt = new()
    {
        NumberGroupSizes       = new[] { 3, 2 },
        NumberGroupSeparator   = ",",
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
        var totalDiscount  = _po.Lines.Sum(l => l.LineDisAmt);
        var totalCgst      = _po.Lines.Sum(l => l.CgstAmt);
        var totalSgst      = _po.Lines.Sum(l => l.SgstAmt);
        var totalIgst      = _po.Lines.Sum(l => l.IgstAmt);
        var totalTcs       = _po.Lines.Sum(l => l.TcsAmt);

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

                // Vendor + PO details
                col.Item().Border(BdCell).BorderColor(Black)
                   .Element(c => ComposeVendorAndPoDetails(c));

                // D-01: updated instruction line text
                col.Item()
                   .Border(BdCell).BorderColor(Black).BorderTop(0)
                   .Padding(2)
                   .Text(t =>
                   {
                       t.AlignCenter();
                       t.Span("Please supply us the following materials as per the terms below and subject to our general conditions of purchase.")
                        .FontSize(FsSmall).Italic();
                   });

                // Items table
                col.Item().Element(c => ComposeItemsTable(c));

                // Footer (terms left + amounts right)
                col.Item().Border(BdCell).BorderColor(Black).BorderTop(0)
                   .Element(c => ComposeFooter(c, totalLineValue, totalDiscount, totalCgst, totalSgst, totalIgst, totalTcs));

                // H-01: "Total PO Value(In Words)"
                col.Item()
                   .Border(BdCell).BorderColor(Black).BorderTop(0)
                   .PaddingVertical(3).PaddingHorizontal(4)
                   .Text(t =>
                   {
                       t.AlignLeft();
                       t.Span("Total PO Value(In Words) : ").Bold().FontSize(FsData);
                       t.Span(AmountToWords.Convert(_po.OrderValue)).FontSize(FsData);
                   });

                // I-01: GSTIN strip REMOVED — GSTIN now in footer left (G-03)

                // Signature block
                col.Item().Element(c => ComposeSignature(c, companyName));

                // K-01: tagline with quotes, Black colour
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

    // ── Letterhead ────────────────────────────────────────────────────────────────

    private void ComposeLetterhead(IContainer c, string companyName)
    {
        c.Border(BdBox).BorderColor(Black)
         .Background(Colors.Grey.Lighten3)           // A-01: gray header background
         .PaddingVertical(4).PaddingHorizontal(6)
         .Row(row =>
         {
             // Logo
             row.ConstantItem(45, Unit.Millimetre)
                .AlignMiddle()
                .Element(logoC =>
                {
                    if (_po.DivLogo is { Length: > 0 })
                        logoC.MaxHeight(28, Unit.Millimetre).Image(_po.DivLogo);
                    else
                        logoC.Height(28, Unit.Millimetre);
                });

             // Company name + address (centre column)
             row.RelativeItem()
                .PaddingHorizontal(4)
                .AlignMiddle()
                .Column(col =>
                {
                    col.Item().Text(t =>
                    {
                        t.AlignCenter();
                        // A-02: Black (not Navy)
                        t.Span(companyName).Bold().FontSize(FsCompany).FontColor(Black);
                    });

                    // A-03: Unit name subtitle
                    if (!string.IsNullOrWhiteSpace(_po.DivUnitName))
                        col.Item().Text(t =>
                        {
                            t.AlignCenter();
                            t.Span($"(Unit - {_po.DivUnitName})").Bold().FontSize(FsInfo).FontColor(Black);
                        });

                    var addr = string.Join(", ", new[]
                    {
                        _po.DivAddress1, _po.DivAddress2, _po.DivAddress3
                    }.Where(s => !string.IsNullOrWhiteSpace(s)));

                    if (!string.IsNullOrWhiteSpace(addr))
                        col.Item().Text(t => { t.AlignCenter(); t.Span(addr).FontSize(FsSmall); });

                    if (!string.IsNullOrWhiteSpace(_po.DivPinCode))
                        col.Item().Text(t => { t.AlignCenter(); t.Span($"Pin: {_po.DivPinCode}").FontSize(FsSmall); });
                });

             // Right panel: GSTIN / Phone / Email
             row.ConstantItem(52, Unit.Millimetre)
                .AlignMiddle()
                .Column(col =>
                {
                    void RightLine(string label, string val)
                    {
                        if (string.IsNullOrWhiteSpace(val)) return;
                        col.Item().Text(t =>
                        {
                            t.AlignRight();
                            t.Span($"{label}: ").Bold().FontSize(FsSmall);
                            t.Span(val).FontSize(FsSmall);
                        });
                    }

                    RightLine("GSTIN", _po.DivGstin);
                    RightLine("PAN",   _po.DivPan);
                    RightLine("E-mail",_po.DivEmail);
                    RightLine("Web",   _po.DivWeb);
                    RightLine("Phone", _po.DivPhone);
                });
         });
    }

    // ── Vendor + PO details ───────────────────────────────────────────────────────

    private void ComposeVendorAndPoDetails(IContainer c)
    {
        c.Row(row =>
        {
            // "To:" vendor block
            row.RelativeItem()
               .BorderRight(BdCell).BorderColor(Black)
               .Padding(4)
               .Column(col =>
               {
                   // B-01: "To :" not "To,"
                   col.Item().Text(t => { t.Span("To :").Bold().FontSize(FsData); });

                   col.Item().Text(t => { t.Span(_po.SlName).Bold().FontSize(FsInfo); });

                   if (!string.IsNullOrWhiteSpace(_po.SlAddress))
                       col.Item().Text(t => { t.Span(_po.SlAddress).FontSize(FsData); });

                   // GSTIN + State Code on same row — always shown
                   col.Item().PaddingTop(2).Row(r =>
                   {
                       r.RelativeItem()
                        .Text(t =>
                        {
                            t.Span("GSTIN : ").Bold().FontSize(FsData);
                            t.Span(_po.SlGstin ?? "").FontSize(FsData);
                        });
                       r.ConstantItem(30, Unit.Millimetre)
                        .Text(t =>
                        {
                            t.Span("State Code : ").Bold().FontSize(FsData);
                            t.Span(_po.SlStateCode ?? "").FontSize(FsData);
                        });
                   });

                   // Phone + Email on same row — always shown
                   col.Item().PaddingTop(1).Row(r =>
                   {
                       r.RelativeItem()
                        .Text(t =>
                        {
                            t.Span("Phone : ").Bold().FontSize(FsSmall);
                            t.Span(_po.SlPhone ?? "").FontSize(FsSmall);
                        });
                       r.RelativeItem()
                        .Text(t =>
                        {
                            t.Span("Email : ").Bold().FontSize(FsSmall);
                            t.Span(_po.SlEmail ?? "").FontSize(FsSmall);
                        });
                   });
               });

            // PO details (right panel)
            row.ConstantItem(88, Unit.Millimetre)
               .Column(col =>
               {
                   // C-01: "PURCHASE ORDER" in Black (not Navy)
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

                   // C-03: "PO.NO."  C-02+C-04: date dd/MM/yy (short year, slash separator)
                   DetailRow("PO.NO.",          ((long)_po.PoNo).ToString());
                   DetailRow("PO.Date",         _po.PoDate.ToString("dd/MM/yy", CultureInfo.InvariantCulture));
                   DetailRow("Currency",        _po.Currency == "INR" || string.IsNullOrWhiteSpace(_po.Currency)
                                                    ? "INR"
                                                    : $"{_po.Currency} @ {F4(_po.CurrRate)}");

                   // C-05: Ref No. & Date combined on one row
                   if (!string.IsNullOrWhiteSpace(_po.RefNo) || !string.IsNullOrWhiteSpace(_po.RefDate))
                       DetailRow("Ref. No. & Date", $"{_po.RefNo} & {_po.RefDate}");

                   // C-06: Order Type, Pay Mode, Credit Days, Pay Terms, Delivery Date, Carrier — REMOVED

                   // C-07: italic note below detail rows
                   col.Item()
                      .PaddingHorizontal(4).PaddingTop(3)
                      .Text(t =>
                      {
                          t.AlignCenter();
                          t.Span("Please mention our order No. in all your invoices & DCs")
                           .Italic().FontSize(FsSmall);
                      });
               });
        });
    }

    // ── Items table ───────────────────────────────────────────────────────────────

    private void ComposeItemsTable(IContainer c)
    {
        c.Border(BdCell).BorderColor(Black).BorderTop(0)
         .Table(table =>
         {
             table.ColumnsDefinition(cols =>
             {
                 foreach (var w in Cols)
                     cols.ConstantColumn(w, Unit.Millimetre);
             });

             table.Header(h =>
             {
                 static IContainer ThStyle(IContainer cell) =>
                     cell.Border(BdCell).BorderColor(Black)
                         .Background(Colors.Grey.Lighten3)
                         .PaddingVertical(2).PaddingHorizontal(2);

                 void ThText(string text, bool center = true) =>
                     h.Cell().Element(ThStyle).Text(t =>
                     {
                         if (center) t.AlignCenter(); else t.AlignLeft();
                         t.Span(text).Bold().FontSize(FsData).FontColor(Black);
                     });

                 ThText("S.No");
                 ThText("Item Name",       center: false);  // E-01
                 ThText("HSN Code");
                 ThText("Order\nQuantity");                  // E-02
                 ThText("Unit");
                 ThText("Rate/Unit\n(Rs.)");
                 ThText("Disc\n(%)");
                 ThText("CGST\nRate (%)");
                 ThText("SGST\nRate (%)");
                 ThText("IGST\nRate (%)");
                 ThText("Value\n(Rs.)");
             });

             // Data rows
             for (var i = 0; i < _po.Lines.Count; i++)
             {
                 var line = _po.Lines[i];

                 static IContainer CellStyle(IContainer cell) =>
                     cell.BorderBottom(BdCell).BorderColor(Black)
                         .PaddingVertical(1).PaddingHorizontal(2);

                 void DataCell(string text, bool right = false, bool mono = false)
                 {
                     table.Cell().Element(CellStyle).Text(t =>
                     {
                         if (right) t.AlignRight(); else t.AlignCenter();
                         var span = t.Span(text).FontSize(FsData);
                         if (mono) span.FontFamily("Courier New");
                     });
                 }

                 DataCell((i + 1).ToString());

                 table.Cell().Element(CellStyle).Column(col =>
                 {
                     col.Item().Text(t =>
                     {
                         t.AlignLeft();
                         t.Span(line.ItemCode).FontFamily("Courier New").FontSize(FsData);
                     });
                     col.Item().Text(t =>
                     {
                         t.AlignLeft();
                         t.Span(line.ItemName).FontSize(FsData);
                     });
                 });

                 DataCell(line.HsnCode);
                 DataCell(line.Qty  == 0m ? "" : F3(line.Qty),  right: true);
                 DataCell(line.Uom);
                 DataCell(line.Rate == 0m ? "" : F4(line.Rate), right: true);
                 DataCell(F2(line.LineDis), right: true);              // E-03: always show Disc
                 DataCell(line.CgstPer == 0m ? "" : F2(line.CgstPer), right: true);
                 DataCell(line.SgstPer == 0m ? "" : F2(line.SgstPer), right: true);
                 DataCell(line.IgstPer == 0m ? "" : F2(line.IgstPer), right: true);
                 DataCell(line.Value   == 0m ? "" : F2(line.Value),    right: true);
             }

             // L-04: pad with empty rows so table always fills ~60% of page body
             const int MinRows = 8;
             for (var pad = _po.Lines.Count; pad < MinRows; pad++)
             {
                 static IContainer PadStyle(IContainer cell) =>
                     cell.BorderBottom(BdCell).BorderColor(Black)
                         .PaddingVertical(3).PaddingHorizontal(2);
                 for (var j = 0; j < Cols.Length; j++)
                     table.Cell().Element(PadStyle).Text("");
             }

             // Totals row
             static IContainer TotStyle(IContainer cell) =>
                 cell.BorderTop(BdCell).BorderBottom(BdCell).BorderColor(Black)
                     .Background(Colors.Grey.Lighten4)
                     .PaddingVertical(2).PaddingHorizontal(2);

             table.Cell().ColumnSpan(3).Element(TotStyle)
                  .Text(t => { t.AlignRight(); t.Span("Total").Bold().FontSize(FsData); });

             table.Cell().Element(TotStyle)
                  .Text(t => { t.AlignRight(); t.Span(F3(_po.Lines.Sum(l => l.Qty))).Bold().FontSize(FsData); });

             table.Cell().ColumnSpan(2).Element(TotStyle);  // Unit + Rate blank
             table.Cell().Element(TotStyle);                 // Disc% blank
             table.Cell().ColumnSpan(3).Element(TotStyle);  // GST% blank

             table.Cell().Element(TotStyle)
                  .Text(t => { t.AlignRight(); t.Span(F2(_po.Lines.Sum(l => l.Value))).Bold().FontSize(FsData).FontColor(Navy); });
         });
    }

    // ── Two-column footer ─────────────────────────────────────────────────────────

    private void ComposeFooter(
        IContainer c,
        decimal totalLineValue, decimal totalDiscount,
        decimal totalCgst, decimal totalSgst, decimal totalIgst, decimal totalTcs)
    {
        c.Row(row =>
        {
            // Left: Terms + address + GSTIN
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

                   // G-01: Payment Terms always shown even when blank
                   col.Item().PaddingBottom(1).Row(r =>
                   {
                       r.ConstantItem(34, Unit.Millimetre)
                        .Text(t => { t.Span("Payment Terms").Bold().FontSize(FsData); });
                       r.RelativeItem()
                        .Text(t => { t.Span(": " + (_po.PayTerms ?? "")).FontSize(FsData); });
                   });

                   TermRow("Delivery Date", _po.DeliveryDate);
                   TermRow("Transport",     _po.Carrier);
                   TermRow("Purpose",       _po.Purpose);
                   // Remarks always shown even when blank
                   col.Item().PaddingBottom(1).Row(r =>
                   {
                       r.ConstantItem(34, Unit.Millimetre)
                        .Text(t => { t.Span("Remarks").Bold().FontSize(FsData); });
                       r.RelativeItem()
                        .Text(t => { t.Span(": " + (_po.Remarks ?? "")).FontSize(FsData); });
                   });

                   // G-02: Delivery Address from company div fields
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

                   // G-03: GSTIN + State Code
                   col.Item().PaddingTop(2).Text(t =>
                   {
                       t.Span("GSTIN : ").Bold().FontSize(FsSmall);
                       t.Span(_po.DivGstin).FontSize(FsSmall);
                       t.Span("    State Code : ").Bold().FontSize(FsSmall);
                       t.Span(_po.DivStateCode).FontSize(FsSmall);
                   });
               });

            // Right: Financial summary
            row.ConstantItem(83, Unit.Millimetre)
               .Column(col =>
               {
                   void AmtRow(string label, string value, bool bold = false)
                   {
                       col.Item()
                          .BorderBottom(BdCell).BorderColor(Black)
                          .Row(r =>
                          {
                              r.RelativeItem()
                               .PaddingLeft(4).PaddingVertical(1)
                               .Text(t =>
                               {
                                   if (bold) t.Span(label).Bold().FontSize(FsData);
                                   else      t.Span(label).FontSize(FsData);
                               });
                              r.ConstantItem(36, Unit.Millimetre)
                               .BorderLeft(BdCell).BorderColor(Black)
                               .PaddingRight(4).PaddingVertical(1)
                               .Text(t =>
                               {
                                   t.AlignRight();
                                   if (bold) t.Span(value).Bold().FontSize(FsData);
                                   else      t.Span(value).FontSize(FsData);
                               });
                          });
                   }

                   AmtRow("Total",                   F2(totalLineValue));
                   AmtRow("Discount",                totalDiscount == 0m ? "" : F2(totalDiscount)); // F-01: always show
                   if (totalCgst != 0m) AmtRow("CGST", F2(totalCgst));
                   if (totalSgst != 0m) AmtRow("SGST", F2(totalSgst));
                   if (totalIgst != 0m) AmtRow("IGST", F2(totalIgst));
                   AmtRow("Freight",                 _po.FreightAmt == 0m ? "" : F2(_po.FreightAmt)); // F-02: always show
                   AmtRow("Insurance Amt.",          _po.InsAmt     == 0m ? "" : F2(_po.InsAmt));      // F-03: always show
                   AmtRow("Packing & Forwarding",    _po.PackAmt    == 0m ? "" : F2(_po.PackAmt));     // F-04: always show
                   AmtRow("Other Charges",           "");                                               // F-05: always blank
                   var tcsPer = _po.Lines.FirstOrDefault(l => l.TcsPer != 0m)?.TcsPer ?? 0m;
                   AmtRow($"TCS {F3(tcsPer)}%",      F2(totalTcs));                                    // F-06: always show
                   AmtRow("Round off",               F2(_po.RoundOff));                                // F-07: always show
                   AmtRow("Total Amount",            $"INR  {F2(_po.OrderValue)}", bold: true);        // F-08: INR in value
               });
        });
    }

    // ── Signature block ───────────────────────────────────────────────────────────

    private void ComposeSignature(IContainer c, string companyName)
    {
        c.Border(BdCell).BorderColor(Black).BorderTop(0)
         .MinHeight(25, Unit.Millimetre)
         .Row(row =>
         {
             row.ConstantItem(50, Unit.Millimetre)
                .BorderRight(BdCell).BorderColor(Black)
                .Padding(4)
                .Column(col =>
                {
                    col.Item().Text(t =>
                    {
                        t.Span($"For {companyName}").Bold().FontSize(FsData).FontColor(Navy);
                    });
                    if (_po.DivLogo is { Length: > 0 })
                        col.Item().PaddingTop(2).MaxHeight(16, Unit.Millimetre).AlignRight()
                           .Image(_po.DivLogo);
                });

             row.RelativeItem()
                .BorderRight(BdCell).BorderColor(Black)
                .Padding(4)
                .Column(col =>
                {
                    col.Item().Text(t => { t.AlignCenter(); t.Span("Prepared by").Bold().FontSize(FsData); });
                    col.Item().PaddingTop(14).Text(t => { t.AlignCenter(); t.Span(_po.CreatedBy).FontSize(FsData); });
                });

             row.RelativeItem()
                .BorderRight(BdCell).BorderColor(Black)
                .Padding(4)
                .Column(col =>
                {
                    col.Item().Text(t => { t.AlignCenter(); t.Span("Checked by").Bold().FontSize(FsData); });
                });

             row.RelativeItem()
                .Padding(4)
                .Column(col =>
                {
                    col.Item().Text(t => { t.AlignCenter(); t.Span("Authorised Signatory").Bold().FontSize(FsData); });
                });
         });
    }
}
