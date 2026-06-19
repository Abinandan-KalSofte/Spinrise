namespace SpinRise.Reports.DepartmentWise;

/// <summary>
/// Replicates the original Crystal status formula on {PO_PRL.prstatus} (+ {PO_PRL.secondapp}),
/// supplied verbatim by the report owner:
///
///     if isNull(prstatus)                    -> "Requested"
///     else if prstatus = 'O'                 -> "Ordered"
///     else if prstatus = 'C'                 -> "Received"
///     else if prstatus = 'Z'                 -> "Force Closed"  (SPINRISE standard label)
///     else if prstatus = 'D'                 -> "Final Level Approved"
///     else if secondapp not null & = 'Y'     -> "Second Level Approved"
///     else if prstatus = 'F'                 -> "First Level Approved"
///     else if prstatus = 'X'                 -> "Cancelled"
///
/// Order matters: the secondapp='Y' test deliberately runs *before* the 'F' test.
/// </summary>
public static class PrStatus
{
    public static string Describe(string? prstatus, string? secondApp = null)
    {
        if (string.IsNullOrWhiteSpace(prstatus)) return "Requested";

        var code = prstatus.Trim().ToUpperInvariant();
        if (code == "O") return "Ordered";
        if (code == "C") return "Received";
        if (code == "Z") return "Force Closed";
        if (code == "D") return "Final Level Approved";

        if (!string.IsNullOrWhiteSpace(secondApp) && secondApp.Trim().ToUpperInvariant() == "Y")
            return "Second Level Approved";

        if (code == "F") return "First Level Approved";
        if (code == "X") return "Cancelled";

        return $"Status {code}"; // not covered by the original formula — surface rather than hide
    }
}
