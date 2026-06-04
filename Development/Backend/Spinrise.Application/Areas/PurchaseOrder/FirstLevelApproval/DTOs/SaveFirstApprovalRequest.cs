using System.ComponentModel.DataAnnotations;

namespace Spinrise.Application.Areas.PurchaseOrder.FirstLevelApproval.DTOs;

public record SaveFirstApprovalRequest(
    [Required] decimal  PrNo,
    [Required] DateTime PrDate,
    [Required] DateTime AppDate,
    [Required] IReadOnlyList<SaveFirstApprovalLineRequest> Lines
);
