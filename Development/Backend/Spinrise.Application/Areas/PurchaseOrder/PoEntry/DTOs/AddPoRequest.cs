using System.ComponentModel.DataAnnotations;

namespace Spinrise.Application.Areas.PurchaseOrder.PoEntry.DTOs;

public class AddPoRequest
{
    [Required]
    public DateOnly PoDate { get; init; }

    [Required]
    public AddPoHeaderRequest Header { get; init; } = new();

    [Required]
    [MinLength(1)]
    public List<AddPoLineRequest> Lines { get; init; } = [];
}

public class AddPoHeaderRequest
{
    [Required] public DateOnly PoDate   { get; init; }

    [Required][MaxLength(5)]  public string OrderType     { get; init; } = "";
    [Required][MaxLength(10)] public string Supplier      { get; init; } = "";
    [Required][MaxLength(3)]  public string Currency      { get; init; } = "";
    [Required][MaxLength(10)] public string Carrier       { get; init; } = "";

    public string   OrderTypeDesc { get; init; } = "";
    public string   SupplierName  { get; init; } = "";
    public string   Gstin         { get; init; } = "";
    public string   GstState      { get; init; } = "";
    public string   Inspect       { get; init; } = "";
    public decimal  CurrRate      { get; init; }
    public string   FormType      { get; init; } = "";
    public string   RefNo         { get; init; } = "";
    public DateOnly? RefDate      { get; init; }
    public string   Remarks       { get; init; } = "";
    // Tax / Discount
    public decimal CgstPer      { get; init; }
    public decimal SgstPer      { get; init; }
    public decimal IgstPer      { get; init; }
    public decimal TcsPer       { get; init; }
    public decimal DiscPer      { get; init; }
    public decimal CessPer      { get; init; }
    public decimal AedPer       { get; init; }
    public decimal FreightAmt   { get; init; }
    public decimal PackPer      { get; init; }
    public decimal InsurPer     { get; init; }
    public decimal SurchargePer { get; init; }
    public decimal AddTaxPer    { get; init; }
    public string  FileNo       { get; init; } = "";
    public decimal FcaFob       { get; init; }
    public string  FreightType  { get; init; } = "PAID";
    public string  DiscApp      { get; init; } = "BEFORE";
    public string  PackApp      { get; init; } = "BEFORE";
    public string  FreightApp   { get; init; } = "BEFORE";
    public string  InsurApp     { get; init; } = "BEFORE";
    public string  CessApp      { get; init; } = "BEFORE";
    // Payment
    public string   PayMode       { get; init; } = "DIRECT";
    public string   DirectInstr   { get; init; } = "";
    public string   BankCode      { get; init; } = "";
    public string   PaymentTerms  { get; init; } = "";
    public decimal  AdvPer        { get; init; }
    public decimal  AdvAmt        { get; init; }
    public string   ModeOfPayment { get; init; } = "";
    public string   PayRef        { get; init; } = "";
    public DateOnly? PayRefDate   { get; init; }
    public string   ChequeNo      { get; init; } = "";
    public DateOnly? ChequeDate   { get; init; }
    // Instructions
    public int      CreditDays       { get; init; }
    public DateOnly? DeliveryDate    { get; init; }
    public string   DeliveryLocation { get; init; } = "";
    public string   BillingAddress   { get; init; } = "";
    public string   SpecialInstr     { get; init; } = "";
    public string   Despatch         { get; init; } = "";
    public string   Purpose          { get; init; } = "";
    public string   OtherLevies      { get; init; } = "";
    public string   PricingTerms     { get; init; } = "";
    public string   PackForwarding   { get; init; } = "";
    public string   Insurance        { get; init; } = "";
    public string   Freight          { get; init; } = "";
}

public class AddPoLineRequest
{
    [Required] public decimal  PrNo    { get; init; }
    [Required] public decimal  PrSno   { get; init; }
    [Required] public DateOnly PrDate  { get; init; }
    [Required][MaxLength(10)] public string ItemCode { get; init; } = "";
    [Range(0.0001, double.MaxValue)] public decimal Rate   { get; init; }
    [Range(0.0001, double.MaxValue)] public decimal Qty    { get; init; }
    [Required][MaxLength(10)] public string TaxCode  { get; init; } = "";
    public string  HsnCode   { get; init; } = "";
    public decimal CgstPer   { get; init; }
    public decimal SgstPer   { get; init; }
    public decimal IgstPer   { get; init; }
    public decimal TcsPer    { get; init; }
    public string  CgstCode  { get; init; } = "";
    public string  SgstCode  { get; init; } = "";
    public string  IgstCode  { get; init; } = "";
    public string  Route         { get; init; } = "LOCAL";
    public string  RequesterId   { get; init; } = "";
    public string  RequesterName { get; init; } = "";
    public decimal LandCost      { get; init; }

    [MinLength(0)]
    public List<DeliverySlotRequest> Slots { get; init; } = [];
}

public class DeliverySlotRequest
{
    public int      SlotNo  { get; init; }
    public DateOnly? ShDate { get; init; }
    public decimal   Qty    { get; init; }
    public string    Remarks { get; init; } = "";
}
