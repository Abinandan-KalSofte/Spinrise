namespace Spinrise.Application.Areas.PurchaseOrder.FinalLevelApproval.DTOs;

public record FinalApprovalSaveResponse(
    int    ApprovedCount,
    string Message
);
