namespace Spinrise.Domain.Areas.PurchaseOrder.PurchaseRequisition;

public class PurchaseRequisitionHeader
{
    public string DivCode   { get; init; } = string.Empty;
    public decimal PrNo     { get; init; }
    public DateOnly PrDate  { get; init; }
    public string DepCode   { get; init; } = string.Empty;
    public string? ReqName  { get; init; }
    public string? Section  { get; init; }
    public string? IType    { get; init; }
    public string? RefNo    { get; init; }
    public string? PoGrp    { get; init; }
    public string AppFlg    { get; init; } = "N";
    public string? CancelFlag { get; init; }
    public decimal AmendNo  { get; init; }
    public string UserId    { get; init; } = string.Empty;
    public string? CreatedBy { get; init; }
    public string? CreatedDt { get; init; }
}
