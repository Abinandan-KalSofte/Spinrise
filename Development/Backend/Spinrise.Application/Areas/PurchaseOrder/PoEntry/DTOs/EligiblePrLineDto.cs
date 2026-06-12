namespace Spinrise.Application.Areas.PurchaseOrder.PoEntry.DTOs;

public class EligiblePrLineDto
{
    public string  Id             { get; set; } = "";
    public decimal PrNo           { get; set; }
    public string  PrDate         { get; set; } = "";
    public decimal PrSno          { get; set; }
    public string  ItemCode       { get; set; } = "";
    public string  ItemName       { get; set; } = "";
    public string  Uom            { get; set; } = "";
    public decimal BalanceQty     { get; set; }
    public string  Department     { get; set; } = "";
    public string  SubCostCentre  { get; set; } = "";
    public string  Remarks        { get; set; } = "";
    public string  HsnCode        { get; set; } = "";
    public decimal CgstPer        { get; set; }
    public decimal SgstPer        { get; set; }
    public decimal IgstPer        { get; set; }
    public string  GstTaxCode     { get; set; } = "";
    public string  RequesterId    { get; set; } = "";
    public string  RequesterName  { get; set; } = "";
}
