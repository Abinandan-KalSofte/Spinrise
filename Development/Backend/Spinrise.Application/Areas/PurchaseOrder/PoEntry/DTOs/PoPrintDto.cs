namespace Spinrise.Application.Areas.PurchaseOrder.PoEntry.DTOs;

public record PoPrintDto(
    // Division letterhead
    byte[]?  DivLogo,
    string   DivName,
    string   DivPrintName,
    string   DivUnitName,
    string   DivAddress1,
    string   DivAddress2,
    string   DivAddress3,
    string   DivPinCode,
    string   DivPhone,
    string   DivEmail,
    string   DivGstin,
    string   DivPan,
    string   DivWeb,
    // PO header
    string   DivCode,
    decimal  PoNo,
    DateOnly PoDate,
    string   SlCode,
    string   SlName,
    string   SlAddress,
    string   SlGstin,
    string   SlPhone,
    string   SlEmail,
    string   OrderType,
    string   Carrier,
    string   Currency,
    decimal  CurrRate,
    int      CreditDays,
    string   PayMode,
    string   Remarks,
    // Tax header
    decimal  CgstPer,
    decimal  SgstPer,
    decimal  IgstPer,
    decimal  TcsPer,
    decimal  DiscPer,
    decimal  FreightAmt,
    decimal  RoundOff,
    decimal  OrderValue,
    // Approval
    string   FirstLevelApp,
    string   Conflg,
    string   CreatedBy,
    string   CreatedDt,
    // V2 print fields
    string   RefNo,
    string   RefDate,
    string   DeliveryDate,
    string   Purpose,
    string   PayTerms,
    decimal  InsAmt,
    decimal  PackAmt,
    string   DivStateCode,
    string   SlStateCode,
    // Lines
    IReadOnlyList<PoPrintLineDto> Lines,
    // Appended (defaulted) — populated by the KSP_PR_PO_GST path; legacy ksp_PO_GetPrint omits it
    decimal  OtherCharges = 0m,
    // Authorised-signatory signature image (PO_ParaPOApproval.SIGNATURE via FinalAppSign)
    byte[]?  AuthorisedSign = null
);

public record PoPrintLineDto(
    int     LineNo,
    string  ItemCode,
    string  ItemName,
    string  Uom,
    string  HsnCode,
    decimal PrNo,
    decimal PrSno,
    decimal Qty,
    decimal Rate,
    decimal Value,
    string  TaxCode,
    decimal TaxPer,
    decimal TaxAmt,
    decimal CgstPer,
    decimal CgstAmt,
    decimal SgstPer,
    decimal SgstAmt,
    decimal IgstPer,
    decimal IgstAmt,
    decimal TcsPer,
    decimal TcsAmt,
    decimal LineDis,
    decimal LineDisAmt
);

/// <summary>Flat Dapper row for ksp_PO_GetPrint result set 1.</summary>
public class PoPrintHeaderRow
{
    public byte[]?  DivLogo      { get; set; }
    public string   DivName      { get; set; } = "";
    public string   DivPrintName { get; set; } = "";
    public string   DivUnitName  { get; set; } = "";
    public string   DivAddress1  { get; set; } = "";
    public string   DivAddress2  { get; set; } = "";
    public string   DivAddress3  { get; set; } = "";
    public string   DivPinCode   { get; set; } = "";
    public string   DivPhone     { get; set; } = "";
    public string   DivEmail     { get; set; } = "";
    public string   DivGstin     { get; set; } = "";
    public string   DivPan       { get; set; } = "";
    public string   DivWeb       { get; set; } = "";
    public string   DivCode      { get; set; } = "";
    public decimal  PoNo         { get; set; }
    public DateOnly PoDate       { get; set; }
    public string   SlCode       { get; set; } = "";
    public string   SlName       { get; set; } = "";
    public string   SlAddress    { get; set; } = "";
    public string   SlGstin      { get; set; } = "";
    public string   SlPhone      { get; set; } = "";
    public string   SlEmail      { get; set; } = "";
    public string   OrderType    { get; set; } = "";
    public string   Carrier      { get; set; } = "";
    public string   Currency     { get; set; } = "";
    public decimal  CurrRate     { get; set; }
    public int      CreditDays   { get; set; }
    public string   PayMode      { get; set; } = "";
    public string   Remarks      { get; set; } = "";
    public decimal  CgstPer      { get; set; }
    public decimal  SgstPer      { get; set; }
    public decimal  IgstPer      { get; set; }
    public decimal  TcsPer       { get; set; }
    public decimal  DiscPer      { get; set; }
    public decimal  FreightAmt   { get; set; }
    public decimal  RoundOff     { get; set; }
    public decimal  OrderValue   { get; set; }
    public string   FirstLevelApp{ get; set; } = "";
    public string   Conflg       { get; set; } = "";
    public string   CreatedBy    { get; set; } = "";
    public string   CreatedDt    { get; set; } = "";
    public string   RefNo        { get; set; } = "";
    public string   RefDate      { get; set; } = "";
    public string   DeliveryDate { get; set; } = "";
    public string   Purpose      { get; set; } = "";
    public string   PayTerms     { get; set; } = "";
    public decimal  InsAmt       { get; set; }
    public decimal  PackAmt      { get; set; }
    public string   DivStateCode { get; set; } = "";
    public string   SlStateCode  { get; set; } = "";
}

/// <summary>Flat Dapper row for ksp_PO_GetPrint result set 2.</summary>
public class PoPrintLineRow
{
    public int     LineNo   { get; set; }
    public string  ItemCode { get; set; } = "";
    public string  ItemName { get; set; } = "";
    public string  Uom      { get; set; } = "";
    public string  HsnCode  { get; set; } = "";
    public decimal PrNo     { get; set; }
    public decimal PrSno    { get; set; }
    public decimal Qty      { get; set; }
    public decimal Rate     { get; set; }
    public decimal Value    { get; set; }
    public string  TaxCode  { get; set; } = "";
    public decimal TaxPer   { get; set; }
    public decimal TaxAmt   { get; set; }
    public decimal CgstPer  { get; set; }
    public decimal CgstAmt  { get; set; }
    public decimal SgstPer  { get; set; }
    public decimal SgstAmt  { get; set; }
    public decimal IgstPer  { get; set; }
    public decimal IgstAmt  { get; set; }
    public decimal TcsPer      { get; set; }
    public decimal TcsAmt      { get; set; }
    public decimal LineDis     { get; set; }
    public decimal LineDisAmt  { get; set; }
}
