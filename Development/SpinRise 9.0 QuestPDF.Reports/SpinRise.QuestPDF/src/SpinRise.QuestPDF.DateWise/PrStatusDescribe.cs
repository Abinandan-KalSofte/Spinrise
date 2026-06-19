namespace SpinRise.QuestPDF.DateWise;

/// <summary>
/// Replicates the Crystal Reports status formula that runs over
/// <c>PO_PRL.prstatus</c> + <c>PO_PRL.secondapp</c>. The returned labels follow the
/// SPINRISE standard (e.g. "Force Closed", not the legacy "Fore Closed", and a null
/// status decodes to "Requested").
/// </summary>
internal static class PrStatusDescribe
{
    public static string Describe(string? prstatus, string? secondApp = null)
    {
        if (string.IsNullOrWhiteSpace(prstatus)) return "Requested";

        var code = prstatus.Trim().ToUpperInvariant();
        if (code == "O") return "Ordered";
        if (code == "C") return "Received";
        if (code == "Z") return "Force Closed";
        if (code == "D") return "Final Level Approved";

        // secondapp must be checked BEFORE the bare 'F' code or every second-level row
        // would be reported as "First Level Approved".
        if (!string.IsNullOrWhiteSpace(secondApp) && secondApp.Trim().Equals("Y", StringComparison.OrdinalIgnoreCase))
            return "Second Level Approved";

        if (code == "F") return "First Level Approved";
        if (code == "X") return "Cancelled";

        return $"Status {code}";
    }
}
