namespace SpinRise.Reports.DepartmentWise;

/// <summary>
/// Selection criteria for the Department-Wise Purchase Requisition report.
///
/// INFERRED from the .rpt field usage (Crystal's parameter/record-selection block could not be
/// decoded reliably from the binary). Confirm the exact prompts against the sample export —
/// e.g. whether dates filter on PR date, whether department is single/multi/optional, and
/// whether there are extra filters (status, item group, etc.).
/// </summary>
public sealed class DepartmentWiseParameters
{
    /// <summary>Division (PO_PRH.divcode / PP_DIVMAS.DIVCODE). Required.</summary>
    public required string DivCode { get; init; }

    /// <summary>Start of the PR-date range (PO_PRH.prdate).</summary>
    public required DateTime FromDate { get; init; }

    /// <summary>End of the PR-date range (PO_PRH.prdate).</summary>
    public required DateTime ToDate { get; init; }

    /// <summary>Optional single department (PO_PRH.depcode). Null = all departments.</summary>
    public string? DepCode { get; init; }
}
