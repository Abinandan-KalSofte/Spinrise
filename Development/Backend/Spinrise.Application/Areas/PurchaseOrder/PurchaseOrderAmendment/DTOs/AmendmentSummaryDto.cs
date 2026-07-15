namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderAmendment.DTOs;

// Find-mode row — one saved amendment for the year (ksp_PO_GetAmendmentList,
// FN §1 Find). View-only list of PO No/Date, Amd No/Date, Supplier.
public class AmendmentSummaryDto
{
    public string  DivCode      { get; init; } = "";
    public decimal PoNo         { get; init; }
    public string  PoDate       { get; init; } = "";
    public string  PoGroup      { get; init; } = "";
    public decimal AmdNo        { get; init; }   // AMDORDNO
    public string  AmdDate      { get; init; } = "";
    public string  Supplier     { get; init; } = "";
    public string  SupplierName { get; init; } = "";
    public decimal OrderValue   { get; init; }
}
