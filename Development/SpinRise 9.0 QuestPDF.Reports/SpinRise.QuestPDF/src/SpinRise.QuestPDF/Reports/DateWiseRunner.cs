using Microsoft.Extensions.Configuration;
using SpinRise.QuestPDF.Common.Abstractions;
using SpinRise.QuestPDF.Common.Data;
using SpinRise.QuestPDF.DateWise;
using SpinRise.QuestPDF.DateWise.Sample;

namespace SpinRise.QuestPDF.Host.Reports;

/// <summary>
/// Host-side adapter for the Date-Wise report. Turns the parsed CLI args and
/// appsettings.json into <see cref="DateWiseParameters"/> and invokes the
/// underlying report (live or demo).
/// </summary>
internal sealed class DateWiseRunner : IReportRunner
{
    public string Code => "PR-DATEWISE";

    public async Task<PdfReportResult> RunAsync(IConfiguration config, CliArgs cli, CancellationToken ct)
    {
        // Department range follows the SP's @FrmDep/@ToDep — same convention as Department-Wise:
        // a single --dep maps to both ends; otherwise --fromdep/--todep set the range.
        var singleDep = Blank(cli.DepCode ?? config["DepCode"]);
        var fromDep   = Blank(cli.FromDep ?? config["FromDep"]) ?? singleDep;
        var toDep     = Blank(cli.ToDep   ?? config["ToDep"])   ?? singleDep;

        var parameters = new DateWiseParameters
        {
            DivCode  = cli.DivCode  ?? config["DivCode"] ?? "01",
            FromDate = ParseDate(cli.FromDate ?? config["FromDate"], new DateTime(DateTime.Today.Year, DateTime.Today.Month, 1)),
            ToDate   = ParseDate(cli.ToDate   ?? config["ToDate"],   DateTime.Today),
            FromDep  = fromDep,
            ToDep    = toDep,
        };

        if (cli.Demo)
        {
            var rows = DateWiseSampleData.Build();
            return new DateWisePdfReport(null!).Render(rows, parameters);
        }

        var connectionString = config.GetConnectionString("ScmMills")
            ?? throw new InvalidOperationException("ConnectionStrings:ScmMills is not configured.");
        var repository = new DateWiseRepository(new SqlConnectionFactory(connectionString));
        return await new DateWisePdfReport(repository).GenerateAsync(parameters, ct);
    }

    private static DateTime ParseDate(string? value, DateTime fallback)
        => DateTime.TryParse(value, out var parsed) ? parsed : fallback;

    private static string? Blank(string? v) => string.IsNullOrWhiteSpace(v) ? null : v.Trim();
}
