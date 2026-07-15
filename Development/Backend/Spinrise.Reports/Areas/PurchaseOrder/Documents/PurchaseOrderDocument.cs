using System.Globalization;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using Spinrise.Application.Areas.PurchaseOrder.PoEntry.DTOs;
using Spinrise.Reports.Core.Engine;

namespace Spinrise.Reports.Areas.PurchaseOrder.Documents;

public sealed class PurchaseOrderDocument : IDocument
{
    private readonly PoPrintDto _po;

    // ── Page ──────────────────────────────────────────────────────────────────────
    private const float PageMargin = 6.3f;
    private const float TableInset = 2.2f;

    // ── Font ──────────────────────────────────────────────────────────────────────
    private const string FontFamily = "Calibri";
    private const float FsCompany  = 14f;
    private const float FsDivision = 9f;
    private const float FsAddress  = 8f;
    private const float FsTitle    = 12f;
    private const float FsInfo     = 10f;
    private const float FsTh       = 10f;
    private const float FsData     = 9f;
    private const float FsSig      = 10f;

    // ── Colours ───────────────────────────────────────────────────────────────────
    private const string Navy  = "#185FA5";
    private const string Black = "#000000";

    // ── Borders (pt) ─────────────────────────────────────────────────────────────
    private const float BdBox  = 1.5f;
    private const float BdCell = 0.5f;
    private const float BdData = 0.67f;

    // ── Column widths (mm) — 16 cols, Σ = 280 mm ─────────────────────────────────
    //  0=S.No  1=ItemCode  2=ItemName  3=UOM  4=HsnCode  5=PR.Ref
    //  6=Qty   7=Rate      8=Value     9=TaxCode  10=Tax%  11=TaxAmt
    //  12=CGST 13=SGST     14=IGST     15=TCS
    private static readonly float[] Cols =
        { 8.0f, 16.0f, 56.0f, 9.0f, 14.0f, 15.0f, 15.0f, 18.0f, 20.0f, 14.0f, 10.0f, 18.0f, 17.0f, 17.0f, 17.0f, 16.0f };

    // ── Info section widths (mm) ──────────────────────────────────────────────────
    private const float LeftPanelW  = 138.0f;
    private const float LeftLabelW  = 34.0f;
    private const float LeftIndent  = 8.0f;
    private const float RightLabelW = 28.0f;
    private const float RightIndent = 10.0f;
    private const float SepW        = 2.0f;

    // ── Row heights (mm) ─────────────────────────────────────────────────────────
    private const float DataRowH = 8.4f;
    private const float SigH     = 22.9f;

    // ── Indian lakh/crore number grouping ────────────────────────────────────────
    private static readonly NumberFormatInfo _inFmt = new()
    {
        NumberGroupSizes       = new[] { 3, 2 },
        NumberGroupSeparator   = ",",
        NumberDecimalSeparator = "."
    };

    public PurchaseOrderDocument(PoPrintDto po) => _po = po;

    public static byte[] Generate(PoPrintDto po) => new PurchaseOrderDocument(po).GeneratePdf();

    public DocumentMetadata GetMetadata() => DocumentMetadata.Default;
    public DocumentSettings GetSettings() => DocumentSettings.Default;

    public void Compose(IDocumentContainer container)
    {
        var totalValue  = _po.Lines.Sum(l => l.Value);
        var totalTaxAmt = _po.Lines.Sum(l => l.TaxAmt);
        var totalCgst   = _po.Lines.Sum(l => l.CgstAmt);
        var totalSgst   = _po.Lines.Sum(l => l.SgstAmt);
        var totalIgst   = _po.Lines.Sum(l => l.IgstAmt);
        var totalTcs    = _po.Lines.Sum(l => l.TcsAmt);

        var printStamp = $"Printed: {DateTime.Now:dd/MM/yyyy  hh:mm tt}";

        container.Page(page =>
        {
            page.Size(PageSizes.A4.Landscape());
            page.MarginHorizontal(PageMargin, Unit.Millimetre);
            page.MarginVertical(PageMargin, Unit.Millimetre);
            page.DefaultTextStyle(x => x.FontFamily(FontFamily).FontSize(FsData).FontColor(Black));

            page.Header().Element(c => QuestPdfTemplateEngine.RenderHeader(c, BuildHeader()));

            page.Content().Column(col =>
            {
                col.Spacing(4);
                col.Item().PaddingTop(3f, Unit.Millimetre)
                   .Element(c => QuestPdfTemplateEngine.RenderInfoSection(c, BuildInfo()));
                col.Item()
                   .PaddingBottom(2)
                   .BorderBottom(1)
                   .BorderColor(Colors.Grey.Darken1)
                   .Element(c => QuestPdfTemplateEngine.RenderTable(c, BuildTable(totalValue, totalTaxAmt, totalCgst, totalSgst, totalIgst, totalTcs)));
                col.Item()
                   .Element(c => RenderFinancialSummary(c));
                col.Item()
                   .Element(c => QuestPdfTemplateEngine.RenderSignature(c, BuildSignature()));
                col.Item()
                   .PaddingHorizontal(TableInset, Unit.Millimetre)
                   .PaddingVertical(2)
                   .Text(t => { t.AlignRight(); t.Span(printStamp).FontSize(FsAddress).FontColor(Black); });
            });
        });
    }

    // ── Config builders ───────────────────────────────────────────────────────────

    private HeaderConfig BuildHeader()
    {
        var name = string.IsNullOrWhiteSpace(_po.DivPrintName) ? _po.DivName : _po.DivPrintName;

        return new HeaderConfig(
            InsetMm:      TableInset,
            PadBottomMm:  1f,
            BorderPt:     BdBox,
            BorderColor:  Black,
            Logo:         new LogoConfig(_po.DivLogo, WidthMm: 51.6f, MaxHeightMm: 28.7f, GapMm: 9.8f),
            CompanyFont:  new StyleFont(FontFamily, FsCompany,  Bold: true, Color: Navy),
            UnitFont:     new StyleFont(FontFamily, FsDivision, Bold: true, Color: Navy),
            AddressFont:  new StyleFont(FontFamily, FsAddress),
            CompanyName:  name,
            UnitName:     "",
            AddressLines: new[]
            {
                $"{_po.DivAddress1}, {_po.DivAddress2}".Trim(' ', ','),
                $"{_po.DivAddress3} - {_po.DivPinCode}".Trim(' ', ',', '-'),
                string.IsNullOrWhiteSpace(_po.DivPhone) ? "" : $"Phone: {_po.DivPhone}",
                string.IsNullOrWhiteSpace(_po.DivEmail) ? "" : $"Email: {_po.DivEmail}",
                string.IsNullOrWhiteSpace(_po.DivGstin) ? "" : $"GSTIN: {_po.DivGstin}",
            });
    }

    private InfoSectionConfig BuildInfo()
    {
        var currDisplay = _po.Currency == "INR" || string.IsNullOrWhiteSpace(_po.Currency)
            ? "INR"
            : $"{_po.Currency} @ {_po.CurrRate:N4}";

        return new InfoSectionConfig(
            InsetMm:     TableInset,
            BorderPt:    BdBox,
            BorderColor: Black,
            Title:       "Purchase Order",
            TitleFont:   new StyleFont(FontFamily, FsTitle, Bold: true, Color: Navy),
            TitlePadVMm: 3f,
            LabelFont:   new StyleFont(FontFamily, FsInfo, Bold: true),
            ValueFont:   new StyleFont(FontFamily, FsInfo, Bold: false),
            DividerMm:   0.53f,
            LeftPanel: new InfoPanelConfig(
                WidthMm: LeftPanelW, IndentMm: LeftIndent, PadVMm: 3f, RowSpacingMm: 3f,
                Rows: new InfoRowConfig[]
                {
                    new("PO No.",        ((long)_po.PoNo).ToString(),        RightLabelW, SepW),
                    new("PO Date",       _po.PoDate.ToString("dd/MM/yyyy"),  RightLabelW, SepW),
                    new("Order Type",    _po.OrderType,                      RightLabelW, SepW),
                    new("Currency",      currDisplay,                        RightLabelW, SepW),
                    new("Credit Days",   _po.CreditDays.ToString(),          RightLabelW, SepW),
                    new("Pay Mode",      _po.PayMode,                        RightLabelW, SepW),
                }),
            RightPanel: new InfoPanelConfig(
                WidthMm: 0, IndentMm: RightIndent, PadVMm: 3f, RowSpacingMm: 3f,
                Rows: new InfoRowConfig[]
                {
                    new("Supplier Code", _po.SlCode,                 LeftLabelW, SepW),
                    new("Supplier Name", _po.SlName,                 LeftLabelW, SepW),
                    new("GSTIN",         _po.SlGstin,                LeftLabelW, SepW),
                    new("Address",       _po.SlAddress,              LeftLabelW, SepW),
                    new("Carrier",       _po.Carrier,                LeftLabelW, SepW),
                    new("Remarks",       _po.Remarks,                LeftLabelW, SepW),
                }));
    }

    private TableConfig BuildTable(
        decimal totalValue, decimal totalTaxAmt,
        decimal totalCgst, decimal totalSgst, decimal totalIgst, decimal totalTcs)
    {
        var emptyMach = new MachCellConfig(MinHeightMm: 0f, BdSidePt: BdData, BdColor: Black);

        var rows = _po.Lines.Select((line, i) =>
        {
            var prRef = line.PrNo > 0 ? $"{(long)line.PrNo}/{(long)line.PrSno}" : "";

            DcCellConfig Dc(string text, DA align) =>
                new(text, align, MinHeightMm: DataRowH, FontSizePt: FsData, BdSidePt: BdData, BdColor: Black);
            DcCellConfig DcMono(string text, DA align) =>
                new(text, align, MinHeightMm: DataRowH, FontSizePt: FsData, BdSidePt: BdData, BdColor: Black, FontFamily: "Courier New");

            DcCellConfig[] cells =
            {
                Dc((i + 1).ToString(),                                                     DA.Center),
                DcMono(line.ItemCode,                                                      DA.Left),
                Dc(line.ItemName,                                                          DA.Left),
                Dc(line.Uom,                                                               DA.Center),
                Dc(line.HsnCode,                                                           DA.Center),
                Dc(prRef,                                                                  DA.Center),
                Dc(line.Qty == 0m  ? "" : line.Qty.ToString("N3", _inFmt),                DA.Right),
                Dc(line.Rate == 0m ? "" : line.Rate.ToString("N4", _inFmt),               DA.Right),
                Dc(line.Value == 0m ? "" : line.Value.ToString("N2", _inFmt),             DA.Right),
                Dc(line.TaxCode,                                                           DA.Center),
                Dc(line.TaxPer == 0m ? "" : line.TaxPer.ToString("N2"),                   DA.Right),
                Dc(line.TaxAmt == 0m ? "" : line.TaxAmt.ToString("N2", _inFmt),           DA.Right),
                Dc(line.CgstAmt == 0m ? "" : line.CgstAmt.ToString("N2", _inFmt),        DA.Right),
                Dc(line.SgstAmt == 0m ? "" : line.SgstAmt.ToString("N2", _inFmt),        DA.Right),
                Dc(line.IgstAmt == 0m ? "" : line.IgstAmt.ToString("N2", _inFmt),        DA.Right),
                Dc(line.TcsAmt == 0m  ? "" : line.TcsAmt.ToString("N2", _inFmt),         DA.Right),
            };

            return new DataRowConfig(cells, Array.Empty<ChildRowConfig>());
        }).ToList();

        static string F2(decimal v) => v == 0m ? "" : v.ToString("N2", _inFmt);

        var totalsRow = new TotalsRowConfig(
            Cells: new TotalsCellConfig[]
            {
                new("Grand Total", DA.Right,  ColumnSpan: 8u, Bold: true, Color: Navy),
                new(F2(totalValue),  DA.Right, Bold: true, Color: Navy),
                new("",              DA.Left,  ColumnSpan: 2u),
                new(F2(totalTaxAmt), DA.Right, Bold: true, Color: Navy),
                new(F2(totalCgst),   DA.Right, Bold: true, Color: Navy),
                new(F2(totalSgst),   DA.Right, Bold: true, Color: Navy),
                new(F2(totalIgst),   DA.Right, Bold: true, Color: Navy),
                new(F2(totalTcs),    DA.Right, Bold: true, Color: Navy),
            },
            MinHeightMm: DataRowH,
            FontSizePt:  FsData,
            BdSidePt:    BdData,
            BdColor:     Black);

        return new TableConfig(
            InsetMm:       TableInset,
            Columns:       Cols.Select(w => new ColDef(w)).ToArray(),
            Header:        BuildTableHeader(),
            EmptyMachCell: emptyMach,
            Rows:          rows,
            TotalsRow:     totalsRow);
    }

    private static TableHeaderConfig BuildTableHeader()
    {
        ThCellConfig Th(string text, int rowSpan, int colSpan = 1, bool topBd = true) => new(
            Text:     text,
            RowSpan:  (uint)rowSpan,
            ColSpan:  (uint)colSpan,
            BdTop:    topBd ? (float?)BdBox : null,
            BdRight:  BdCell,
            BdBottom: rowSpan == 2 ? BdBox : BdCell,
            BdLeft:   BdCell,
            BdColor:  Black);

        ThCellConfig[] cells =
        {
            Th("S.No",           rowSpan: 2),
            Th("Item Code",      rowSpan: 2),
            Th("Item Name",      rowSpan: 2),
            Th("UOM",            rowSpan: 2),
            Th("HSN Code",       rowSpan: 2),
            Th("PR.No/S.No",     rowSpan: 2),
            Th("Qty",            rowSpan: 2),
            Th("Rate",           rowSpan: 2),
            Th("Value",          rowSpan: 2),
            Th("Tax Code",       rowSpan: 2),
            Th("Tax\n%",         rowSpan: 2),

            new ThCellConfig("Tax Details", RowSpan: 1u, ColSpan: 5u,
                BdTop: BdBox, BdRight: BdCell, BdBottom: BdCell, BdLeft: BdCell, BdColor: Black),

            Th("Tax Amt",   rowSpan: 1, topBd: false),
            Th("CGST Amt",  rowSpan: 1, topBd: false),
            Th("SGST Amt",  rowSpan: 1, topBd: false),
            Th("IGST Amt",  rowSpan: 1, topBd: false),
            Th("TCS Amt",   rowSpan: 1, topBd: false),
        };

        return new TableHeaderConfig(cells, Font: new StyleFont(FontFamily, FsTh, Bold: true, Color: Black));
    }

    private void RenderFinancialSummary(IContainer c)
    {
        static string F2(decimal v, NumberFormatInfo fmt) => v == 0m ? "-" : v.ToString("N2", fmt);

        c.PaddingHorizontal(TableInset, Unit.Millimetre)
         .PaddingVertical(2)
         .Row(row =>
         {
             row.RelativeItem();

             row.ConstantItem(200, Unit.Millimetre)
                .Border(BdData).BorderColor(Black)
                .Column(col =>
                {
                    col.Spacing(0);

                    void SummaryRow(string label, string value)
                    {
                        col.Item().Row(r =>
                        {
                            r.RelativeItem().PaddingVertical(2).PaddingLeft(6)
                             .Text(t =>
                             {
                                 t.AlignLeft();
                                 t.Span(label).Bold().FontSize(FsData);
                             });
                            r.ConstantItem(55, Unit.Millimetre)
                             .BorderLeft(BdData).BorderColor(Black)
                             .PaddingVertical(2).PaddingRight(6)
                             .Text(t =>
                             {
                                 t.AlignRight();
                                 t.Span(value).FontSize(FsData);
                             });
                        });
                    }

                    if (_po.FreightAmt != 0m)
                        SummaryRow("Freight Amount", F2(_po.FreightAmt, _inFmt));
                    if (_po.RoundOff != 0m)
                        SummaryRow("Round Off", F2(_po.RoundOff, _inFmt));

                    col.Item().Row(r =>
                    {
                        r.RelativeItem().PaddingVertical(2).PaddingLeft(6)
                         .Text(t =>
                         {
                             t.AlignLeft();
                             t.Span("Order Value").Bold().FontSize(FsData).FontColor(Navy);
                         });
                        r.ConstantItem(55, Unit.Millimetre)
                         .BorderLeft(BdData).BorderColor(Black)
                         .PaddingVertical(2).PaddingRight(6)
                         .Text(t =>
                         {
                             t.AlignRight();
                             t.Span(F2(_po.OrderValue, _inFmt)).Bold().FontSize(FsData).FontColor(Navy);
                         });
                    });
                });
         });
    }

    private SignatureConfig BuildSignature()
    {
        return new SignatureConfig(
            InsetMm:     TableInset,
            MinHeightMm: SigH,
            BorderPt:    BdBox,
            BorderColor: Black,
            Font:        new StyleFont(FontFamily, FsSig),
            Blocks: new SigBlockConfig[]
            {
                new("Created By",           _po.CreatedBy,      Date: _po.CreatedDt,  RightBorder: true,  PadV: 8f, PadH: 10f, NamePadTop: 6f),
                new("First Level Approval", _po.FirstLevelApp,  Date: null,           RightBorder: true,  PadV: 8f, PadH: 10f, NamePadTop: 6f),
                new("Authorised Signatory", null,               Date: null,           RightBorder: false, PadV: 8f, PadH: 10f, NamePadTop: 6f),
            });
    }
}
