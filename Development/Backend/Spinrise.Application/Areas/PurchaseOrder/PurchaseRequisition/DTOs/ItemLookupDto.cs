namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;

public class ItemLookupDto
{
    public string    ItemCode  { get; set; } = "";
    public string    ItemName  { get; set; } = "";
    public string    Uom       { get; set; } = "";
    public decimal   MinLevel  { get; set; }
    public decimal   MaxLevel  { get; set; }
    public byte[]?   ItemImage { get; set; }
    public decimal?  LpoRate   { get; set; }
    public DateTime? LpoDate   { get; set; }
}
