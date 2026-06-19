using System.Globalization;
using Microsoft.Extensions.Configuration;
using SpinRise.Reports.Common.Abstractions;
using SpinRise.Reports.Common.Data;
using SpinRise.Reports.ItemWise;

// ---------------------------------------------------------------------------
// Standalone runner for the Item-Wise PR report (calls dbo.KSP_PR_ITEMWISE).
//
//   dotnet run                 -> reads appsettings.json, runs the SP, writes the .xlsx
//   dotnet run -- --demo       -> writes a sample .xlsx from built-in data (NO database needed)
//   dotnet run -- --out <path> -> choose the output file
// ---------------------------------------------------------------------------

var demo = args.Contains("--demo", StringComparer.OrdinalIgnoreCase);

var config = new ConfigurationBuilder()
    .SetBasePath(AppContext.BaseDirectory)
    .AddJsonFile("appsettings.json", optional: true)
    .Build();

var parameters = new ItemWiseParameters
{
    DivCode    = config["DivCode"] ?? "01",
    FromDate   = DateTime.TryParse(config["FromDate"], out var from) ? from : new DateTime(2026, 4, 1),
    ToDate     = DateTime.TryParse(config["ToDate"],   out var to)   ? to   : new DateTime(2026, 5, 31),
    ItemFilter = string.IsNullOrWhiteSpace(config["ItemFilter"]) ? "A" : config["ItemFilter"]!,
};

var outPath = Path.GetFullPath(ArgValue("--out")
    ?? $"PRItemwise_{parameters.FromDate:yyyy-MM-dd}_{parameters.ToDate:yyyy-MM-dd}.xlsx");

try
{
    ReportResult result;

    if (demo)
    {
        Console.WriteLine("Mode: DEMO (built-in sample data, no database)");
        result = new ItemWiseReport(null!).Render(BuildDemoData(), parameters);
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

        Console.WriteLine($"Mode: LIVE | Division {parameters.DivCode} | {parameters.FromDate:yyyy-MM-dd}..{parameters.ToDate:yyyy-MM-dd} | Items {parameters.ItemFilter}");
        var repository = new ItemWiseRepository(new SqlConnectionFactory(connectionString));
        result = await new ItemWiseReport(repository).GenerateAsync(parameters);
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

string? ArgValue(string flag)
{
    var i = Array.FindIndex(args, a => string.Equals(a, flag, StringComparison.OrdinalIgnoreCase));
    return i >= 0 && i + 1 < args.Length ? args[i + 1] : null;
}

// Built-in sample: 3 items, one spanning two departments, varied (pre-decoded) statuses.
static List<ItemWiseRow> BuildDemoData()
{
    static ItemWiseRow R(string code, string name, int no, string dt, string dep, string unit,
                         decimal reqd, decimal ord, decimal rec, string status) => new()
    {
        ItemCode = code, ItemName = name, IndentNo = no,
        IndentDt = DateTime.ParseExact(dt, "dd-MM-yyyy", CultureInfo.InvariantCulture),
        DepName = dep, DivName = "ASHOK TEXTILE MILLS (P) LTD - SPG", Unit = unit,
        QtyReqd = reqd, QtyOrd = ord, QtyRec = rec, PrStatus = status,
        ReqdDate = DateTime.ParseExact(dt, "dd-MM-yyyy", CultureInfo.InvariantCulture).AddDays(7),
    };

    return new List<ItemWiseRow>
    {
        R("340A001", "ACTUATING DISC -883 431 174", 361, "09-04-2026", "AUTO CONER", "NOS", 10, 10, 10, "Received"),
        R("340A001", "ACTUATING DISC -883 431 174", 362, "09-04-2026", "AUTO CONER", "NOS", 50, 0, 0, "Final Level Approved"),
        R("340A001", "ACTUATING DISC -883 431 174", 368, "10-04-2026", "BLOW ROOM", "NOS", 20, 0, 0, "Fore Closed"),
        R("320B006", "BACK UNDER CLEARER ROLLER FOR 6 SPINDLES 079/M198", 373, "21-04-2026", "ACCOUNTS", "NOS", 2, 0, 0, "Requested"),
        R("320B006", "BACK UNDER CLEARER ROLLER FOR 6 SPINDLES 079/M198", 380, "22-04-2026", "CARDING", "NOS", 4, 4, 0, "Ordered"),
        R("890M003", "MATTRESS 72\" X 31.5\" X 3\" WITH PILLOW \"VENUS\"", 365, "09-04-2026", "MIXING", "NOS", 2, 0, 0, "Requested"),
    };
}
