namespace SpinRise.QuestPDF.DateWise;

/// <summary>
/// Input parameters for the Date-Wise PR report — mirrors <c>KSP_PR_DateWise</c>
/// (@Divcode, @FromDate, @ToDate, @FrmDep, @ToDep).
/// </summary>
public sealed class DateWiseParameters
{
    public required string   DivCode  { get; init; }
    public required DateTime FromDate { get; init; }
    public required DateTime ToDate   { get; init; }

    /// <summary>Department-range start (inclusive). Null = open / from the first department.</summary>
    public string? FromDep { get; init; }

    /// <summary>Department-range end (inclusive). Null = open / through the last department.</summary>
    public string? ToDep { get; init; }
}
