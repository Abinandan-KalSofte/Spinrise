namespace SpinRise.QuestPDF.ItemWise;

/// <summary>Input parameters for the Item-Wise PR report (mirrors KSP_PR_ITEMWISE).</summary>
public sealed class ItemWiseParameters
{
    public required string   DivCode  { get; init; }
    public required DateTime FromDate { get; init; }
    public required DateTime ToDate   { get; init; }

    /// <summary>
    /// Item selection, mapped onto the SP's <c>@FITEM</c> parameter:
    ///   "A"               => all items (the SP's sentinel)
    ///   "320B006,9002001" => CSV of specific item codes
    /// (The SP ignores <c>@TITEM</c>, so there is no "to item".)
    /// </summary>
    public string ItemFilter { get; init; } = "A";
}
