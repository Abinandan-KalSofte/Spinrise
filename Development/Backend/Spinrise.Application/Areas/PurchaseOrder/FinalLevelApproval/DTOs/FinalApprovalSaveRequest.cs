using System.ComponentModel.DataAnnotations;

namespace Spinrise.Application.Areas.PurchaseOrder.FinalLevelApproval.DTOs;

public class FinalApprovalSaveRequest
{
    [Required] public string                             DbName    { get; set; } = string.Empty;
    public bool                                          BypassAll { get; set; }
    [Required, MinLength(1)] public List<FinalApprovalSaveItemRequest> Items { get; set; } = [];
}
