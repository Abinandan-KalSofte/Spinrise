namespace Spinrise.Application.Areas.PurchaseOrder.PoReport.DTOs;

public class PoSupplierWiseRowDto
{
    public string    SupplierCode   { get; set; } = "";
    public string    SupplierName   { get; set; } = "";
    public string    PoNo           { get; set; } = "";
    public string    PrNo           { get; set; } = "";
    public DateTime? PoDate         { get; set; }
    public string    QuotationNo    { get; set; } = "";
    public string    CarrierCode    { get; set; } = "";
    public string    CarrierName    { get; set; } = "";
    public string    DeliveryInstructions { get; set; } = "";
    public string    SpecialInstructions  { get; set; } = "";
    public DateTime? DueDate        { get; set; }
    public string    ItemCode       { get; set; } = "";
    public string    ItemName       { get; set; } = "";
    public string    Uom            { get; set; } = "";
    public decimal   Rate           { get; set; }
    public decimal   QtyOrdered     { get; set; }
    public decimal   LineValue      { get; set; }
    public decimal   TaxAmount      { get; set; }
    public decimal   OrderValue     { get; set; }  // PO header total
    public decimal   AdvancePercent { get; set; }
    public decimal   AdvanceAmount  { get; set; }
    public decimal   BalanceAmount  { get; set; }
    public string    PaymentMode    { get; set; } = "";
    public int       DelDays        { get; set; }
    public int       CrdDays        { get; set; }
    public string?   DivPrintName   { get; set; }
    public string?   DivUnitName    { get; set; }
}
