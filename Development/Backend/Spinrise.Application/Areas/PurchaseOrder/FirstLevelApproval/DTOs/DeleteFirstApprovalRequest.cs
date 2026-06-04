using System.ComponentModel.DataAnnotations;

namespace Spinrise.Application.Areas.PurchaseOrder.FirstLevelApproval.DTOs;

public record DeleteFirstApprovalRequest(
    [Required] decimal  PrNo,
    [Required] DateTime PrDate
);
