using System.Globalization;

namespace SpinRise.QuestPDF.ItemWise.Sample;

/// <summary>
/// Built-in sample for runs without a database. Covers three items (one spanning multiple
/// departments) and every status colour, so item subtotals and the grand total are exercised.
/// </summary>
public static class ItemWiseSampleData
{
    public static IReadOnlyList<ItemWiseRow> Build()
    {
        static ItemWiseRow R(string code, string name, string no, string dt, string dep, string unit,
                             decimal reqd, decimal ord, decimal rec, string status) => new()
        {
            ItemCode = code, ItemName = name, IndentNo = no,
            IndentDt = DateTime.ParseExact(dt, "dd-MM-yyyy", CultureInfo.InvariantCulture),
            DepName = dep, DivPrintName = "KALPATHARU SPINNERS PVT. LTD.", Unit = unit,
            QtyReqd = reqd, QtyOrd = ord, QtyRec = rec, PrStatus = status,
            ReqdDate = DateTime.ParseExact(dt, "dd-MM-yyyy", CultureInfo.InvariantCulture).AddDays(7),
        };

        return new List<ItemWiseRow>
        {
            R("1104001", "WOVEN SACK PP 48\"X108\" PLAIN", "16", "20-05-2026", "MIXING",     "NOS", 0,  0,  0,  "Requested"),
            R("1104001", "WOVEN SACK PP 48\"X108\" PLAIN", "31", "22-05-2026", "BALE PRESS", "NOS", 5,  5,  0,  "Ordered"),
            R("1104001", "WOVEN SACK PP 48\"X108\" PLAIN", "33", "23-05-2026", "BLOW ROOM",  "NOS", 2,  2,  2,  "Received"),
            R("1104001", "WOVEN SACK PP 48\"X108\" PLAIN", "58", "31-05-2026", "BLOW ROOM",  "NOS", 3,  0,  0,  "Force Closed"),

            R("340A001", "ACTUATING DISC -883 431 174",   "361", "09-05-2026", "AUTO CONER", "NOS", 10, 10, 10, "Received"),
            R("340A001", "ACTUATING DISC -883 431 174",   "362", "09-05-2026", "AUTO CONER", "NOS", 50, 0,  0,  "Final Level Approved"),
            R("340A001", "ACTUATING DISC -883 431 174",   "380", "28-05-2026", "CARDING",    "NOS", 20, 0,  0,  "First Level Approved"),

            R("890M003", "MATTRESS 72\" X 31.5\" X 3\" WITH PILLOW \"VENUS\"", "365", "09-05-2026", "MIXING", "NOS", 2, 0, 0, "Requested"),
        };
    }
}
