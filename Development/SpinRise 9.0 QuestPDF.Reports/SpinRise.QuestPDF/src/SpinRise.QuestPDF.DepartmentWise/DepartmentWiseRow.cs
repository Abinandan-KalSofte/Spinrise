namespace SpinRise.QuestPDF.DepartmentWise;

/// <summary>
/// One PR line for the Department-Wise report. Column set matches the original
/// <c>ksp_Pr_DepWise</c> stored procedure (PO_PRH + PO_PRL + IN_DEP + PP_DIVMAS + IN_ITEM).
/// </summary>
public sealed class DepartmentWiseRow
{
    public string    DivCode      { get; set; } = "";
    public string    DepCode      { get; set; } = "";
    public string    DepName      { get; set; } = "";
    public string    PrNo         { get; set; } = "";
    public DateTime? PrDate       { get; set; }
    public string    ItemCode     { get; set; } = "";
    public string    ItemName     { get; set; } = "";
    public string    Uom          { get; set; } = "";
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
