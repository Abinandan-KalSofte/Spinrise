namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderAmendment.DTOs;

// Full PO loaded for amendment — ksp_PO_GetPOForAmend header (first result set),
// with Lines + Delivery attached in the repository from the 2nd/3rd result sets.
// Mirrors the amendable subset of PoEntry.PoHeaderDto so the same PO_ORDH columns
// are reused. Identity fields (DivCode/PoNo/PoDate/OrderType/Supplier) are locked
// in the UI (FN §1); Amd No/Date are read-only (FN §2 Amendment tab).
public class PoAmendmentHeaderDto
{
    // Identity (locked)
    public string   DivCode       { get; init; } = "";
    public decimal  PoNo          { get; init; }
    public string   PoDate        { get; init; } = "";
    public string   PoGroup       { get; init; } = "";   // POGRP
    public string   OrderType     { get; init; } = "";
    public string   OrderTypeDesc { get; init; } = "";
    public string   Supplier      { get; init; } = "";   // SLCODE
    public string   SupplierName  { get; init; } = "";
    public string   Gstin         { get; init; } = "";
    public string   GstState      { get; init; } = "";
    // Amendment (read-only)
    public decimal? AmdOrderNo    { get; init; }          // AMDORDNO
    public string?  AmdDate       { get; init; }          // AMDORDDT
    public decimal? RefOrderNo    { get; init; }          // REFORDNO
    public string?  RefOrderDate  { get; init; }          // REFORDDT
    // Order details (amendable)
    public string   Inspect       { get; init; } = "";
    public decimal  RoundOff      { get; init; }          // Roff
    public decimal  OrderValue    { get; init; }          // ORDVAL (header)
    public string   FormType      { get; init; } = "";
    public string   RefNo         { get; init; } = "";
    public string?  RefDate       { get; init; }
    public string   Currency      { get; init; } = "";
    public decimal  CurrRate      { get; init; }
    public string   Remarks       { get; init; } = "";
    // Tax / discount (header)
    public decimal  CgstPer       { get; init; }
    public decimal  SgstPer       { get; init; }
    public decimal  IgstPer       { get; init; }
    public decimal  TcsPer        { get; init; }
    public decimal  DiscPer       { get; init; }
    public decimal  PackPer       { get; init; }
    public decimal  InsurPer      { get; init; }
    public decimal  FreightPer    { get; init; }
    public decimal  FreightAmt    { get; init; }
    public decimal  PackingAmt    { get; init; }
    public decimal  InsuranceAmt  { get; init; }
    public decimal  AddTaxPer     { get; init; }
    public string   FileNo        { get; init; } = "";
    public decimal  FcaFob        { get; init; }          // FCACharg
    public string   FreightType   { get; init; } = "PAID"; // FRTFLG
    public string   DiscApp       { get; init; } = "BEFORE";
    public string   PackApp       { get; init; } = "BEFORE";
    public string   FreightPosition   { get; init; } = "BEFORE";
    public string   InsurancePosition { get; init; } = "BEFORE";
    // Payment
    public string   PayMode       { get; init; } = "DIRECT";
    public string   DirectInstr   { get; init; } = "";
    public string   BankCode      { get; init; } = "";
    public string   PaymentTerms  { get; init; } = "";
    public string   PaymentTermCode { get; init; } = "";  // paytermcode
    public decimal  AdvPer        { get; init; }
    public decimal  AdvAmt        { get; init; }
    public string   ModeOfPayment { get; init; } = "";    // advpaymenttype
    public string   PayRef        { get; init; } = "";    // CHQNO (DIRECT-mode display label)
    public string?  PayRefDate    { get; init; }          // CHQDT
    public string   ChequeNo      { get; init; } = "";
    public string?  ChequeDate    { get; init; }
    // Instructions
    public string   Carrier       { get; init; } = "";   // CARCODE
    public int      CreditDays    { get; init; }
    public string?  DueDate       { get; init; }
    public string   DeliveryLocation { get; init; } = ""; // DEL_INS1
    public string   BillingAddress   { get; init; } = ""; // Billadd
    public string   SpecialInstr  { get; init; } = "";   // SPL_INS
    public string   Despatch      { get; init; } = "";   // DEL_INS2
    public string   Purpose       { get; init; } = "";   // Note
    public string   OtherLevies   { get; init; } = "";   // Note2
    public string   PricingTerms  { get; init; } = "";   // PriceTerm
    public string   PackForwarding{ get; init; } = "";   // RemarksPF
    public string   Insurance     { get; init; } = "";   // RemarksIns (text remark, distinct from InsuranceAmt)
    public string   Freight       { get; init; } = "";   // RemarksFrt (text remark, distinct from FreightAmt)
    // Cancel / status (read-only context)
    public string   CancelFlag    { get; init; } = "";   // CANFLG
    public string?  CancelDate    { get; init; }
    public string   Reminder      { get; init; } = "";
    public string   Approved      { get; init; } = "";
    public string   ApprovedBy    { get; init; } = "";
    public string   Conflg        { get; init; } = "";
    // Audit
    public string   CreatedBy     { get; init; } = "";
    public string   CreatedDt     { get; init; } = "";
    // Children — attached by the repository from result sets 2 and 3
    public List<PoAmendmentLineDto>          Lines    { get; set; } = [];
    public List<PoAmendmentDeliverySlotDto>  Delivery { get; set; } = [];
}
