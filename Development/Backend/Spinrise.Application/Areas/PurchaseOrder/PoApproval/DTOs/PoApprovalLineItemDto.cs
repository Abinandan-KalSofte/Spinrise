namespace Spinrise.Application.Areas.PurchaseOrder.PoApproval.DTOs;

// PO_ORDL line detail row — present on First/Second Level responses only.
// Final Level is a grouped header-only view (BR-06) and never includes these.
public record PoApprovalLineItemDto(
    int     PordSno,
    string  ItemCode,
    string  ItemName,
    decimal Qty,
    string  Uom,
    decimal Rate,
    decimal Value,
    string  OnlineRemarks,
    string  FClosed);
