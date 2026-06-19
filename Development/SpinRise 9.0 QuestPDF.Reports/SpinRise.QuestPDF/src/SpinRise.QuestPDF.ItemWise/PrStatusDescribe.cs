namespace SpinRise.QuestPDF.ItemWise;

/// <summary>
/// Replicates the status CASE expression from the original <c>KSP_PR_ITEMWISE</c> stored
/// procedure, with one approved upgrade: the legacy "Fore Closed" label is emitted as the
/// SPINRISE-standard "Force Closed" (CEO #2).
/// <para>
/// SP mapping: X→Requested, O→Ordered, C→Received, Z→Force Closed,
/// D→Final Level Approved, F→First Level Approved. A null/empty/unknown code falls back to
/// "Requested" so the Status cell is never blank.
/// </para>
/// <para>
/// Note: this differs from the Department-Wise decoder, which maps X→Cancelled and adds a
/// SecondApp→"Second Level Approved" branch. Each report faithfully follows its own source
/// definition.
/// </para>
/// </summary>
internal static class PrStatusDescribe
{
    public static string Describe(string? prstatus)
    {
        if (string.IsNullOrWhiteSpace(prstatus)) return "Requested";

        return prstatus.Trim().ToUpperInvariant() switch
        {
            "X" => "Requested",
            "O" => "Ordered",
            "C" => "Received",
            "Z" => "Force Closed",          // SP says "Fore Closed"; normalized per CEO #2
            "D" => "Final Level Approved",
            "F" => "First Level Approved",
            _   => "Requested",
        };
    }
}
