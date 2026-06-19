using Microsoft.Extensions.Configuration;
using SpinRise.QuestPDF.Common.Abstractions;

namespace SpinRise.QuestPDF.Host.Reports;

/// <summary>
/// Adapter contract for the host runner: each sub-project ships one of these so the host
/// can dispatch by <see cref="Code"/> without knowing the report's parameter type.
/// </summary>
internal interface IReportRunner
{
    string Code { get; }
    Task<PdfReportResult> RunAsync(IConfiguration config, CliArgs cli, CancellationToken ct);
}
