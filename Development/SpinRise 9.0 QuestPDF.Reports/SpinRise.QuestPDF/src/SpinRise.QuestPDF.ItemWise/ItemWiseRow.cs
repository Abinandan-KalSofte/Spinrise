namespace SpinRise.QuestPDF.ItemWise;

/// <summary>
/// One PR line for the Item-Wise report. Column set matches the original
/// <c>KSP_PR_ITEMWISE</c> stored procedure output.
/// Quantity columns are <c>decimal?</c> so a DB NULL never breaks hydration; the renderer
/// coalesces <c>?? 0m</c> so the cell always shows "0.000".
/// </summary>
public sealed class ItemWiseRow
{
    public string    ItemCode     { get; set; } = "";
    public string    ItemName     { get; set; } = "";
    public string    IndentNo     { get; set; } = "";   // PO_PRL.prno
    public DateTime? IndentDt     { get; set; }          // PO_PRL.prdate
    public string?   DepName      { get; set; }
    public string?   DepCode      { get; set; }
    public string?   DivName      { get; set; }
    public string?   DivPrintName { get; set; }
    public string?   DivUnitName  { get; set; }
    public string?   Unit         { get; set; }          // IN_ITEM.UOM
    public decimal?  QtyReqd      { get; set; }
    public decimal?  QtyOrd       { get; set; }
    public decimal?  QtyRec       { get; set; }

    /// <summary>Raw <c>PO_PRL.prstatus</c> code (decoded by <see cref="PrStatusDescribe"/>).</summary>
    public string?   PrStatusCode { get; set; }
    public string?   SecondApp    { get; set; }
    public string?   RefNo        { get; set; }
    public string?   Remarks      { get; set; }
    public DateTime? ReqdDate     { get; set; }
    public string?   PlaceOfIss   { get; set; }

    /// <summary>Decoded SPINRISE-standard status label (filled by the repository).</summary>
    public string    PrStatus     { get; set; } = "";
}
