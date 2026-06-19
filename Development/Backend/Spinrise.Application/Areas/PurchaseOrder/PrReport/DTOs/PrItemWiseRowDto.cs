namespace Spinrise.Application.Areas.PurchaseOrder.PrReport.DTOs;

public class PrItemWiseRowDto
{
    public string    ItemCode     { get; set; } = "";
    public string    ItemName     { get; set; } = "";
    public string    IndentNo     { get; set; } = "";
    public DateTime? IndentDt     { get; set; }
    public string?   DepName      { get; set; }
    public string?   DepCode      { get; set; }
    public string?   Unit         { get; set; }
    public decimal?  QtyReqd      { get; set; }
    public decimal?  QtyOrd       { get; set; }
    public decimal?  QtyRec       { get; set; }
    public string?   PrStatus     { get; set; }
    public DateTime? ReqdDate     { get; set; }
    public string?   RefNo        { get; set; }
    public string?   Remarks      { get; set; }
    public string?   DivName      { get; set; }
    public string?   DivPrintName { get; set; }
    public string?   DivUnitName  { get; set; }
}
