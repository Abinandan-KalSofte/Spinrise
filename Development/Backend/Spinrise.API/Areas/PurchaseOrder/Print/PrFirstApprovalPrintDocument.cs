using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using Spinrise.Application.Areas.PurchaseOrder.FirstLevelApproval.DTOs;

namespace Spinrise.API.Areas.PurchaseOrder.Print;

internal sealed class PrFirstApprovalPrintDocument : IDocument
{
    private readonly PrApprovalReportDto _data;

    // ── Page ──────────────────────────────────────────────────────────────────────
    private const float PageMargin  = 6.3f;
    private const float TableInset  = 2.2f;

    // ── Font ──────────────────────────────────────────────────────────────────────
    private const string FontFamily = "Calibri";
    private const float  FsCompany  = 14f;
    private const float  FsDivision = 9f;
    private const float  FsAddress  = 8f;
    private const float  FsTitle    = 12f;
    private const float  FsInfo     = 10f;
    private const float  FsTh       = 10f;
    private const float  FsData     = 9f;
    private const float  FsSig      = 10f;

    // ── Colours ───────────────────────────────────────────────────────────────────
    private const string Navy  = "#185FA5";
    private const string Black = "#000000";

    // ── Borders (pt) ─────────────────────────────────────────────────────────────
    private const float BdBox  = 1.5f;
    private const float BdCell = 0.5f;
    private const float BdData = 0.67f;

    // ── Column widths (mm) — 9 cols, Σ = 278 mm ──────────────────────────────────
    //  0=S.No  1=ItemCode  2=ItemName  3=Unit
    //  4=ReqQty  5=1stAppQty  6=Rate  7=ApproxValue  8=Remarks
    private static readonly float[] Cols =
        { 9.0f, 18.0f, 60.0f, 11.0f, 25.0f, 28.0f, 26.0f, 28.0f, 73.0f };

    // ── Info section widths (mm) — identical to PrPrintDocument ──────────────────
    private const float LeftPanelW  = 141.5f;
    private const float LeftLabelW  = 34.2f;
    private const float LeftIndent  = 8.5f;
    private const float RightLabelW = 29.4f;
    private const float RightIndent = 10.8f;
    private const float SepW        = 2.1f;

    // ── Row heights (mm) ─────────────────────────────────────────────────────────
    private const float DataRowH = 8.4f;
    private const float SigH     = 22.9f;

    public PrFirstApprovalPrintDocument(PrApprovalReportDto data) => _data = data;

    public static byte[] Generate(PrApprovalReportDto data)
        => new PrFirstApprovalPrintDocument(data).GeneratePdf();

    public DocumentMetadata GetMetadata() => DocumentMetadata.Default;
    public DocumentSettings GetSettings() => DocumentSettings.Default;

    public void Compose(IDocumentContainer container)
    {
        var totalReqQty   = _data.Lines.Sum(l => l.QtyInd);
        var totalAppQty   = _data.Lines.Sum(l => l.FirstAppQty);
        var totalApprox   = _data.Lines.Sum(l => l.Rate * l.FirstAppQty);
        var printStamp    = $"Printed: {DateTime.Now:dd/MM/yyyy  hh:mm tt}";

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
                   .Element(c => QuestPdfTemplateEngine.RenderTable(c, BuildTable(totalReqQty, totalAppQty, totalApprox)));
                col.Item()
                   .Element(c => QuestPdfTemplateEngine.RenderSignature(c, BuildSignature()));
                col.Item()
                   .PaddingHorizontal(TableInset, Unit.Millimetre)
                   .PaddingVertical(2)
                   .Text(t => { t.AlignRight(); t.Span(printStamp).FontSize(FsAddress).FontColor(Black); });
            });
        });
    }

    // ── Header (company letterhead) ───────────────────────────────────────────────

    private HeaderConfig BuildHeader()
    {
        var name = string.IsNullOrWhiteSpace(_data.DivPrintName) ? _data.DivName : _data.DivPrintName;

        return new HeaderConfig(
            InsetMm:      TableInset,
            PadBottomMm:  1f,
            BorderPt:     BdBox,
            BorderColor:  Black,
            Logo:         new LogoConfig(_data.DivLogo, WidthMm: 51.6f, MaxHeightMm: 28.7f, GapMm: 9.8f),
            CompanyFont:  new StyleFont(FontFamily, FsCompany,  Bold: true, Color: Navy),
            UnitFont:     new StyleFont(FontFamily, FsDivision, Bold: true, Color: Navy),
            AddressFont:  new StyleFont(FontFamily, FsAddress),
            CompanyName:  name,
            UnitName:     _data.DivUnitName,
            AddressLines: new[]
            {
                $"{_data.DivAddress1}, {_data.DivAddress2}".Trim(' ', ','),
                $"{_data.DivAddress3} - {_data.DivPinCode}, {_data.DivState}".Trim(' ', ',', '-'),
                string.IsNullOrWhiteSpace(_data.DivPhone) ? "" : $"Phone: {_data.DivPhone}",
                string.IsNullOrWhiteSpace(_data.DivEmail) ? "" : $"Email: {_data.DivEmail}",
            });
    }

    // ── Info section ──────────────────────────────────────────────────────────────

    private InfoSectionConfig BuildInfo()
    {
        var requester = !string.IsNullOrWhiteSpace(_data.ReqName) ? _data.ReqName : "";
        var depLabel  = string.IsNullOrWhiteSpace(_data.DepName)  ? _data.DepCode : _data.DepName;

        return new InfoSectionConfig(
            InsetMm:     TableInset,
            BorderPt:    BdBox,
            BorderColor: Black,
            Title:       "Purchase Requisition — First Level Approval",
            TitleFont:   new StyleFont(FontFamily, FsTitle, Bold: true, Color: Navy),
            TitlePadVMm: 3f,
            LabelFont:   new StyleFont(FontFamily, FsInfo, Bold: true),
            ValueFont:   new StyleFont(FontFamily, FsInfo, Bold: false),
            DividerMm:   0.53f,
            LeftPanel: new InfoPanelConfig(
                WidthMm: LeftPanelW, IndentMm: LeftIndent, PadVMm: 3f, RowSpacingMm: 3f,
                Rows: new InfoRowConfig[]
                {
                    new("PR.No.",        ((long)_data.PrNo).ToString(),                    RightLabelW, SepW),
                    new("PR.Date/Time",  FormatCreatedDt(),                                RightLabelW, SepW),
                    new("Approve Date",  _data.App1Date?.ToString("dd-MM-yyyy") ?? "",     RightLabelW, SepW),
                }),
            RightPanel: new InfoPanelConfig(
                WidthMm: 0, IndentMm: RightIndent, PadVMm: 3f, RowSpacingMm: 3f,
                Rows: new InfoRowConfig[]
                {
                    new("Requester Name", requester,                     LeftLabelW, SepW),
                    new("Created By",     _data.CreatedBy,               LeftLabelW, SepW),
                    new("Department",     depLabel,                      LeftLabelW, SepW),
                    new("Reference",      _data.RefNo ?? "",             LeftLabelW, SepW),
                }));
    }

    // ── Item table ────────────────────────────────────────────────────────────────

    private TableConfig BuildTable(decimal totalReqQty, decimal totalAppQty, decimal totalApprox)
    {
        var emptyMach = new MachCellConfig(MinHeightMm: 0f, BdSidePt: BdData, BdColor: Black);

        var rows = _data.Lines.Select((line, i) =>
        {
            var approxValue = line.Rate * line.FirstAppQty;

            DcCellConfig Dc(string text, DA align) =>
                new(text, align, MinHeightMm: DataRowH, FontSizePt: FsData, BdSidePt: BdData, BdColor: Black);
            DcCellConfig DcMono(string text, DA align) =>
                new(text, align, MinHeightMm: DataRowH, FontSizePt: FsData, BdSidePt: BdData, BdColor: Black, FontFamily: "Courier New");

            DcCellConfig[] cells =
            {
                Dc((i + 1).ToString(),                                                          DA.Center),
                DcMono(line.ItemCode,                                                           DA.Left),
                Dc(line.ItemName,                                                               DA.Left),
                Dc(line.Uom,                                                                    DA.Center),
                Dc(line.QtyInd     == 0m ? "" : line.QtyInd.ToString("N3"),                    DA.Right),
                Dc(line.FirstAppQty == 0m ? "" : line.FirstAppQty.ToString("N3"),              DA.Right),
                Dc(line.Rate       == 0m ? "" : line.Rate.ToString("N4"),                      DA.Right),
                Dc(approxValue     == 0m ? "" : approxValue.ToString("N2"),                    DA.Right),
                Dc(line.Remarks    ?? string.Empty,                                             DA.Left),
            };

            return new DataRowConfig(cells, Array.Empty<ChildRowConfig>());
        }).ToList();

        var totalsRow = new TotalsRowConfig(
            Cells: new TotalsCellConfig[]
            {
                new("Grand Total",                                                     DA.Right,  ColumnSpan: 4u, Bold: true,  Color: Navy),
                new(totalReqQty == 0m  ? "" : totalReqQty.ToString("N3"),             DA.Right,  ColumnSpan: 1u, Bold: true,  Color: Navy),
                new(totalAppQty == 0m  ? "" : totalAppQty.ToString("N3"),             DA.Right,  ColumnSpan: 1u, Bold: true,  Color: Navy),
                new("",                                                                DA.Right,  ColumnSpan: 1u, Bold: false, Color: null),
                new(totalApprox == 0m  ? "" : totalApprox.ToString("N2"),             DA.Right,  ColumnSpan: 1u, Bold: true,  Color: Navy),
                new("",                                                                DA.Left,   ColumnSpan: 1u, Bold: false, Color: null),
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
        ThCellConfig Th(string text) => new(
            Text:     text,
            RowSpan:  1u,
            ColSpan:  1u,
            BdTop:    BdBox,
            BdRight:  BdCell,
            BdBottom: BdBox,
            BdLeft:   BdCell,
            BdColor:  Black);

        ThCellConfig[] cells =
        {
            Th("S.No"),
            Th("Item ID"),
            Th("Item Name"),
            Th("Unit"),
            Th("Required\nQuantity"),
            Th("1st Approved\nQuantity"),
            Th("Rate"),
            Th("Approx.\nValue"),
            Th("Remarks"),
        };

        return new TableHeaderConfig(cells, Font: new StyleFont(FontFamily, FsTh, Bold: true, Color: Black));
    }

    // ── Signature ─────────────────────────────────────────────────────────────────

    private SignatureConfig BuildSignature()
    {
        var requester     = _data.ReqName ?? string.Empty;
        var approverLabel = _data.ApproverLabel;
        var approverName  = _data.ApproverName ?? string.Empty;

        return new SignatureConfig(
            InsetMm:     TableInset,
            MinHeightMm: SigH,
            BorderPt:    BdBox,
            BorderColor: Black,
            Font:        new StyleFont(FontFamily, FsSig),
            Blocks: new SigBlockConfig[]
            {
                new("Requested By",                       requester,    Date: null, RightBorder: true,  PadV: 8f, PadH: 10f, NamePadTop: 6f),
                new($"Approved By ({approverLabel})",     approverName, Date: null, RightBorder: true,  PadV: 8f, PadH: 10f, NamePadTop: 6f),
                new("Authorised Signatory",               string.Empty, Date: null, RightBorder: false, PadV: 8f, PadH: 10f, NamePadTop: 6f),
            });
    }

    // ── Helpers ───────────────────────────────────────────────────────────────────

    private string FormatCreatedDt()
    {
        if (string.IsNullOrWhiteSpace(_data.CreatedDt))
            return _data.PrDate.ToString("dd-MM-yyyy");

        // CreatedDt format from DB: "DD/MM/YYYY HH:MM:SS" (24-hour, no AM/PM suffix)
        var parts = _data.CreatedDt.Trim().Split(' ', StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length >= 2 &&
            DateTime.TryParseExact(parts[0] + " " + parts[1], "dd/MM/yyyy HH:mm:ss",
                null, System.Globalization.DateTimeStyles.None, out var dt))
            return dt.ToString("dd-MM-yyyy  hh:mm tt");

        return _data.PrDate.ToString("dd-MM-yyyy");
    }
}
