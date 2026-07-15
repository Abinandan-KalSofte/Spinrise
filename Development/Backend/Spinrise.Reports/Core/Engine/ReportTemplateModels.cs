namespace Spinrise.Reports.Core.Engine;

// ── Shared enums ──────────────────────────────────────────────────────────────
public enum DA { Left, Center, Right }

// ── Shared style primitives ───────────────────────────────────────────────────
public record StyleFont(string Family, float Size, bool Bold = false, string Color = "#000000");

// ── Company Header ────────────────────────────────────────────────────────────
public record LogoConfig(byte[]? Data, float WidthMm, float MaxHeightMm, float GapMm);

public record HeaderConfig(
    float InsetMm,
    float PadBottomMm,
    float BorderPt,
    string BorderColor,
    LogoConfig Logo,
    StyleFont CompanyFont,
    StyleFont UnitFont,
    StyleFont AddressFont,
    string CompanyName,
    string UnitName,
    IReadOnlyList<string> AddressLines);

// ── Info Section ──────────────────────────────────────────────────────────────
public record InfoRowConfig(string Label, string Value, float LabelMm, float SepMm);

public record InfoPanelConfig(
    float WidthMm,
    float IndentMm,
    float PadVMm,
    float RowSpacingMm,
    IReadOnlyList<InfoRowConfig> Rows);

public record InfoSectionConfig(
    float InsetMm,
    float BorderPt,
    string BorderColor,
    string Title,
    StyleFont TitleFont,
    float TitlePadVMm,
    StyleFont LabelFont,
    StyleFont ValueFont,
    float DividerMm,
    InfoPanelConfig LeftPanel,
    InfoPanelConfig RightPanel);

// ── Item Table ────────────────────────────────────────────────────────────────
public record ColDef(float WidthMm);

public record ThCellConfig(
    string Text,
    uint RowSpan,
    uint ColSpan,
    float? BdTop,
    float? BdRight,
    float? BdBottom,
    float? BdLeft,
    string BdColor,
    float PadV = 3f,
    float PadH = 2f);

public record DcCellConfig(
    string Text,
    DA Align,
    float MinHeightMm,
    float FontSizePt,
    float BdSidePt,
    string BdColor,
    float PadV = 2f,
    float PadH = 2f,
    float PadR = 3f,
    string? FontFamily = null);

public record TotalsCellConfig(
    string Text,
    DA Align,
    uint ColumnSpan = 1u,
    bool Bold = false,
    float PadV = 2f,
    float PadH = 2f,
    float PadR = 3f,
    string? Color = null);

public record TotalsRowConfig(
    IReadOnlyList<TotalsCellConfig> Cells,
    float MinHeightMm,
    float FontSizePt,
    float BdSidePt,
    string BdColor,
    string BgColor = "#F2F2F2");

public record MachCellConfig(
    float MinHeightMm,
    float BdSidePt,
    string BdColor,
    float PadV = 1f,
    float PadH = 2f);

public record ChildRowConfig(string LabelText, float FontSizePt);

public record DataRowConfig(
    IReadOnlyList<DcCellConfig> Cells,
    IReadOnlyList<ChildRowConfig> ChildRows);

public record TableHeaderConfig(IReadOnlyList<ThCellConfig> Cells, StyleFont Font);

public record TableConfig(
    float InsetMm,
    IReadOnlyList<ColDef> Columns,
    TableHeaderConfig Header,
    MachCellConfig EmptyMachCell,
    IReadOnlyList<DataRowConfig> Rows,
    TotalsRowConfig? TotalsRow = null);

// ── Signature ─────────────────────────────────────────────────────────────────
public record SigBlockConfig(
    string Title,
    string? Name,
    string? Date,
    bool RightBorder,
    float PadV,
    float PadH,
    float NamePadTop);

public record SignatureConfig(
    float InsetMm,
    float MinHeightMm,
    float BorderPt,
    string BorderColor,
    StyleFont Font,
    IReadOnlyList<SigBlockConfig> Blocks);
