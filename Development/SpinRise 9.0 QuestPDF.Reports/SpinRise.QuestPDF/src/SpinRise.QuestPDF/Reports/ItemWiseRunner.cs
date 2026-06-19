using Microsoft.Extensions.Configuration;
using SpinRise.QuestPDF.Common.Abstractions;
using SpinRise.QuestPDF.Common.Data;
using SpinRise.QuestPDF.ItemWise;
using SpinRise.QuestPDF.ItemWise.Sample;

namespace SpinRise.QuestPDF.Host.Reports;

/// <summary>
/// Host-side adapter for the Item-Wise report. Turns the parsed CLI args and appsettings.json
/// into <see cref="ItemWiseParameters"/> and invokes the report (live or demo).
/// </summary>
internal sealed class ItemWiseRunner : IReportRunner
{
    public string Code => "PR-ITEMWISE";

    public async Task<PdfReportResult> RunAsync(IConfiguration config, CliArgs cli, CancellationToken ct)
    {
        var parameters = new ItemWiseParameters
        {
            DivCode    = cli.DivCode  ?? config["DivCode"] ?? "01",
            FromDate   = ParseDate(cli.FromDate ?? config["FromDate"], new DateTime(DateTime.Today.Year, DateTime.Today.Month, 1)),
            ToDate     = ParseDate(cli.ToDate   ?? config["ToDate"],   DateTime.Today),
            ItemFilter = string.IsNullOrWhiteSpace(cli.ItemFilter ?? config["ItemFilter"]) ? "A" : (cli.ItemFilter ?? config["ItemFilter"])!,
        };

        if (cli.Demo)
            return new ItemWisePdfReport(null!).Render(ItemWiseSampleData.Build(), parameters);

        var connectionString = config.GetConnectionString("ScmMills")
            ?? throw new InvalidOperationException("ConnectionStrings:ScmMills is not configured.");
        var repository = new ItemWiseRepository(new SqlConnectionFactory(connectionString));
        return await new ItemWisePdfReport(repository).GenerateAsync(parameters, ct);
    }

    private static DateTime ParseDate(string? value, DateTime fallback)
        => DateTime.TryParse(value, out var parsed) ? parsed : fallback;
}
