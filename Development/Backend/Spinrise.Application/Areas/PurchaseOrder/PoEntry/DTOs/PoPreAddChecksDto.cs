namespace Spinrise.Application.Areas.PurchaseOrder.PoEntry.DTOs;

public class PoPreAddChecksDto
{
    public bool    ApprovedPrLinesExist { get; set; }
    public bool    DocParaExists        { get; set; }
    public string  BackDateFlag         { get; set; } = "";
    public string? MaxPoDate            { get; set; }
}
