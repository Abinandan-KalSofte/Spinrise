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
    private const float Margin   = 6.3f;     // mm — all sides
    private const float Inset    = 0f;       // no additional inset; border sits at content edge

    // ── Font ──────────────────────────────────────────────────────────────────────
    private const string Font       = "Calibri";
    private const float FsCompany   = 14f;
    private const float FsInfo      = 10f;
    private const float FsData      = 9f;
    private const float FsSmall     = 8f;

    // ── Colours ───────────────────────────────────────────────────────────────────
    private const string Navy  = "#185FA5";
    private const string Black = "#000000";

    // ── Borders ───────────────────────────────────────────────────────────────────
    private const float BdBox  = 1.0f;
    private const float BdCell = 0.5f;

    // ── Column widths (mm) — 11 cols, Σ ≈ 193 mm ─────────────────────────────────
    //  0=S.No  1=ItemName  2=HSN  3=Qty  4=Unit  5=Rate  6=Disc%
    //  7=CGST%  8=SGST%  9=IGST%  10=Value
    private static readonly float[] Cols = { 8f, 54f, 17f, 16f, 11f, 19f, 11f, 13f, 13f, 13f, 18f };

    // ── Indian number format (lakh grouping) ─────────────────────────────────────
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
        // Compute summary totals
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

                // Vendor + PO details row
                col.Item().Border(BdCell).BorderColor(Black)
                   .Element(c => ComposeVendorAndPoDetails(c));

                // Instruction line
                col.Item()
                   .Border(BdCell).BorderColor(Black)
                   .BorderTop(0)
                   .Padding(2)
                   .Text(t =>
                   {
                       t.AlignCenter();
                       t.Span("Kindly supply the following material as per the terms and conditions mentioned herein.")
                        .FontSize(FsSmall).Italic();
                   });

                // Items table
                col.Item().Element(c => ComposeItemsTable(c));

                // Two-column footer: terms left, amounts right
                col.Item().Border(BdCell).BorderColor(Black).BorderTop(0)
                   .Element(c => ComposeFooter(c, totalLineValue, totalDiscount, totalCgst, totalSgst, totalIgst, totalTcs));

                // Amount in words
                col.Item()
                   .Border(BdCell).BorderColor(Black).BorderTop(0)
                   .PaddingVertical(3).PaddingHorizontal(4)
                   .Text(t =>
                   {
                       t.AlignLeft();
                       t.Span("Amount in Words : ").Bold().FontSize(FsData);
                       t.Span(AmountToWords.Convert(_po.OrderValue)).FontSize(FsData);
                   });

                // GSTIN strip
                col.Item()
                   .Border(BdCell).BorderColor(Black).BorderTop(0)
                   .PaddingVertical(2).PaddingHorizontal(4)
                   .Text(t =>
                   {
                       t.AlignCenter();
                       t.Span($"Company GSTIN : {_po.DivGstin}").Bold().FontSize(FsSmall).FontColor(Navy);
                       if (!string.IsNullOrWhiteSpace(_po.SlGstin))
                           t.Span($"     |     Supplier GSTIN : {_po.SlGstin}").Bold().FontSize(FsSmall).FontColor(Navy);
                   });

                // Signature block
                col.Item().Element(c => ComposeSignature(c, companyName));

                // Tagline
                col.Item()
                   .PaddingTop(3).PaddingBottom(1)
                   .Text(t =>
                   {
                       t.AlignCenter();
                       t.Span("We Prefer ECO Friendly Practices and Packages")
                        .FontSize(FsSmall).Italic().FontColor(Navy);
                   });
            });
        });
    }

    // ── Letterhead (page header) ──────────────────────────────────────────────────

    private void ComposeLetterhead(IContainer c, string companyName)
    {
        c.Border(BdBox).BorderColor(Black)
         .PaddingVertical(4).PaddingHorizontal(6)
         .Row(row =>
         {
             // Logo column
             row.ConstantItem(45, Unit.Millimetre)
                .AlignMiddle()
                .Element(logoC =>
                {
                    if (_po.DivLogo is { Length: > 0 })
                        logoC.MaxHeight(28, Unit.Millimetre).Image(_po.DivLogo);
                    else
                        logoC.Height(28, Unit.Millimetre);
                });

             // Company name + address
             row.RelativeItem()
                .PaddingHorizontal(4)
                .AlignMiddle()
                .Column(col =>
                {
                    col.Item().Text(t =>
                    {
                        t.AlignCenter();
                        t.Span(companyName).Bold().FontSize(FsCompany).FontColor(Navy);
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

                    RightLine("GSTIN",  _po.DivGstin);
                    RightLine("Phone",  _po.DivPhone);
                    RightLine("Email",  _po.DivEmail);
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
                   col.Item().Text(t =>
                   {
                       t.Span("To,").Bold().FontSize(FsData);
                   });

                   col.Item().Text(t =>
                   {
                       t.Span(_po.SlName).Bold().FontSize(FsInfo);
                   });

                   if (!string.IsNullOrWhiteSpace(_po.SlAddress))
                       col.Item().Text(t => { t.Span(_po.SlAddress).FontSize(FsData); });

                   if (!string.IsNullOrWhiteSpace(_po.SlGstin))
                       col.Item().Text(t =>
                       {
                           t.Span("GSTIN: ").Bold().FontSize(FsData);
                           t.Span(_po.SlGstin).FontSize(FsData);
                       });
               });

            // PO details (right side)
            row.ConstantItem(88, Unit.Millimetre)
               .Column(col =>
               {
                   // "PURCHASE ORDER" centred title at top of this column
                   col.Item()
                      .BorderBottom(BdCell).BorderColor(Black)
                      .PaddingVertical(4)
                      .Text(t =>
                      {
                          t.AlignCenter();
                          t.Span("PURCHASE ORDER").Bold().FontSize(12f).FontColor(Navy);
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

                   DetailRow("PO No.",       ((long)_po.PoNo).ToString());
                   DetailRow("PO Date",       _po.PoDate.ToString("dd/MM/yyyy"));
                   DetailRow("Ref No.",       _po.RefNo);
                   DetailRow("Ref Date",      _po.RefDate);
                   DetailRow("Order Type",    _po.OrderType);
                   DetailRow("Currency",      _po.Currency == "INR" || string.IsNullOrWhiteSpace(_po.Currency)
                                                  ? "INR"
                                                  : $"{_po.Currency} @ {F4(_po.CurrRate)}");
                   DetailRow("Pay Mode",      _po.PayMode);
                   DetailRow("Credit Days",   _po.CreditDays > 0 ? _po.CreditDays.ToString() : "");
                   DetailRow("Pay Terms",     _po.PayTerms);
                   DetailRow("Delivery Date", _po.DeliveryDate);
                   DetailRow("Carrier",       _po.Carrier);
               });
        });
    }

    // ── Items table ───────────────────────────────────────────────────────────────

    private void ComposeItemsTable(IContainer c)
    {
        c.Border(BdCell).BorderColor(Black).BorderTop(0)
         .Table(table =>
         {
             // Define columns
             table.ColumnsDefinition(cols =>
             {
                 foreach (var w in Cols)
                     cols.ConstantColumn(w, Unit.Millimetre);
             });

             // Header row
             void Th(string text, int? col = null, bool center = true)
             {
                 table.Header(h =>
                 {
                     // We use CellsDefinition instead — see below
                 });
             }

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
                 ThText("Item Description",    center: false);
                 ThText("HSN Code");
                 ThText("Order Qty");
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

                 // Item description cell: code (monospace) + name
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
                 DataCell(line.LineDis == 0m ? "" : F2(line.LineDis), right: true);
                 DataCell(line.CgstPer == 0m ? "" : F2(line.CgstPer), right: true);
                 DataCell(line.SgstPer == 0m ? "" : F2(line.SgstPer), right: true);
                 DataCell(line.IgstPer == 0m ? "" : F2(line.IgstPer), right: true);
                 DataCell(line.Value == 0m ? "" : F2(line.Value), right: true);
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

             table.Cell().ColumnSpan(2).Element(TotStyle);  // Unit + Rate (blank)

             table.Cell().Element(TotStyle);  // Disc% blank

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
            // Left: Terms
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

                   TermRow("Payment Terms",   _po.PayTerms);
                   TermRow("Delivery Date",   _po.DeliveryDate);
                   TermRow("Transport",       _po.Carrier);
                   TermRow("Purpose",         _po.Purpose);
                   TermRow("Remarks",         _po.Remarks);
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
                                   if (bold) t.Span(label).Bold().FontSize(FsData).FontColor(Navy);
                                   else      t.Span(label).FontSize(FsData);
                               });
                              r.ConstantItem(36, Unit.Millimetre)
                               .BorderLeft(BdCell).BorderColor(Black)
                               .PaddingRight(4).PaddingVertical(1)
                               .Text(t =>
                               {
                                   t.AlignRight();
                                   if (bold) t.Span(value).Bold().FontSize(FsData).FontColor(Navy);
                                   else      t.Span(value).FontSize(FsData);
                               });
                          });
                   }

                   AmtRow("Total",                  F2(totalLineValue));
                   if (totalDiscount != 0m)
                       AmtRow("Discount",           F2(totalDiscount));
                   if (totalCgst != 0m)
                       AmtRow("CGST",               F2(totalCgst));
                   if (totalSgst != 0m)
                       AmtRow("SGST",               F2(totalSgst));
                   if (totalIgst != 0m)
                       AmtRow("IGST",               F2(totalIgst));
                   if (_po.FreightAmt != 0m)
                       AmtRow("Freight",            F2(_po.FreightAmt));
                   if (_po.InsAmt != 0m)
                       AmtRow("Insurance Amt.",     F2(_po.InsAmt));
                   if (_po.PackAmt != 0m)
                       AmtRow("Packing & Forwarding", F2(_po.PackAmt));
                   if (totalTcs != 0m)
                   {
                       var tcsLabel = _po.Lines.FirstOrDefault(l => l.TcsPer != 0m) is { } tl
                           ? $"TCS {F3(tl.TcsPer)}%"
                           : "TCS";
                       AmtRow(tcsLabel,             F2(totalTcs));
                   }
                   if (_po.RoundOff != 0m)
                       AmtRow("Round Off",          F2(_po.RoundOff));

                   AmtRow($"Total Amount INR",      F2(_po.OrderValue), bold: true);
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
             // "For <Company>" column
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

             // Prepared by
             row.RelativeItem()
                .BorderRight(BdCell).BorderColor(Black)
                .Padding(4)
                .Column(col =>
                {
                    col.Item().Text(t =>
                    {
                        t.AlignCenter();
                        t.Span("Prepared by").Bold().FontSize(FsData);
                    });
                    col.Item().PaddingTop(14).Text(t =>
                    {
                        t.AlignCenter();
                        t.Span(_po.CreatedBy).FontSize(FsData);
                    });
                });

             // Checked by
             row.RelativeItem()
                .BorderRight(BdCell).BorderColor(Black)
                .Padding(4)
                .Column(col =>
                {
                    col.Item().Text(t =>
                    {
                        t.AlignCenter();
                        t.Span("Checked by").Bold().FontSize(FsData);
                    });
                });

             // Authorised Signatory
             row.RelativeItem()
                .Padding(4)
                .Column(col =>
                {
                    col.Item().Text(t =>
                    {
                        t.AlignCenter();
                        t.Span("Authorised Signatory").Bold().FontSize(FsData);
                    });
                });
         });
    }
}
