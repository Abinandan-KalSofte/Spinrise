namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;

public record PrPrintDto(
    // Division letterhead
    byte[]?  DivLogo,
    string   DivName,
    string   DivPrintName,
    string   DivUnitName,
    string   DivAddress1,
    string   DivAddress2,
    string   DivAddress3,
    string   DivPinCode,
    string   DivState,
    string   DivPhone,
    string   DivEmail,
    // PR header
    string   DivCode,
    decimal  PrNo,
    DateOnly PrDate,
    string   DepCode,
    string   DepName,
    string   ReqName,
    string   ReqEmpName,
    string   Section,
    string   RefNo,
    string   PoGrp,
    string   IDesc,
    string   AppFlg,
    string   CreatedBy,
    string   CreatedDt,
    // Approval signature block
    string   FirstAppUser,
    string   SecondAppUser,
    string   ThirdAppUser,
    string   FinalAppUser,
    string   PresidentAppDate,
    // Lines
    IReadOnlyList<PrPrintLineDto> Lines
);

public record PrPrintLineDto(
    decimal   PrSno,
    string    ItemCode,
    string    ItemName,
    string    Uom,
    string    CatNo,
    string    DrawNo,
    string    MacNo,
    string    MacModel,
    string    MacMake,
    decimal   QtyInd,
    DateOnly? ReqdDate,
    decimal   Rate,
    decimal   LastPoRate,
    DateOnly? LastPoDate,
    decimal   CurrentStock,
    decimal   AppCost,
    string    Remarks
);

/// <summary>Flat Dapper row DTO — class (not record) so Dapper maps by property name.</summary>
public class PrPrintRowDto
{
    // Division letterhead
    public byte[]?   DivLogo      { get; set; }
    public string    DivName      { get; set; } = "";
    public string    DivPrintName { get; set; } = "";
    public string    DivUnitName  { get; set; } = "";
    public string    DivAddress1  { get; set; } = "";
    public string    DivAddress2  { get; set; } = "";
    public string    DivAddress3  { get; set; } = "";
    public string    DivPinCode   { get; set; } = "";
    public string    DivState     { get; set; } = "";
    public string    DivPhone     { get; set; } = "";
    public string    DivEmail     { get; set; } = "";
    // PR header
    public string    DivCode      { get; set; } = "";
    public decimal   PrNo         { get; set; }
    public DateOnly  PrDate       { get; set; }
    public string    DepCode      { get; set; } = "";
    public string    DepName      { get; set; } = "";
    public string    ReqName      { get; set; } = "";
    public string    ReqEmpName   { get; set; } = "";
    public string    Section      { get; set; } = "";
    public string    RefNo        { get; set; } = "";
    public string    PoGrp        { get; set; } = "";
    public string    IDesc        { get; set; } = "";
    public string    AppFlg       { get; set; } = "";
    public string    CreatedBy    { get; set; } = "";
    public string    CreatedDt    { get; set; } = "";
    // Line
    public decimal   PrSno        { get; set; }
    public string    ItemCode     { get; set; } = "";
    public string    ItemName     { get; set; } = "";
    public string    Uom          { get; set; } = "";
    public string    CatNo        { get; set; } = "";
    public string    DrawNo       { get; set; } = "";
    public string    MacNo        { get; set; } = "";
    public string    MacModel     { get; set; } = "";
    public string    MacMake      { get; set; } = "";
    public decimal   QtyInd       { get; set; }
    public DateOnly? ReqdDate     { get; set; }
    public decimal   Rate         { get; set; }
    public decimal   LastPoRate   { get; set; }
    public DateOnly? LastPoDate   { get; set; }
    public decimal   CurrentStock { get; set; }
    public decimal   AppCost      { get; set; }
    public string    Remarks      { get; set; } = "";
    // Approval
    public string    FirstApp          { get; set; } = "";
    public string    SecondApp         { get; set; } = "";
    public string    ThirdApp          { get; set; } = "";
    public string    DirectApp         { get; set; } = "";
    public string    FirstAppUser      { get; set; } = "";
    public string    SecondAppUser     { get; set; } = "";
    public string    ThirdAppUser      { get; set; } = "";
    public string    FinalAppUser      { get; set; } = "";
    public string    PresidentAppDate  { get; set; } = "";
}
