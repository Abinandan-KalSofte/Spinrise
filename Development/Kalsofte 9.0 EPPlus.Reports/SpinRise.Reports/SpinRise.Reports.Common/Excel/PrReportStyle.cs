using System.Drawing;
using OfficeOpenXml;
using OfficeOpenXml.Style;

namespace SpinRise.Reports.Common.Excel;

/// <summary>
/// Shared visual language for the PR report family (DateWise, DepartmentWise, ItemWise).
/// Palette, cell helpers and the status colour map — all taken from the approved DateWise sample —
/// so every report renders with one consistent look.
/// </summary>
public static class PrReportStyle
{
    public static readonly Color Navy    = Color.FromArgb(0x1F, 0x38, 0x64); // banner / labels / PR No
    public static readonly Color TitleBg = Color.FromArgb(0x2F, 0x54, 0x96); // report title row
    public static readonly Color BandBg  = Color.FromArgb(0x44, 0x72, 0xC4); // period strip + col headers
    public static readonly Color GroupBg = Color.FromArgb(0xBD, 0xD7, 0xEE); // group banner / subtotal
    public static readonly Color ZebraBg = Color.FromArgb(0xEB, 0xF3, 0xFB); // alternate detail row
    public static readonly Color TotalBg = Color.FromArgb(0xD6, 0xE4, 0xF0); // grand total
    public static readonly Color QtyText = Color.FromArgb(0x1F, 0x49, 0x7D); // quantity numerals
    public static readonly Color Orange  = Color.FromArgb(0xFF, 0xA5, 0x00); // "Ordered" status

    public const string FontName  = "Calibri";
    public const string QtyFormat = "#,##0.000";

    public static void SetFont(ExcelRange r, float size, bool bold, Color color)
    {
        r.Style.Font.Name = FontName;
        r.Style.Font.Size = size;
        r.Style.Font.Bold = bold;
        r.Style.Font.Color.SetColor(color);
    }

    public static void Fill(ExcelRange r, Color color)
    {
        r.Style.Fill.PatternType = ExcelFillStyle.Solid;
        r.Style.Fill.BackgroundColor.SetColor(color);
    }

    public static void Center(ExcelRange r, bool wrap)
    {
        r.Style.HorizontalAlignment = ExcelHorizontalAlignment.Center;
        r.Style.VerticalAlignment = ExcelVerticalAlignment.Center;
        r.Style.WrapText = wrap;
    }

    /// <summary>Colour for a (already decoded) status label. Handles both the SP and formula spellings.</summary>
    public static Color StatusColor(string? status) => (status ?? string.Empty) switch
    {
        "Ordered"                        => Orange,
        "Received"                       => Color.FromArgb(0x2E, 0x7D, 0x32), // green
        "Fore Closed" or "Force Closed"  => Color.FromArgb(0xC0, 0x39, 0x2B), // red
        "Cancelled"                      => Color.FromArgb(0xC0, 0x39, 0x2B), // red
        "Requested"                      => Color.FromArgb(0x70, 0x70, 0x70), // grey
        _                                => Navy,                             // approval levels / other
    };
}
