namespace Spinrise.Application.Areas.PurchaseOrder.PoApproval.DTOs;

// DivCode moved to per-item (10-Jul-2026 bug fix) — see PoApprovalSaveItemRequest.
public record PoApprovalSaveRequest(IReadOnlyList<PoApprovalSaveItemRequest> Items);
