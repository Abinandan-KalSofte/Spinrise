namespace Spinrise.Application.Areas.PurchaseOrder.PrReport.DTOs;

public class PrDateWiseRowDto
{
    public DateTime? PrDate       { get; set; }
    public string    PrNo         { get; set; } = "";
    public string    ItemCode     { get; set; } = "";
    public string    ItemName     { get; set; } = "";
    public string    Uom          { get; set; } = "";
    public string    DepName      { get; set; } = "";
    public decimal   QtyIndent    { get; set; }
    public decimal   QtyReqd      { get; set; }
    public decimal   QtyOrdered   { get; set; }
    public decimal   QtyReceived  { get; set; }
    public string?   PrStatusCode { get; set; }
    public string?   SecondApp    { get; set; }
    public string?   DivPrintName { get; set; }
    public string?   DivUnitName  { get; set; }
    public string    PrStatus     { get; set; } = "";
}
