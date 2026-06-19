using Microsoft.Extensions.Configuration;
using QuestPDF.Infrastructure;
using SpinRise.QuestPDF.Host;
using SpinRise.QuestPDF.Host.Reports;

// ---------------------------------------------------------------------------
// SpinRise.QuestPDF host runner.
//
//   dotnet run -- --report PR-DEPTWISE                       (uses appsettings.json defaults)
//   dotnet run -- --report PR-DEPTWISE --demo                (no database)
//   dotnet run -- --report PR-DEPTWISE --from 2026-05-01 --to 2026-05-31 --div 01 --dep 780 --out out.pdf
//
// The host doesn't know how to generate any specific report — it dispatches to one of the
// IReportRunner adapters registered in ReportRegistry, each of which lives in the matching
// sub-project (e.g. SpinRise.QuestPDF.DepartmentWise).
// ---------------------------------------------------------------------------

global::QuestPDF.Settings.License = LicenseType.Community;

var config = new ConfigurationBuilder()
    .SetBasePath(AppContext.BaseDirectory)
    .AddJsonFile("appsettings.json", optional: true)
    .Build();

var cli = CliArgs.Parse(args);

var requestedCode = cli.Report ?? config["DefaultReport"] ?? "PR-DEPTWISE";
var runner = ReportRegistry.Find(requestedCode);
if (runner is null)
{
    Console.Error.WriteLine($"Unknown report code: '{requestedCode}'.");
    Console.Error.WriteLine("Available reports:");
    foreach (var r in ReportRegistry.All)
        Console.Error.WriteLine($"  - {r.Code}");
    return 2;
}

Console.WriteLine($"Report : {runner.Code}");
Console.WriteLine($"Mode   : {(cli.Demo ? "DEMO (no database)" : "LIVE")}");

try
{
    var result = await runner.RunAsync(config, cli, CancellationToken.None);
    var outPath = Path.GetFullPath(cli.Output ?? result.FileName);

    Directory.CreateDirectory(Path.GetDirectoryName(outPath)!);
    await File.WriteAllBytesAsync(outPath, result.Content);

    Console.WriteLine($"Lines  : {result.RowCount}");
    Console.WriteLine($"Written: {outPath}");
    return 0;
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Failed: {ex.Message}");
    return 1;
}
