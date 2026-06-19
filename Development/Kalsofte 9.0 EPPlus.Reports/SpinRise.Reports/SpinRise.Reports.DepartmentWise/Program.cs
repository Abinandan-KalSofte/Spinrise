using System.Globalization;
using Microsoft.Extensions.Configuration;
using SpinRise.Reports.Common.Abstractions;
using SpinRise.Reports.Common.Data;
using SpinRise.Reports.Common.Models;
using SpinRise.Reports.DepartmentWise;

// ---------------------------------------------------------------------------
// Standalone runner for the Department-Wise PR report.
//
//   dotnet run                 -> reads appsettings.json, queries the DB, writes the .xlsx
//   dotnet run -- --demo       -> writes a sample .xlsx from built-in data (NO database needed)
//   dotnet run -- --out <path> -> choose the output file
// ---------------------------------------------------------------------------

var demo = args.Contains("--demo", StringComparer.OrdinalIgnoreCase);

var config = new ConfigurationBuilder()
    .SetBasePath(AppContext.BaseDirectory)
    .AddJsonFile("appsettings.json", optional: true)
    .Build();

var parameters = new DepartmentWiseParameters
{
    DivCode  = config["DivCode"] ?? "01",
    FromDate = DateTime.TryParse(config["FromDate"], out var from) ? from : new DateTime(2026, 4, 1),
    ToDate   = DateTime.TryParse(config["ToDate"],   out var to)   ? to   : new DateTime(2026, 4, 24),
    DepCode  = string.IsNullOrWhiteSpace(config["DepCode"]) ? null : config["DepCode"],
};

var outPath = Path.GetFullPath(ArgValue("--out")
    ?? $"PRDeptwise_{parameters.FromDate:yyyy-MM-dd}_{parameters.ToDate:yyyy-MM-dd}.xlsx");

try
{
    ReportResult result;

    if (demo)
    {
        Console.WriteLine("Mode: DEMO (built-in sample data, no database)");
        var (company, rows) = BuildDemoData();
        result = new DepartmentWiseReport(null!).Render(company, rows, parameters);
    }
    else
    {
        var connectionString = config.GetConnectionString("ScmMills");
        if (string.IsNullOrWhiteSpace(connectionString) || connectionString.Contains("SERVER\\INSTANCE"))
        {
            Console.Error.WriteLine("No real connection string yet. Set ConnectionStrings:ScmMills in appsettings.json,");
            Console.Error.WriteLine("or generate a no-database sample:  dotnet run -- --demo");
            return 1;
        }

        Console.WriteLine($"Mode: LIVE | Division {parameters.DivCode} | {parameters.FromDate:yyyy-MM-dd}..{parameters.ToDate:yyyy-MM-dd} | Dept {parameters.DepCode ?? "ALL"}");
        var repository = new DepartmentWiseRepository(new SqlConnectionFactory(connectionString));
        result = await new DepartmentWiseReport(repository).GenerateAsync(parameters);
    }

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

// reads "--out <value>" from the command line
string? ArgValue(string flag)
{
    var i = Array.FindIndex(args, a => string.Equals(a, flag, StringComparison.OrdinalIgnoreCase));
    return i >= 0 && i + 1 < args.Length ? args[i + 1] : null;
}

// Built-in sample mirroring the DateWise reference: 2 departments, a multi-line PR (368), varied status.
static (CompanyHeader, List<DepartmentWiseRow>) BuildDemoData()
{
    var company = new CompanyHeader { DivCode = "01", DivName = "ASHOK TEXTILE MILLS (P) LTD - SPG" };

    static DepartmentWiseRow Row(string dep, string depName, string prNo, string date, string code, string name,
                                 string uom, decimal reqd, decimal ord, decimal rec, string status) => new()
    {
        DepCode = dep, DepName = depName, DivCode = "01",
        PrNo = prNo, PrDate = DateTime.ParseExact(date, "dd-MM-yyyy", CultureInfo.InvariantCulture),
        ItemCode = code, ItemName = name, Uom = uom,
        QtyReqd = reqd, QtyOrdered = ord, QtyReceived = rec,
        PrStatus = status,
    };

    var rows = new List<DepartmentWiseRow>
    {
        Row("ACON", "AUTO CONER", "361", "09-04-2026", "340A001", "ACTUATING DISC -883 431 174", "NOS", 10, 0, 0, "Ordered"),
        Row("ACON", "AUTO CONER", "362", "09-04-2026", "250A001", "ADJUSTING WASHER 17 X 24 X 1.0 - 4162.014 ( 8500801 )", "NOS", 50, 0, 0, "Ordered"),
        Row("ACON", "AUTO CONER", "365", "09-04-2026", "890M003", "MATTRESS 72\" X 31.5\" X 3\" WITH PILLOW \"VENUS\"", "NOS", 2, 0, 0, "Requested"),
        Row("ACON", "AUTO CONER", "368", "10-04-2026", "560A032", "ACTUATOR F.THERMOMETER VALVE 24VDC7 (IEC 7.7457.0)", "NOS", 10, 10, 0, "Ordered"),
        Row("ACON", "AUTO CONER", "368", "10-04-2026", "560R002", "(IN ACTIVE) ROTO INJECT OIL 2901052200 (20LTRS)", "NOS", 20, 20, 20, "Received"),
        Row("ACCT", "ACCOUNTS", "371", "20-04-2026", "320F006", "ACRYLIC GLASS 1067 MM X 635 MM X 3 MM", "NOS", 22, 22, 0, "Ordered"),
        Row("ACCT", "ACCOUNTS", "373", "21-04-2026", "320B006", "BACK UNDER CLEARER ROLLER FOR 6 SPINDLES 079/M198", "NOS", 2, 0, 0, "Final Level Approved"),
        Row("ACCT", "ACCOUNTS", "375", "21-04-2026", "690U014", "UAP-AC-LR UNIFI", "NOS", 1, 1, 1, "Fore Closed"),
    };
    return (company, rows);
}
