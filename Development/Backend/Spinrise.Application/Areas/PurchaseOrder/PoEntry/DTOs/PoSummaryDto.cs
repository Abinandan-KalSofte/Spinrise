namespace Spinrise.Application.Areas.PurchaseOrder.PoEntry.DTOs;

public class PoSummaryDto
{
    public string  DivCode        { get; init; } = string.Empty;
    public decimal PoNo           { get; init; }
    public string  PoDate         { get; init; } = string.Empty;
    public string  OrderType      { get; init; } = string.Empty;
    public string  Supplier       { get; init; } = string.Empty;
    public string  SupplierName   { get; init; } = string.Empty;
    public decimal OrderValue     { get; init; }
    public string  ApprovalStatus { get; init; } = string.Empty;
    public int     TotalLines     { get; init; }
}
