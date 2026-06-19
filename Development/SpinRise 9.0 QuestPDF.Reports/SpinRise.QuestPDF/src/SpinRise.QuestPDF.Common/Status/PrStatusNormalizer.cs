namespace SpinRise.QuestPDF.Common.Status;

/// <summary>
/// Rename any legacy PR-status label coming from a stored procedure to the SPINRISE
/// standard before display. Also surfaces a sensible label when the SP returns null/empty.
/// </summary>
public static class PrStatusNormalizer
{
    public static string Normalize(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw)) return "Requested";
        return raw switch
        {
            "Fore Closed" => "Force Closed",
            "Indent"      => "Requested",
            _             => raw,
        };
    }
}
