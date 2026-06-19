namespace SpinRise.Reports.ItemWise;

/// <summary>
/// Selection criteria for the Item-Wise PR report, mapped onto dbo.KSP_PR_ITEMWISE.
/// </summary>
public sealed class ItemWiseParameters
{
    public required string DivCode { get; init; }
    public required DateTime FromDate { get; init; }
    public required DateTime ToDate { get; init; }

    /// <summary>
    /// Item selection, passed to the SP's @FITEM:
    ///   "A"            => all items (the SP's sentinel value)
    ///   "320B006,9002001" => comma-separated list of specific item codes
    /// (The SP ignores @TITEM, so there is no "to item".)
    /// </summary>
    public string ItemFilter { get; init; } = "A";
}
