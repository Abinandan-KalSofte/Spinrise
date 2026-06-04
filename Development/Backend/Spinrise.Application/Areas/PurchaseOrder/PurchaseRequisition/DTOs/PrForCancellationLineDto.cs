namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;

public record PrForCancellationLineDto(
    int     Sno,
    string  ItemCode,
    string  ItemName,
    string  UOM,
    decimal QtyRequired,
    decimal QtyApproved,
    decimal QtyOrdered,
    decimal QtyReceived,
    decimal CurrentStock,
    decimal Rate,
    decimal ApproxCost,
    string  ReqdDate,
    string  Machine,
    string  PlaceOfIssue,
    string  Remarks,
    bool    IsSample
);
