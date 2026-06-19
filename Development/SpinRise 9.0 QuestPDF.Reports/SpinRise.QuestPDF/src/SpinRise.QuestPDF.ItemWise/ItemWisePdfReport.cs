using QuestPDF.Fluent;
using QuestPDF.Infrastructure;
using SpinRise.QuestPDF.Common.Abstractions;

namespace SpinRise.QuestPDF.ItemWise;

/// <summary>
/// Orchestrator for the Item-Wise PDF report. Pulls data via the repository, hands it to
/// <see cref="ItemWiseDocument"/> for layout, and returns the rendered bytes.
/// </summary>
public sealed class ItemWisePdfReport : IPdfReport<ItemWiseParameters>
{
    static ItemWisePdfReport()
    {
        global::QuestPDF.Settings.License = LicenseType.Community;
    }

    public string Code => "PR-ITEMWISE";

    private readonly ItemWiseRepository _repository;

    public ItemWisePdfReport(ItemWiseRepository repository) => _repository = repository;

    public async Task<PdfReportResult> GenerateAsync(
        ItemWiseParameters parameters, CancellationToken cancellationToken = default)
    {
        var rows = await _repository.GetRowsAsync(parameters, cancellationToken);
        return Render(rows, parameters);
    }

    /// <summary>Pure rendering path — used by the runner's --demo mode (no database).</summary>
    public PdfReportResult Render(IReadOnlyList<ItemWiseRow> rows, ItemWiseParameters parameters)
    {
        var doc   = new ItemWiseDocument(rows, parameters);
        var bytes = doc.GeneratePdf();
        return new PdfReportResult
        {
            Content  = bytes,
            FileName = $"PRItemwise_{parameters.FromDate:yyyy-MM-dd}_{parameters.ToDate:yyyy-MM-dd}.pdf",
            RowCount = rows.Count,
        };
    }
}
