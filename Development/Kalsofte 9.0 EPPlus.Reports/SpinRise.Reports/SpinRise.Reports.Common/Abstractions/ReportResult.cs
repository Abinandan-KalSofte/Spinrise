namespace SpinRise.Reports.Common.Abstractions;

/// <summary>
/// The rendered output of a report. Returning bytes (rather than writing a file) lets any
/// host stream it to a browser, save it to disk, or e-mail it without caring how it was built.
/// </summary>
public sealed class ReportResult
{
    /// <summary>The rendered workbook.</summary>
    public required byte[] Content { get; init; }

    /// <summary>Suggested download name, e.g. "DepartmentWise_2026-06-06.xlsx".</summary>
    public required string FileName { get; init; }

    /// <summary>MIME type — defaults to .xlsx.</summary>
    public string ContentType { get; init; }
        = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";

    /// <summary>Number of detail rows in the report (handy for logging / empty-result checks).</summary>
    public int RowCount { get; init; }
}
