namespace SpinRise.Reports.ItemWise;

/// <summary>
/// One row returned by dbo.KSP_PR_ITEMWISE. Property names match the SP's output columns
/// (Dapper matches case-insensitively), so unused columns like DIV_PRINTNAME are simply skipped.
/// </summary>
public sealed class ItemWiseRow
{
    public string ItemCode { get; set; } = "";  // itemcode  (group key)
    public string ItemName { get; set; } = "";  // ITEMNAME
    public int IndentNo { get; set; }            // Indentno  (PR number)
    public DateTime? IndentDt { get; set; }      // Indentdt  (PR date)
    public string? DepName { get; set; }         // DEPNAME
    public string? DepCode { get; set; }         // depcode
    public string? DivName { get; set; }         // DIVNAME   (company banner)
    public string? Unit { get; set; }            // unit      (IN_ITEM.UOM)
    // Nullable so a DB NULL from KSP_PR_ITEMWISE doesn't crash Dapper hydration.
    // The renderer coalesces to 0m before writing the cell (CEO #3 belt-and-braces
    // for the case where the SP hasn't been ISNULL-ALTERed yet).
    public decimal? QtyReqd { get; set; }        // qtyreqd
    public decimal? QtyOrd  { get; set; }        // qtyord
    public decimal? QtyRec  { get; set; }        // qtyrec
    public string? PrStatus { get; set; }        // prstatus  (ALREADY decoded to text by the SP)
    public string? SecondApp { get; set; }       // SecondApp
    public string? RefNo { get; set; }           // refno
    public string? Remarks { get; set; }         // remarks
    public DateTime? ReqdDate { get; set; }      // reqddate
    public string? PlaceOfIss { get; set; }      // PLACEOFISS
}
