using QuestPDF.Fluent;
using QuestPDF.Infrastructure;
using SpinRise.QuestPDF.Common.Abstractions;

namespace SpinRise.QuestPDF.DateWise;

/// <summary>
/// Orchestrator for the Date-Wise PDF report. Pulls data via the repository, hands it to
/// <see cref="DateWiseDocument"/> for layout, and returns the rendered bytes wrapped in a
/// <see cref="PdfReportResult"/>.
/// </summary>
public sealed class DateWisePdfReport : IPdfReport<DateWiseParameters>
{
    static DateWisePdfReport()
    {
        // QuestPDF needs a one-time license declaration per process. Set it from the
        // static ctor so the report works even when the host forgets — Community is
        // free for revenue < USD 1M / year, which fits SpinRise's internal use.
        global::QuestPDF.Settings.License = LicenseType.Community;
    }

    public string Code => "PR-DATEWISE";

    private readonly DateWiseRepository _repository;

    public DateWisePdfReport(DateWiseRepository repository)
        => _repository = repository;

    public async Task<PdfReportResult> GenerateAsync(
        DateWiseParameters parameters, CancellationToken cancellationToken = default)
    {
        var rows = await _repository.GetRowsAsync(parameters, cancellationToken);
        return Render(rows, parameters);
    }

    /// <summary>Pure rendering path — used by the runner's --demo mode (no database).</summary>
    public PdfReportResult Render(
        IReadOnlyList<DateWiseRow> rows,
        DateWiseParameters parameters)
    {
        var doc   = new DateWiseDocument(rows, parameters);
        var bytes = doc.GeneratePdf();
        return new PdfReportResult
        {
            Content  = bytes,
            FileName = $"PRDatewise_{parameters.FromDate:yyyy-MM-dd}_{parameters.ToDate:yyyy-MM-dd}.pdf",
            RowCount = rows.Count,
        };
    }
}
