namespace SpinRise.QuestPDF.Common.Style;

/// <summary>
/// Shared visual language for the PR-report family (Department-Wise, Item-Wise, ...).
/// Palette is verbatim from the customer-approved EPPlus reference
/// (PRDeptwise_2026-05-01_2026-05-31.xlsx) so the QuestPDF output is pixel-faithful.
/// </summary>
public static class PrPdfStyle
{
    // ---- Palette (hex / ARGB — alpha stripped, QuestPDF accepts #RRGGBB) ------------------
    public const string Navy    = "#1F3864";  // company banner / labels / PR No.
    public const string TitleBg = "#2F5496";  // report title row
    public const string BandBg  = "#4472C4";  // period strip + column header band
    public const string GroupBg = "#BDD7EE";  // department group banner
    public const string ZebraBg = "#EBF3FB";  // alternate detail row
    public const string TotalBg = "#D6E4F0";  // grand total (reserved for Item-Wise)
    public const string QtyText = "#1F497D";  // quantity numerals
    public const string White   = "#FFFFFF";
    public const string Black   = "#000000";

    // ---- Status colours -------------------------------------------------------------------
    public const string Orange  = "#FFA500";  // Ordered
    public const string Green   = "#2E7D32";  // Received
    public const string Red     = "#C0392B";  // Force Closed / Cancelled
    public const string Grey    = "#707070";  // Requested

    // ---- Typography -----------------------------------------------------------------------
    public const string FontName  = "Calibri";
    public const float  FontSize  = 9f;       // body
    public const float  TitleSize = 11f;      // report title
    public const float  BannerSize = 13f;     // company banner
    public const string QtyFormat = "#,##0.000";

    /// <summary>Colour for an already-decoded SPINRISE status label.</summary>
    public static string StatusColor(string? status) => (status ?? string.Empty) switch
    {
        "Ordered"                        => Orange,
        "Received"                       => Green,
        "Force Closed" or "Fore Closed"  => Red,
        "Cancelled"                      => Red,
        "Requested"                      => Grey,
        _                                => Navy,
    };
}
