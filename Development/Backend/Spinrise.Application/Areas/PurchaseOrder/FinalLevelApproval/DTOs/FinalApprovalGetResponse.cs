namespace Spinrise.Application.Areas.PurchaseOrder.FinalLevelApproval.DTOs;

public record FinalApprovalGetResponse(
    IReadOnlyList<FinalApprovalLineDto> Items,
    int     TotalLines,
    decimal TotalCost    // 2dp — sum of (qtyRequired × lpoRate)
);
