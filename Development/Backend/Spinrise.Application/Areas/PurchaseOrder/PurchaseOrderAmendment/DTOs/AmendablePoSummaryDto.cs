namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderAmendment.DTOs;

// ksp_PO_GetAmendablePOList row (FN §1 lookup predicate — AmdAfterGRN-branch is the
// SP's own internal logic, not a caller-supplied parameter).
public class AmendablePoSummaryDto
{
    public string  DivCode      { get; init; } = string.Empty;
    public decimal PoNo         { get; init; }
    public string  PoDate       { get; init; } = string.Empty;
    public string  PoGroup      { get; init; } = string.Empty;
    public string  Supplier     { get; init; } = string.Empty;
    public string  SupplierName { get; init; } = string.Empty;
    public decimal OrderValue   { get; init; }
    public int     TotalLines   { get; init; }
}
