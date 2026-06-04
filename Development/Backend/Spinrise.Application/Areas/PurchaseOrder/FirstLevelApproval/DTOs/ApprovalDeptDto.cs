namespace Spinrise.Application.Areas.PurchaseOrder.FirstLevelApproval.DTOs;

public record ApprovalDeptDto(
    string DepCode,
    string DepName,
    int    PendingCount
);
