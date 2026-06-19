namespace SpinRise.QuestPDF.DateWise;

/// <summary>
/// One PR line for the Date-Wise report. Column set matches the <c>KSP_PR_DateWise</c>
/// stored procedure (PO_PRH + PO_PRL + IN_DEP + PP_DIVMAS + IN_ITEM) — including
/// <c>qtyind</c> (Indent Quantity), which the other PR reports do not carry.
/// </summary>
public sealed class DateWiseRow
{
    public DateTime? PrDate       { get; set; }
    public string    PrNo         { get; set; } = "";
    public string    ItemCode     { get; set; } = "";
    public string    ItemName     { get; set; } = "";
    public string    Uom          { get; set; } = "";
    public string    DepName      { get; set; } = "";
    public decimal   QtyIndent    { get; set; }   // PO_PRL.qtyind
    public decimal   QtyReqd      { get; set; }
    public decimal   QtyOrdered   { get; set; }
    public decimal   QtyReceived  { get; set; }

    /// <summary><c>PP_DIVMAS.div_printname</c> — the report title (company print name).</summary>
    public string?   DivPrintName { get; set; }
    /// <summary><c>PP_DIVMAS.div_unitname</c> — the "(Unit - …)" sub-title.</summary>
    public string?   DivUnitName  { get; set; }

    /// <summary>Raw <c>PO_PRL.prstatus</c> code as stored in the database.</summary>
    public string?   PrStatusCode { get; set; }
    /// <summary>Raw <c>PO_PRL.secondapp</c> flag — needed by the Crystal status formula.</summary>
    public string?   SecondApp    { get; set; }
    /// <summary>Decoded SPINRISE-standard label (filled by <see cref="PrStatusDescribe.Describe"/>).</summary>
    public string    PrStatus     { get; set; } = "";
}
