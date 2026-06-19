namespace SpinRise.QuestPDF.Common.Abstractions;

/// <summary>
/// Contract every QuestPDF report implements. Reports are pluggable so the runner (and the
/// SpinRise API host) can resolve any report by its <see cref="Code"/> without knowing the
/// concrete type.
/// </summary>
public interface IPdfReport<TParameters>
{
    /// <summary>Stable identifier — used by the runner to dispatch and by the API as the route key.</summary>
    string Code { get; }

    /// <summary>Generate the PDF for the given parameters.</summary>
    Task<PdfReportResult> GenerateAsync(TParameters parameters, CancellationToken cancellationToken = default);
}
