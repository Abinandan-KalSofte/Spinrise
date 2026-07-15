namespace Spinrise.Application.Areas.PurchaseOrder.PoReport.DTOs;

public class PoItemWiseRowDto
{
    public string    ItemCode       { get; set; } = "";
    public string    ItemName       { get; set; } = "";
    public string    Uom            { get; set; } = "";
    public string    PoNo           { get; set; } = "";
    public DateTime? PoDate         { get; set; }
    public string    SupplierCode   { get; set; } = "";
    public string    SupplierName   { get; set; } = "";
    public string    DepCode        { get; set; } = "";
    public string    DepName        { get; set; } = "";
    public decimal   Rate           { get; set; }
    public decimal   QtyOrdered     { get; set; }
    public decimal   QtyReceived    { get; set; }
    public decimal   LineValue      { get; set; }
    // PO header order value (PO_ORDH.ORDVAL). The Item-Wise report's "Order Value" column binds
    // to this (once per PO); "Item Value" binds to LineValue (line PO_ORDL.ORDVAL, per line).
    public decimal   HeaderOrderValue { get; set; }
    public decimal   TaxAmount      { get; set; }
    public string    OrderType      { get; set; } = "";
    public string    QuotationNo    { get; set; } = "";
    public string    CarrierName    { get; set; } = "";
    public decimal   AdvancePercent { get; set; }
    public decimal   AdvanceAmount  { get; set; }
    public decimal   BalanceAmount  { get; set; }
    public string    PaymentMode    { get; set; } = "";
    public string    DeliveryInstructions { get; set; } = "";
    public string    SpecialInstructions  { get; set; } = "";
    public DateTime? DueDate        { get; set; }
    public int       CrdDays        { get; set; }
    public string?   ApprovalStatus { get; set; }
    public string?   DivPrintName   { get; set; }
    public string?   DivUnitName    { get; set; }
    public string    PrNo             { get; set; } = "";
}
