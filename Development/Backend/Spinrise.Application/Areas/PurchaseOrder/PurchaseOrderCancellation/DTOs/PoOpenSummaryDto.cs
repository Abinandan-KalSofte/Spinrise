namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderCancellation.DTOs;

// One open PO eligible for cancellation — wire contract PoOpenSummary
// (poCancellationTypes.ts). Sourced from ksp_PO_GetOpenPOList (FN-PO-Cancellation
// v1.4 §5). Narrower than PoEntry's PoSummaryDto — no order value/approval status,
// the open-PO picker doesn't need them.
public record PoOpenSummaryDto(
    decimal PoNo,
    string  PoDate,
    string  SlCode,
    string  SupplierName,
    string  PoGrp
);
