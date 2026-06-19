using System.Globalization;

namespace SpinRise.QuestPDF.DepartmentWise.Sample;

/// <summary>
/// Built-in sample for runs without a database connection. Two departments, a multi-line PR
/// (#368), and every status label.
/// </summary>
public static class DepartmentWiseSampleData
{
    public static IReadOnlyList<DepartmentWiseRow> Build()
    {
        static DepartmentWiseRow R(
            string dep, string depName, string prNo, string date, string code, string name,
            string uom, decimal reqd, decimal ord, decimal rec, string status) => new()
        {
            DepCode    = dep,
            DepName    = depName,
            DivCode    = "01",
            PrNo       = prNo,
            PrDate     = DateTime.ParseExact(date, "dd-MM-yyyy", CultureInfo.InvariantCulture),
            ItemCode   = code,
            ItemName   = name,
            Uom        = uom,
            QtyReqd    = reqd,
            QtyOrdered = ord,
            QtyReceived = rec,
            PrStatus   = status,
            DivPrintName = "KALPATHARU SPINNERS PVT. LTD.",
            DivUnitName  = "UNIT - I",
        };

        var rows = new List<DepartmentWiseRow>
        {
            R("780", "ACCOUNTS",   "3",   "14-05-2026", "3400001", " 06/0 U1 UEL UDR LOOSE EXPRESS PLUS",                      "BOX", 0, 0, 0, "Ordered"),
            R("780", "ACCOUNTS",   "10",  "14-05-2026", "3400001", " 06/0 U1 UEL UDR LOOSE EXPRESS PLUS",                      "BOX", 3, 0, 0, "Force Closed"),
            R("780", "ACCOUNTS",   "12",  "19-05-2026", "8802001", " 215/75 R15 JK BRUTE LT TYRE",                             "NOS", 0, 0, 0, "Ordered"),
            R("780", "ACCOUNTS",   "12",  "19-05-2026", "730I005", " INSTALLATION ",                                           "LOT", 0, 0, 0, "Ordered"),
            R("780", "ACCOUNTS",   "15",  "20-05-2026", "3400001", " 06/0 U1 UEL UDR LOOSE EXPRESS PLUS",                      "BOX", 0, 0, 0, "Ordered"),
            R("780", "ACCOUNTS",   "37",  "22-05-2026", "3400001", " 06/0 U1 UEL UDR LOOSE EXPRESS PLUS",                      "BOX", 0, 0, 0, "Requested"),
            R("780", "ACCOUNTS",   "45",  "25-05-2026", "3400001", " 06/0 U1 UEL UDR LOOSE EXPRESS PLUS",                      "BOX", 0, 0, 0, "Requested"),
            R("780", "ACCOUNTS",   "45",  "25-05-2026", "116S001", "SEWAGE TREATMENT WITH TREATMENT CAPACITY OF 20 KLD",       "NOS", 0, 0, 0, "Requested"),

            R("010", "AUTO CONER", "361", "09-05-2026", "340A001", "ACTUATING DISC -883 431 174",                              "NOS", 10, 0, 0, "Ordered"),
            R("010", "AUTO CONER", "362", "09-05-2026", "250A001", "ADJUSTING WASHER 17 X 24 X 1.0 - 4162.014 (8500801)",       "NOS", 50, 0, 0, "Ordered"),
            R("010", "AUTO CONER", "365", "09-05-2026", "890M003", "MATTRESS 72\" X 31.5\" X 3\" WITH PILLOW \"VENUS\"",        "NOS", 2,  0, 0, "Requested"),
            R("010", "AUTO CONER", "368", "10-05-2026", "560A032", "ACTUATOR F.THERMOMETER VALVE 24VDC7 (IEC 7.7457.0)",        "NOS", 10, 10, 0, "Ordered"),
            R("010", "AUTO CONER", "368", "10-05-2026", "560R002", "(IN ACTIVE) ROTO INJECT OIL 2901052200 (20LTRS)",           "NOS", 20, 20, 20, "Received"),
            R("010", "AUTO CONER", "371", "20-05-2026", "320F006", "ACRYLIC GLASS 1067 MM X 635 MM X 3 MM",                     "NOS", 22, 22, 0, "Ordered"),
            R("010", "AUTO CONER", "373", "21-05-2026", "320B006", "BACK UNDER CLEARER ROLLER FOR 6 SPINDLES 079/M198",         "NOS", 2,  0, 0, "Final Level Approved"),
            R("010", "AUTO CONER", "375", "21-05-2026", "690U014", "UAP-AC-LR UNIFI",                                           "NOS", 1,  1, 1, "Force Closed"),
            R("010", "AUTO CONER", "380", "28-05-2026", "560A032", "ACTUATOR F.THERMOMETER VALVE",                              "NOS", 5,  0, 0, "Second Level Approved"),
            R("010", "AUTO CONER", "382", "29-05-2026", "320F006", "ACRYLIC GLASS",                                             "NOS", 1,  0, 0, "First Level Approved"),
            R("010", "AUTO CONER", "385", "30-05-2026", "560R002", "ROTO INJECT OIL",                                           "NOS", 4,  0, 0, "Cancelled"),
        };

        return rows;
    }
}
