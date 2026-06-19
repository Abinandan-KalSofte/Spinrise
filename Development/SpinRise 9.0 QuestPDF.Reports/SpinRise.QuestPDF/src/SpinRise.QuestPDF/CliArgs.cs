namespace SpinRise.QuestPDF.Host;

/// <summary>
/// Minimal flag parser for the host runner. Recognises:
/// <c>--report</c>, <c>--from</c>, <c>--to</c>, <c>--div</c>, <c>--dep</c>, <c>--out</c>, <c>--demo</c>.
/// Unknown flags are ignored so future reports can add their own without changing the host.
/// </summary>
internal sealed class CliArgs
{
    public string? Report     { get; private init; }
    public string? FromDate   { get; private init; }
    public string? ToDate     { get; private init; }
    public string? DivCode    { get; private init; }
    public string? DepCode    { get; private init; }
    public string? FromDep    { get; private init; }
    public string? ToDep      { get; private init; }
    public string? ItemFilter { get; private init; }
    public string? Output     { get; private init; }
    public bool    Demo       { get; private init; }

    public static CliArgs Parse(string[] args) => new()
    {
        Report     = Value(args, "--report"),
        FromDate   = Value(args, "--from"),
        ToDate     = Value(args, "--to"),
        DivCode    = Value(args, "--div"),
        DepCode    = Value(args, "--dep"),
        FromDep    = Value(args, "--fromdep"),
        ToDep      = Value(args, "--todep"),
        ItemFilter = Value(args, "--items"),
        Output     = Value(args, "--out"),
        Demo       = args.Any(a => string.Equals(a, "--demo", StringComparison.OrdinalIgnoreCase)),
    };

    private static string? Value(string[] args, string flag)
    {
        var i = Array.FindIndex(args, a => string.Equals(a, flag, StringComparison.OrdinalIgnoreCase));
        return i >= 0 && i + 1 < args.Length ? args[i + 1] : null;
    }
}
