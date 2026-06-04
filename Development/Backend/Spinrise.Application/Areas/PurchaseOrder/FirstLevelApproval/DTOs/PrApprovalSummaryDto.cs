namespace Spinrise.Application.Areas.PurchaseOrder.FirstLevelApproval.DTOs;

public record PrApprovalSummaryDto(
    decimal  PrNo,
    DateTime PrDate,
    string   DepCode,
    string   DepName,
    string?  RefNo,
    string?  Section
);
