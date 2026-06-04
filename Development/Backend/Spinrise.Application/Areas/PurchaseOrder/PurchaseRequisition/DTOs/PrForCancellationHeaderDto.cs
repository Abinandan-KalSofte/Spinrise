namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;

public record PrForCancellationHeaderDto(
    decimal PrNo,
    string  PRDate,
    string  DepCode,
    string  Department,
    string  Section,
    string  RequestedBy,
    string  PRType,
    string  RefNo,
    string  CreatedBy,
    string  Status
);
