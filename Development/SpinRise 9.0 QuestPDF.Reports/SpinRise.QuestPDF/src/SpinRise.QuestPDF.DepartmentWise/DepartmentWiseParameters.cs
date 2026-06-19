namespace SpinRise.QuestPDF.DepartmentWise;

/// <summary>
/// Input parameters for the Department-Wise PR report — mirrors <c>ksp_Pr_DepWise</c>
/// (@Divcode, @FromDate, @ToDate, @FrmDep, @ToDep).
/// </summary>
public sealed class DepartmentWiseParameters
{
    public required string   DivCode  { get; init; }
    public required DateTime FromDate { get; init; }
    public required DateTime ToDate   { get; init; }

    /// <summary>Department-range start (inclusive). Null = open / from the first department.</summary>
    public string? FromDep { get; init; }

    /// <summary>Department-range end (inclusive). Null = open / through the last department.</summary>
    public string? ToDep { get; init; }
}
