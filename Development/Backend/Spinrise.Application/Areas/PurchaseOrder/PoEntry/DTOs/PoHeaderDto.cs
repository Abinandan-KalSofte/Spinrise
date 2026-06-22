namespace Spinrise.Application.Areas.PurchaseOrder.PoEntry.DTOs;

public class DeliverySlotDto
{
    public int      SlotNo  { get; set; }
    public string?  ShDate  { get; set; }
    public decimal  Qty     { get; set; }
    public string   Remarks { get; set; } = "";
}

public class DeliveryScheduleLineDto
{
    public int                   LineNo   { get; set; }
    public string                ItemCode { get; set; } = "";
    public string                ItemName { get; set; } = "";
    public string                Uom      { get; set; } = "";
    public decimal               PrNo     { get; set; }
    public decimal               PoQty    { get; set; }
    public List<DeliverySlotDto> Slots    { get; set; } = [];
}

public class PoLineDto
{
    public int     LineNo        { get; set; }
    public decimal PrSno         { get; set; }
    public string  ItemCode      { get; set; } = "";
    public string  ItemName      { get; set; } = "";
    public string  Uom           { get; set; } = "";
    public decimal PrNo          { get; set; }
    public string  PrDate        { get; set; } = "";
    public decimal Rate          { get; set; }
    public decimal Qty           { get; set; }
    public decimal BalanceQty    { get; set; }
    public decimal Value         { get; set; }
    public string  TaxCode       { get; set; } = "";
    public decimal TaxPer        { get; set; }
    public decimal TaxAmt        { get; set; }
    public string  HsnCode       { get; set; } = "";
    public decimal CgstPer       { get; set; }
    public decimal CgstAmt       { get; set; }
    public decimal SgstPer       { get; set; }
    public decimal SgstAmt       { get; set; }
    public decimal IgstPer       { get; set; }
    public decimal IgstAmt       { get; set; }
    public decimal TcsPer        { get; set; }
    public decimal TcsAmt        { get; set; }
    public string  CgstCode      { get; set; } = "";
    public string  SgstCode      { get; set; } = "";
    public string  IgstCode      { get; set; } = "";
    public string  RequesterId   { get; set; } = "";
    public string  RequesterName { get; set; } = "";
    public string  Route         { get; set; } = "LOCAL";
    public string  DeleteReason  { get; set; } = "";
    public decimal DiscPer       { get; set; }
    public decimal DiscAmt       { get; set; }
    public decimal PackingPer    { get; set; }
    public decimal PackingAmt    { get; set; }
    public decimal FreightPer    { get; set; }
    public decimal FreightAmt    { get; set; }
    public decimal InsurancePer  { get; set; }
    public decimal InsuranceAmt  { get; set; }
    public decimal CessPer       { get; set; }
    public decimal CessAmt       { get; set; }
    public string  AddTaxCode    { get; set; } = "";
    public decimal AddTaxPer     { get; set; }
    public decimal AddTaxAmt     { get; set; }
    public decimal FcaFob        { get; set; }
    public decimal OtherCharges  { get; set; }
    public string  DiscApp       { get; set; } = "BEFORE";
    public string  PackApp       { get; set; } = "BEFORE";
    public string  FreightPos    { get; set; } = "BEFORE";
    public string  InsuranceDuty { get; set; } = "BEFORE";
    public string  CessTaxPos    { get; set; } = "BEFORE";
    public decimal NetAmount     { get; set; }
}

public class PoHeaderDto
{
    public string   DivCode       { get; set; } = "";
    public decimal? PoNo          { get; set; }
    public string   PoDate        { get; set; } = "";
    public string   OrderType     { get; set; } = "";
    public string   OrderTypeDesc { get; set; } = "";
    public string   Supplier      { get; set; } = "";
    public string   SupplierName  { get; set; } = "";
    public string   Gstin         { get; set; } = "";
    public string   GstState      { get; set; } = "";
    public string   Inspect       { get; set; } = "";
    public decimal  RoundOff      { get; set; }
    public decimal  OrderValue    { get; set; }
    public string   FormType      { get; set; } = "";
    public string   RefNo         { get; set; } = "";
    public string?  RefDate       { get; set; }
    public string   Currency      { get; set; } = "";
    public decimal  CurrRate      { get; set; }
    public string   Remarks       { get; set; } = "";
    // Tax / Discount (header)
    public decimal CgstPer      { get; set; }
    public decimal SgstPer      { get; set; }
    public decimal IgstPer      { get; set; }
    public decimal TcsPer       { get; set; }
    public decimal DiscPer      { get; set; }
    public decimal CessPer      { get; set; }
    public decimal AedPer       { get; set; }
    public decimal FreightAmt   { get; set; }
    public decimal PackPer      { get; set; }
    public decimal InsurPer     { get; set; }
    public decimal SurchargePer { get; set; }
    public decimal AddTaxPer    { get; set; }
    public string  FileNo       { get; set; } = "";
    public decimal FcaFob       { get; set; }
    public string  FreightType          { get; set; } = "PAID";
    public string  DiscApp              { get; set; } = "BEFORE";
    public string  PackApp              { get; set; } = "BEFORE";
    public string  FreightPosition      { get; set; } = "BEFORE";
    public string  InsurancePosition    { get; set; } = "BEFORE";
    public string  CessPosition         { get; set; } = "BEFORE";
    // Charge amounts: PackingAmt/InsuranceAmt stored in DB; others derived from % in SP
    public decimal PackingAmt          { get; set; }
    public decimal InsuranceAmt        { get; set; }
    public decimal DiscountAmt         { get; set; }
    public decimal CessAmt             { get; set; }
    public decimal AddTaxAmt           { get; set; }
    // Payment
    public string  PayMode          { get; set; } = "DIRECT";
    public string  DirectInstr      { get; set; } = "";
    public string  BankCode         { get; set; } = "";
    public string  PaymentTerms     { get; set; } = "";
    public string  PaymentTermCode  { get; set; } = "";
    public decimal AdvPer        { get; set; }
    public decimal AdvAmt        { get; set; }
    public string  ModeOfPayment { get; set; } = "";
    public string  PayRef        { get; set; } = "";
    public string? PayRefDate    { get; set; }
    public string  ChequeNo      { get; set; } = "";
    public string? ChequeDate    { get; set; }
    // Instructions
    public string  Carrier          { get; set; } = "";
    public int     CreditDays       { get; set; }
    public string? DeliveryDate     { get; set; }
    public string  DeliveryLocation { get; set; } = "";
    public string  BillingAddress   { get; set; } = "";
    public string  SpecialInstr     { get; set; } = "";
    public string  Despatch         { get; set; } = "";
    public string  Purpose          { get; set; } = "";
    public string  OtherLevies      { get; set; } = "";
    public string  PricingTerms     { get; set; } = "";
    public string  PackForwarding   { get; set; } = "";
    public string  Insurance        { get; set; } = "";
    public string  Freight          { get; set; } = "";
    // Cancel / Status
    public string  Reminder         { get; set; } = "";
    public string  Status           { get; set; } = "";
    public bool    Cancelled        { get; set; }
    public string? CancelDate       { get; set; }
    public string  CancelReason     { get; set; } = "";
    public string  Approved         { get; set; } = "";
    public string  ApprovedBy       { get; set; } = "";
    // Amendment (read-only)
    public decimal? AmdOrderNo  { get; set; }
    public string?  AmdDate     { get; set; }
    public decimal? AmdRefNo    { get; set; }
    public string?  AmdRefDate  { get; set; }
    // Approval / audit
    public string ApprovalStatus { get; set; } = "";
    public string PrintStatus    { get; set; } = "";
    public string FirstLevelApp  { get; set; } = "";
    public string Conflg         { get; set; } = "";
    public string CreatedBy      { get; set; } = "";
    public string CreatedDt      { get; set; } = "";
    public string UserId         { get; set; } = "";
    // Children
    public List<PoLineDto>              Lines    { get; set; } = [];
    public List<DeliveryScheduleLineDto> Delivery { get; set; } = [];
}
