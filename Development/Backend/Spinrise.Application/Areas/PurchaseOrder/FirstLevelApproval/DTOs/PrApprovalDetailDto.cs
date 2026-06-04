namespace Spinrise.Application.Areas.PurchaseOrder.FirstLevelApproval.DTOs;

public record PrApprovalDetailDto(
    PrApprovalHeaderDto       Header,
    IReadOnlyList<PrApprovalLineDto> Lines
);
