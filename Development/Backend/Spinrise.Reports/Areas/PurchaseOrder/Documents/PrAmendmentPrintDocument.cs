using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using Spinrise.Application.Areas.PurchaseOrder.Amendment.DTOs;
using Spinrise.Reports.Core.Engine;

namespace Spinrise.Reports.Areas.PurchaseOrder.Documents;

public sealed class PrAmendmentPrintDocument : IDocument
{
    private readonly PrAmendmentPrintDto _dto;

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

    // ── Column widths (mm) — 6 cols, Σ = 280.0 mm ───────────────────────────────
    //  0=S.No  1=ItemCode  2=ItemName  3=Unit  4=PRQty  5=AmendReason
    private static readonly float[] Cols =
        { 10.0f, 22.0f, 100.0f, 15.0f, 28.0f, 105.0f };

    // ── Info section widths (mm) ──────────────────────────────────────────────────
    private const float LeftPanelW  = 141.5f;
    private const float LeftLabelW  = 30.0f;   // fits "Amendment No."
    private const float RightLabelW = 32.0f;   // fits "Amendment Date"
    private const float LeftIndent  = 8.5f;
    private const float RightIndent = 10.8f;
    private const float SepW        = 2.1f;

    // ── Row heights (mm) ─────────────────────────────────────────────────────────
    private const float DataRowH = 8.4f;
    private const float MachRowH = 5.0f;
    private const float SigH     = 22.9f;

    public PrAmendmentPrintDocument(PrAmendmentPrintDto dto) => _dto = dto;

    public static byte[] Generate(PrAmendmentPrintDto dto) =>
        new PrAmendmentPrintDocument(dto).GeneratePdf();

    public DocumentMetadata GetMetadata() => DocumentMetadata.Default;
    public DocumentSettings GetSettings() => DocumentSettings.Default;

    public void Compose(IDocumentContainer container)
    {
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
                   .Element(c => QuestPdfTemplateEngine.RenderTable(c, BuildTable()));
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
        var name = string.IsNullOrWhiteSpace(_dto.DivPrintName) ? _dto.DivName : _dto.DivPrintName;

        return new HeaderConfig(
            InsetMm:      TableInset,
            PadBottomMm:  1f,
            BorderPt:     BdBox,
            BorderColor:  Black,
            Logo:         new LogoConfig(_dto.DivLogo, WidthMm: 51.6f, MaxHeightMm: 28.7f, GapMm: 9.8f),
            CompanyFont:  new StyleFont(FontFamily, FsCompany,  Bold: true, Color: Navy),
            UnitFont:     new StyleFont(FontFamily, FsDivision, Bold: true, Color: Navy),
            AddressFont:  new StyleFont(FontFamily, FsAddress),
            CompanyName:  name,
            UnitName:     _dto.DivUnitName,
            AddressLines: new[]
            {
                $"{_dto.DivAddress1}, {_dto.DivAddress2}".Trim(' ', ','),
                $"{_dto.DivAddress3} - {_dto.DivPinCode}, {_dto.DivState}".Trim(' ', ',', '-'),
                string.IsNullOrWhiteSpace(_dto.DivPhone) ? "" : $"Phone: {_dto.DivPhone}",
                string.IsNullOrWhiteSpace(_dto.DivEmail) ? "" : $"Email: {_dto.DivEmail}",
            });
    }

    private InfoSectionConfig BuildInfo() =>
        new(
            InsetMm:     TableInset,
            BorderPt:    BdBox,
            BorderColor: Black,
            Title:       "Purchase Requisition Amendment",
            TitleFont:   new StyleFont(FontFamily, FsTitle, Bold: true, Color: Navy),
            TitlePadVMm: 3f,
            LabelFont:   new StyleFont(FontFamily, FsInfo, Bold: true),
            ValueFont:   new StyleFont(FontFamily, FsInfo, Bold: false),
            DividerMm:   0.53f,
            LeftPanel: new InfoPanelConfig(
                WidthMm: LeftPanelW, IndentMm: LeftIndent, PadVMm: 3f, RowSpacingMm: 3f,
                Rows: new InfoRowConfig[]
                {
                    new("Amendment No.", _dto.AmendNo.ToString(),             LeftLabelW, SepW),
                    new("PR. No.",       ((long)_dto.PrNo).ToString(),            LeftLabelW, SepW),
                }),
            RightPanel: new InfoPanelConfig(
                WidthMm: 0, IndentMm: RightIndent, PadVMm: 3f, RowSpacingMm: 3f,
                Rows: new InfoRowConfig[]
                {
                    new("Amendment Date", _dto.AmendDate, RightLabelW, SepW),
                    new("PR. Date.",      _dto.PrDate,    RightLabelW, SepW),
                }));

    private TableConfig BuildTable()
    {
        var emptyMach = new MachCellConfig(MinHeightMm: MachRowH, BdSidePt: BdData, BdColor: Black);

        var rows = _dto.Lines.Select((line, i) =>
        {
            DcCellConfig Dc(string text, DA align) =>
                new(text, align, MinHeightMm: DataRowH, FontSizePt: FsData, BdSidePt: BdData, BdColor: Black);
            DcCellConfig DcMono(string text, DA align) =>
                new(text, align, MinHeightMm: DataRowH, FontSizePt: FsData, BdSidePt: BdData, BdColor: Black, FontFamily: "Courier New");

            DcCellConfig[] cells =
            {
                Dc((i + 1).ToString(),                                       DA.Center),
                DcMono(line.ItemCode,                                        DA.Left),
                Dc(line.ItemName,                                            DA.Left),
                Dc(line.Uom,                                                 DA.Center),
                Dc(line.QtyInd == 0m ? "" : line.QtyInd.ToString("N3"),     DA.Right),
                Dc(_dto.AmendmentReason ?? string.Empty,                     DA.Left),
            };

            var childRows = new List<ChildRowConfig>();
            if (!string.IsNullOrWhiteSpace(line.DrawNo))
                childRows.Add(new($"DRAWING NO.:  {line.DrawNo}", FsData));
            if (!string.IsNullOrWhiteSpace(line.CatNo))
                childRows.Add(new($"CATALOGUE NO.:  {line.CatNo}", FsData));
            if (!string.IsNullOrWhiteSpace(line.MacDesc))
                childRows.Add(new($"Machine:  {line.MacDesc}", FsData));
            if (line.RateSource == "MANUAL" && !string.IsNullOrWhiteSpace(line.RateJustification))
                childRows.Add(new($"Rate Justification:  {line.RateJustification}", FsData));

            return new DataRowConfig(cells, childRows.ToArray());
        }).ToList();

        return new TableConfig(
            InsetMm:       TableInset,
            Columns:       Cols.Select(w => new ColDef(w)).ToArray(),
            Header:        BuildTableHeader(),
            EmptyMachCell: emptyMach,
            Rows:          rows,
            TotalsRow:     null);
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
            Th("Item Description"),
            Th("Unit"),
            Th("PR. Quantity"),
            Th("Amendment Reason"),
        };

        return new TableHeaderConfig(cells, Font: new StyleFont(FontFamily, FsTh, Bold: true, Color: Black));
    }

    private SignatureConfig BuildSignature() =>
        new(
            InsetMm:     TableInset,
            MinHeightMm: SigH,
            BorderPt:    BdBox,
            BorderColor: Black,
            Font:        new StyleFont(FontFamily, FsSig),
            Blocks: new SigBlockConfig[]
            {
                new("Prepared By",          _dto.CreatedBy, Date: null, RightBorder: true,  PadV: 8f, PadH: 10f, NamePadTop: 6f),
                new("Approved By",          null,         Date: null, RightBorder: true,  PadV: 8f, PadH: 10f, NamePadTop: 6f),
                new("Authorised Signatory", null,         Date: null, RightBorder: false, PadV: 8f, PadH: 10f, NamePadTop: 6f),
            });
}
