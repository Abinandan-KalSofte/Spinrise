namespace SpinRise.Reports.DepartmentWise;

/// <summary>
/// One Purchase Requisition line, joined with its department, item and division context.
/// Column set mirrors the fields the Crystal report pulls from PO_PRH / PO_PRL / IN_ITEM / IN_DEP.
/// Final visible columns will be trimmed/ordered to match the sample layout.
/// </summary>
public sealed class DepartmentWiseRow
{
    // --- Grouping (IN_DEP) ---
    public string DepCode { get; set; } = "";
    public string DepName { get; set; } = "";

    // --- PR header (PO_PRH) ---
    public string DivCode { get; set; } = "";
    public string PrNo { get; set; } = "";
    public DateTime? PrDate { get; set; }

    // --- PR line (PO_PRL) ---
    public string PrSno { get; set; } = "";
    public DateTime? ReqdDate { get; set; }
    public string ItemCode { get; set; } = "";
    public decimal QtyIndented { get; set; }   // qtyind
    public decimal QtyReqd { get; set; }        // qtyreqd
    public decimal QtyOrdered { get; set; }     // qtyord  (null-guarded in SQL)
    public decimal QtyReceived { get; set; }    // qtyrec  (null-guarded in SQL)
    public string? PrStatusCode { get; set; }   // raw prstatus
    public string? SecondApp { get; set; }       // raw secondapp — needed by the status formula
    public string PrStatus { get; set; } = "";  // decoded via PrStatus.Describe(...)
    public string? Remarks { get; set; }
    public decimal Rate { get; set; }
    public decimal Value { get; set; }

    // --- Item master (IN_ITEM) ---
    public string ItemName { get; set; } = "";
    public string? ItemSpec { get; set; }
    public string? Uom { get; set; }

    /// <summary>Outstanding quantity (ordered but not yet received).</summary>
    public decimal QtyPending => QtyOrdered - QtyReceived;
}
