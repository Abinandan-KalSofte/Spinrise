namespace Spinrise.Application.Areas.PurchaseOrder.PendingPrReport.DTOs;

public class PendingPrDateWiseRowDto
{
    public string    PrNo         { get; set; } = "";
    public DateTime? PrDate       { get; set; }
    public DateTime? App3Date     { get; set; }
    public string    ItemCode     { get; set; } = "";
    public string    ItemName     { get; set; } = "";
    public string    Uom          { get; set; } = "";
    public string    DepName      { get; set; } = "";
    public decimal   QtyReqd      { get; set; }
    public decimal   QtyOrdered   { get; set; }
    public decimal   QtyReceived  { get; set; }
    public DateTime? ReqdDate     { get; set; }
    public string?   DivPrintName { get; set; }
    public string?   DivUnitName  { get; set; }
}
