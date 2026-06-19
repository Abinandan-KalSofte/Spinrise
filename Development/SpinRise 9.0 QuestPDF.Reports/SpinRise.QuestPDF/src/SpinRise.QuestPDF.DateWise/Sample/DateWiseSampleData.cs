using System.Globalization;

namespace SpinRise.QuestPDF.DateWise.Sample;

/// <summary>
/// Built-in sample for runs without a database connection. Three PR dates, multiple
/// departments per date, and every status label.
/// </summary>
public static class DateWiseSampleData
{
    public static IReadOnlyList<DateWiseRow> Build()
    {
        static DateWiseRow R(
            string date, string prNo, string code, string name, string uom, string depName,
            decimal ind, decimal reqd, decimal ord, decimal rec, string status) => new()
        {
            PrDate      = DateTime.ParseExact(date, "dd-MM-yyyy", CultureInfo.InvariantCulture),
            PrNo        = prNo,
            ItemCode    = code,
            ItemName    = name,
            Uom         = uom,
            DepName     = depName,
            QtyIndent   = ind,
            QtyReqd     = reqd,
            QtyOrdered  = ord,
            QtyReceived = rec,
            PrStatus    = status,
            DivPrintName = "KALPATHARU SPINNERS PVT. LTD.",
            DivUnitName  = "UNIT - I",
        };

        return new List<DateWiseRow>
        {
            R("14-05-2025", "86",  "120R002", "RAPPID SCAN -X4 CONTAMINATION MESH BAG -950*3300",   "NOS", "BLOW ROOM",  2,  2,  2,  2, "Received"),
            R("14-05-2025", "87",  "3400001", "06/0 U1 UEL UDR LOOSE EXPRESS PLUS",                 "BOX", "ACCOUNTS",   0,  3,  0,  0, "Ordered"),
            R("14-05-2025", "88",  "8601002", "1\" CI COLLER",                                       "NOS", "CIVIL",      5,  5,  5,  0, "First Level Approved"),

            R("19-05-2025", "100", "460S010", "SEALING TAPE 7250 X 80MM",                            "NOS", "BLOW ROOM",  3,  3,  3,  3, "Received"),
            R("19-05-2025", "101", "8802001", "215/75 R15 JK BRUTE LT TYRE",                         "NOS", "VEHICLE",    1,  1,  0,  0, "Force Closed"),
            R("19-05-2025", "101", "730I005", "INSTALLATION",                                        "LOT", "VEHICLE",    1,  0,  0,  0, "Requested"),

            R("28-05-2025", "126", "150F005", "FLEXIBLE PU HOSE 152 MM TRANSPARENT",                 "MTR", "CARDING",   15, 15, 15, 15, "Received"),
            R("28-05-2025", "128", "150C004", "CENTURA S.TOPS FD 14A(SCREW TYPE-1010)",              "NOS", "CARDING",   54, 54, 54, 54, "Received"),
            R("28-05-2025", "128", "150L002", "LICKERIN WIRE-TRIANGULAM-E5510X1.2-6.5",              "ROL", "CARDING",  150,150,150,150, "Received"),
            R("28-05-2025", "129", "150C007", "CENTURA S.TOPS FD 64A (SCREW TYPA-1010)",             "NOS", "CARDING",   80, 80, 80, 72, "Second Level Approved"),
            R("28-05-2025", "130", "150B004", "BORDER WIRE 1501",                                    "ROL", "CARDING",    4,  4,  0,  0, "Cancelled"),
            R("28-05-2025", "131", "150D001", "DOFFER WIRE M 4030E X 0.8 EVOLV-2X",                  "ROL", "CARDING",    2,  2,  2,  0, "Final Level Approved"),
        };
    }
}
