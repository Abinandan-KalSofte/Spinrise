namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderCancellation.DTOs;

// Reason dropdown row — wire contract CancellationReason { code, name }
// (poCancellationTypes.ts). Sourced from ksp_PO_GetCancelReasons.
public record CancellationReasonDto(
    string Code,
    string Name
);
