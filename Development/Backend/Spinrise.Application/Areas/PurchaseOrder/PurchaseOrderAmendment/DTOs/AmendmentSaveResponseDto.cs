namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderAmendment.DTOs;

// Save result — the allocated Amendment No. + confirmation message (FN §4H:
// "Amendment Saved Successfully — Amendment No: n").
public record AmendmentSaveResponseDto(
    int    AmendNo,
    string Message
);
