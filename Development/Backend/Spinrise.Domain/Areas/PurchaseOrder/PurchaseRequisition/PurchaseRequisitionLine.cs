namespace Spinrise.Domain.Areas.PurchaseOrder.PurchaseRequisition;

public class PurchaseRequisitionLine
{
    public string DivCode     { get; init; } = string.Empty;
    public decimal PrNo       { get; init; }
    public DateOnly PrDate    { get; init; }
    public decimal PrSno      { get; init; }
    public string ItemCode    { get; init; } = string.Empty;
    public string? MacNo      { get; init; }
    public decimal QtyInd     { get; init; }
    public DateOnly? ReqdDate { get; init; }
    public decimal Rate       { get; init; }
    public decimal LpoRate    { get; init; }
    public DateOnly? LpoDate  { get; init; }
    public string? LpoFrom    { get; init; }
    public string RateSource  { get; init; } = "LPO";
    public string? RateJustification { get; init; }
    public decimal CurStock   { get; init; }
    public decimal? CcCode    { get; init; }
    public string? CatCode    { get; init; }
    public string? BgrpCode   { get; init; }
    public decimal AppCost    { get; init; }
    public string? Remarks    { get; init; }
    public string Sample      { get; init; } = "N";
}
