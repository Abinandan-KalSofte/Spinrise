namespace SpinRise.QuestPDF.Host.Reports;

/// <summary>
/// Central registry of every report the host knows about. Adding a new report is a
/// one-line change here plus a project reference in the .csproj.
/// </summary>
internal static class ReportRegistry
{
    public static IReadOnlyList<IReportRunner> All { get; } = new IReportRunner[]
    {
        new DepartmentWiseRunner(),
        new ItemWiseRunner(),
        new DateWiseRunner(),
    };

    public static IReportRunner? Find(string? code) =>
        string.IsNullOrWhiteSpace(code)
            ? null
            : All.FirstOrDefault(r => string.Equals(r.Code, code, StringComparison.OrdinalIgnoreCase));
}
