using QuestPDF.Fluent;
using QuestPDF.Infrastructure;
using SpinRise.QuestPDF.Common.Abstractions;

namespace SpinRise.QuestPDF.DepartmentWise;

/// <summary>
/// Orchestrator for the Department-Wise PDF report. Pulls data via the repository, hands
/// it to <see cref="DepartmentWiseDocument"/> for layout, and returns the rendered bytes
/// wrapped in a <see cref="PdfReportResult"/>.
/// </summary>
public sealed class DepartmentWisePdfReport : IPdfReport<DepartmentWiseParameters>
{
    static DepartmentWisePdfReport()
    {
        // QuestPDF needs a one-time license declaration per process. Set it from the
        // static ctor so the report works even when the host forgets — Community is
        // free for revenue < USD 1M / year, which fits SpinRise's internal use.
        global::QuestPDF.Settings.License = LicenseType.Community;
    }

    public string Code => "PR-DEPTWISE";

    private readonly DepartmentWiseRepository _repository;

    public DepartmentWisePdfReport(DepartmentWiseRepository repository)
        => _repository = repository;

    public async Task<PdfReportResult> GenerateAsync(
        DepartmentWiseParameters parameters, CancellationToken cancellationToken = default)
    {
        var rows = await _repository.GetRowsAsync(parameters, cancellationToken);
        return Render(rows, parameters);
    }

    /// <summary>Pure rendering path — used by the runner's --demo mode (no database).</summary>
    public PdfReportResult Render(
        IReadOnlyList<DepartmentWiseRow> rows,
        DepartmentWiseParameters parameters)
    {
        var doc   = new DepartmentWiseDocument(rows, parameters);
        var bytes = doc.GeneratePdf();
        return new PdfReportResult
        {
            Content  = bytes,
            FileName = $"PRDeptwise_{parameters.FromDate:yyyy-MM-dd}_{parameters.ToDate:yyyy-MM-dd}.pdf",
            RowCount = rows.Count,
        };
    }
}
