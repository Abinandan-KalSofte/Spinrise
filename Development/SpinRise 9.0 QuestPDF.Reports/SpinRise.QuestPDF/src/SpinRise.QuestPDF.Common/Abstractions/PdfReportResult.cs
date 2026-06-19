namespace SpinRise.QuestPDF.Common.Abstractions;

/// <summary>
/// Output of a single report run: PDF bytes, a suggested filename and a row count for logging.
/// Content type is fixed because every report in this solution is PDF.
/// </summary>
public sealed class PdfReportResult
{
    public required byte[] Content  { get; init; }
    public required string FileName { get; init; }
    public int RowCount { get; init; }
    public string ContentType => "application/pdf";
}
