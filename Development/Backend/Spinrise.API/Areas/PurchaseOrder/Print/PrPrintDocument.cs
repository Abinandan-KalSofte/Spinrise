using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;

namespace Spinrise.API.Areas.PurchaseOrder.Print;

internal sealed class PrPrintDocument : IDocument
{
    private readonly PrPrintDto _pr;

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

    // ── Column widths (mm) — 12 cols, Σ = 277.97 mm ──────────────────────────────
    //  0=S.No  1=ItemCode  2=ItemName  3=Unit  4=ReqQty  5=ReqDate  6=CurrStk
    //  7=Rate  8=Value     9=Date      10=AppCost         11=Remarks
    private static readonly float[] Cols =
        { 8.9f, 17.8f, 58.0f, 11.1f, 21.2f, 19f, 23.0f, 22.0f, 27.7f, 21.8f, 22.7f, 24.77f };

    // ── Info section widths (mm) ──────────────────────────────────────────────────
    private const float LeftPanelW  = 141.5f;
    private const float LeftLabelW  = 34.2f;
    private const float LeftIndent  = 8.5f;
    private const float RightLabelW = 29.4f;
    private const float RightIndent = 10.8f;
    private const float SepW        = 2.1f;

    // ── Row heights (mm) ─────────────────────────────────────────────────────────
    private const float DataRowH = 8.4f;
    private const float MachRowH = 5.0f;
    private const float SigH     = 22.9f;

    public PrPrintDocument(PrPrintDto pr) => _pr = pr;

    public static byte[] Generate(PrPrintDto pr) => new PrPrintDocument(pr).GeneratePdf();

    public DocumentMetadata GetMetadata() => DocumentMetadata.Default;
    public DocumentSettings GetSettings() => DocumentSettings.Default;

    public void Compose(IDocumentContainer container)
    {
        var totalValue = _pr.Lines.Sum(l => l.Rate * l.QtyInd);
        var totalAppCost = _pr.Lines.Sum(l =>
        {
            var rateValue = l.Rate * l.QtyInd;
            return l.AppCost <= 0m ? rateValue : l.AppCost;
        });

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
                   .Element(c => QuestPdfTemplateEngine.RenderTable(c, BuildTable(totalValue, totalAppCost)));
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
        var name = string.IsNullOrWhiteSpace(_pr.DivPrintName) ? _pr.DivName : _pr.DivPrintName;

        return new HeaderConfig(
            InsetMm:      TableInset,
            PadBottomMm:  1f,
            BorderPt:     BdBox,
            BorderColor:  Black,
            Logo:         new LogoConfig(_pr.DivLogo, WidthMm: 51.6f, MaxHeightMm: 28.7f, GapMm: 9.8f),
            CompanyFont:  new StyleFont(FontFamily, FsCompany,  Bold: true, Color: Navy),
            UnitFont:     new StyleFont(FontFamily, FsDivision, Bold: true, Color: Navy),
            AddressFont:  new StyleFont(FontFamily, FsAddress),
            CompanyName:  name,
            UnitName:     _pr.DivUnitName,
            AddressLines: new[]
            {
                $"{_pr.DivAddress1}, {_pr.DivAddress2}".Trim(' ', ','),
                $"{_pr.DivAddress3} - {_pr.DivPinCode}, {_pr.DivState}".Trim(' ', ',', '-'),
                string.IsNullOrWhiteSpace(_pr.DivPhone) ? "" : $"Phone: {_pr.DivPhone}",
                string.IsNullOrWhiteSpace(_pr.DivEmail) ? "" : $"Email: {_pr.DivEmail}",
            });
    }

    private InfoSectionConfig BuildInfo()
    {
        var requester = !string.IsNullOrWhiteSpace(_pr.ReqEmpName) ? _pr.ReqEmpName : _pr.ReqName;
        var depLabel  = string.IsNullOrWhiteSpace(_pr.DepName) ? _pr.DepCode : _pr.DepName;

        return new InfoSectionConfig(
            InsetMm:     TableInset,
            BorderPt:    BdBox,
            BorderColor: Black,
            Title:       "Purchase Requisition",
            TitleFont:   new StyleFont(FontFamily, FsTitle, Bold: true, Color: Navy),
            TitlePadVMm: 3f,
            LabelFont:   new StyleFont(FontFamily, FsInfo, Bold: true),
            ValueFont:   new StyleFont(FontFamily, FsInfo, Bold: false),
            DividerMm:   0.53f,
            LeftPanel: new InfoPanelConfig(
                WidthMm: LeftPanelW, IndentMm: LeftIndent, PadVMm: 3f, RowSpacingMm: 3f,
                Rows: new InfoRowConfig[]
                {
                    new("Requester Name", requester,       LeftLabelW, SepW),
                    new("Created By",     _pr.CreatedBy,   LeftLabelW, SepW),
                    new("Department",     depLabel,        LeftLabelW, SepW),
                    new("Reference",      _pr.RefNo,       LeftLabelW, SepW),
                }),
            RightPanel: new InfoPanelConfig(
                WidthMm: 0, IndentMm: RightIndent, PadVMm: 3f, RowSpacingMm: 3f,
                Rows: new InfoRowConfig[]
                {
                    new("PR.No.",        ((long)_pr.PrNo).ToString(),               RightLabelW, SepW),
                    new("PR.Date/Time",  FormatCreatedDt(),                              RightLabelW, SepW),
                    new("Approved Date", _pr.PresidentAppDate,                      RightLabelW, SepW),
                }));
    }

    private TableConfig BuildTable(decimal totalValue, decimal totalAppCost)
    {
        var emptyMach = new MachCellConfig(MinHeightMm: MachRowH, BdSidePt: BdData, BdColor: Black);

        var rows = _pr.Lines.Select((line, i) =>
        {
            var rate       = line.Rate;
            var rateValue  = rate * line.QtyInd;
            var approxCost = line.AppCost <= 0m ? rateValue : line.AppCost;
            var stock      = line.CurrentStock;

            DcCellConfig Dc(string text, DA align) =>
                new(text, align, MinHeightMm: DataRowH, FontSizePt: FsData, BdSidePt: BdData, BdColor: Black);
            DcCellConfig DcMono(string text, DA align) =>
                new(text, align, MinHeightMm: DataRowH, FontSizePt: FsData, BdSidePt: BdData, BdColor: Black, FontFamily: "Courier New");

            DcCellConfig[] cells =
            {
                Dc((i + 1).ToString(),                                                                    DA.Center),
                DcMono(line.ItemCode,                                                                     DA.Left),
                Dc(line.ItemName,                                                                         DA.Left),
                Dc(line.Uom,                                                                              DA.Center),
                Dc(line.QtyInd == 0m ? "" : line.QtyInd.ToString("N3"),                                  DA.Right),
                Dc(line.ReqdDate.HasValue ? line.ReqdDate.Value.ToString("dd/MM/yyyy") : "",              DA.Center),
                Dc(stock < 1m ? "" : stock.ToString("N3"),                                               DA.Right),
                Dc(rate == 0m ? "" : rate.ToString("N4"),                                                DA.Right),
                Dc(rateValue == 0m ? "" : rateValue.ToString("N2"),                                      DA.Right),
                Dc(line.LastPoDate.HasValue ? line.LastPoDate.Value.ToString("dd/MM/yyyy") : "",          DA.Center),
                Dc(approxCost == 0m ? "" : approxCost.ToString("N2"),                                    DA.Right),
                Dc(line.Remarks,                                                                          DA.Left),
            };

            var childRows = new List<ChildRowConfig>();
            if (!string.IsNullOrWhiteSpace(line.DrawNo))
                childRows.Add(new($"DRAWING NO.:  {line.DrawNo}", FsData));
            if (!string.IsNullOrWhiteSpace(line.CatNo))
                childRows.Add(new($"CATALOGUE NO.:  {line.CatNo}", FsData));
            if (!string.IsNullOrWhiteSpace(line.MacNo))
                childRows.Add(new($"Machine:  {line.MacNo}", FsData));

            return new DataRowConfig(cells, childRows.ToArray());
        }).ToList();

        var totalsRow = new TotalsRowConfig(
            Cells: new TotalsCellConfig[]
            {
                new("Grand Total", DA.Right, ColumnSpan: 8u, Bold: true, Color: Navy),
                new(totalValue   == 0m ? "" : totalValue.ToString("N2"), DA.Right, Bold: true, Color: Navy),
                new("", DA.Center),
                new(totalAppCost == 0m ? "" : totalAppCost.ToString("N2"), DA.Right, Bold: true, Color: Navy),
                new("", DA.Left),
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
        ThCellConfig Th(string text, int rowSpan, bool topBd) => new(
            Text:     text,
            RowSpan:  (uint)rowSpan,
            ColSpan:  1u,
            BdTop:    topBd ? (float?)BdBox : null,
            BdRight:  BdCell,
            BdBottom: BdBox,
            BdLeft:   BdCell,
            BdColor:  Black);

        ThCellConfig[] cells =
        {
            Th("S.No",                    rowSpan: 2, topBd: true),
            Th("Item ID",                 rowSpan: 2, topBd: true),
            Th("Item Name",               rowSpan: 2, topBd: true),
            Th("Unit",                    rowSpan: 2, topBd: true),
            Th("Required\nQuantity",      rowSpan: 2, topBd: true),
            Th("Required\nDate",          rowSpan: 2, topBd: true),
            Th("Current stock\nQuantity", rowSpan: 2, topBd: true),

            new ThCellConfig(
                Text:     "Previous Purchase Details",
                RowSpan:  1u,
                ColSpan:  3u,
                BdTop:    BdBox,
                BdRight:  BdCell,
                BdBottom: BdCell,
                BdLeft:   BdCell,
                BdColor:  Black),

            Th("App. Cost\nValue", rowSpan: 2, topBd: true),
            Th("Remarks",          rowSpan: 2, topBd: true),

            Th("Rate/Unit", rowSpan: 1, topBd: false),
            Th("Value",     rowSpan: 1, topBd: false),
            Th("Date",      rowSpan: 1, topBd: false),
        };

        return new TableHeaderConfig(cells, Font: new StyleFont(FontFamily, FsTh, Bold: true, Color: Black));
    }

    private string FormatCreatedDt()
    {
        if (string.IsNullOrWhiteSpace(_pr.CreatedDt))
            return _pr.PrDate.ToString("dd-MM-yyyy");

        // CreatedDt format: "DD/MM/YYYY HH:MM:SS AM/PM" — 24-hour clock with trailing AM/PM marker
        var parts = _pr.CreatedDt.Trim().Split(' ', StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length >= 2 &&
            DateTime.TryParseExact(parts[0] + " " + parts[1], "dd/MM/yyyy HH:mm:ss",
                null, System.Globalization.DateTimeStyles.None, out var dt))
            return dt.ToString("dd-MM-yyyy  hh:mm tt");

        return _pr.PrDate.ToString("dd-MM-yyyy");
    }

    private SignatureConfig BuildSignature()
    {
        var requester = !string.IsNullOrWhiteSpace(_pr.ReqEmpName) ? _pr.ReqEmpName : _pr.ReqName;

        return new SignatureConfig(
            InsetMm:     TableInset,
            MinHeightMm: SigH,
            BorderPt:    BdBox,
            BorderColor: Black,
            Font:        new StyleFont(FontFamily, FsSig),
            Blocks: new SigBlockConfig[]
            {
                new("Requested By",         requester,         Date: null,                 RightBorder: true,  PadV: 8f, PadH: 10f, NamePadTop: 6f),
                new("Approved By",          _pr.FirstAppUser,  Date: null,                 RightBorder: true,  PadV: 8f, PadH: 10f, NamePadTop: 6f),
                new("Authorised Signatory", _pr.FinalAppUser,  Date: _pr.PresidentAppDate, RightBorder: false, PadV: 8f, PadH: 10f, NamePadTop: 6f),
            });
    }
}
