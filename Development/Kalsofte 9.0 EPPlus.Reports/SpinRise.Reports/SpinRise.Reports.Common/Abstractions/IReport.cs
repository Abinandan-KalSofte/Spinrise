namespace SpinRise.Reports.Common.Abstractions;

/// <summary>
/// A single report, implemented once per report project (DepartmentWise, DateWise, ItemWise, ...).
/// Each report owns its data access and its EPPlus rendering; this is the only contract the
/// outside world needs to run one.
/// </summary>
/// <typeparam name="TParameters">The report's selection criteria (division, dates, etc.).</typeparam>
public interface IReport<in TParameters>
{
    /// <summary>Stable identifier for the report, e.g. "PR-DEPTWISE".</summary>
    string Code { get; }

    /// <summary>Runs the query and renders the workbook.</summary>
    Task<ReportResult> GenerateAsync(TParameters parameters, CancellationToken cancellationToken = default);
}
