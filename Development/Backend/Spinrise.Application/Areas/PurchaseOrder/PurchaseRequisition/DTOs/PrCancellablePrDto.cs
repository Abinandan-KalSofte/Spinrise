namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;

public record PrCancellablePrDto(
    decimal PrNo,
    string  PRDate,
    string  DepCode,
    string  Department,
    string  Requester,
    int     ItemCount,
    string  RefNo,
    string  PRType,
    string  Section,
    string  CreatedBy,
    string  Status
);
