namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;

public record PrCancelledPrDto(
    decimal  PrNo,
    string   PRDate,
    string   DepCode,
    string   Department,
    string   RequestedBy,
    string   CancelledOn,
    string   PrevStatus,
    byte[]?  RowVersion,
    string?  CancelReason
);
