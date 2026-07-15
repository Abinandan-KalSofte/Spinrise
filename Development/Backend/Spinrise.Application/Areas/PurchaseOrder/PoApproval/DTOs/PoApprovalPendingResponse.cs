namespace Spinrise.Application.Areas.PurchaseOrder.PoApproval.DTOs;

public record PoApprovalPendingResponse(IReadOnlyList<PoApprovalLineDto> Items);
