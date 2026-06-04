using System.ComponentModel.DataAnnotations;

namespace Spinrise.Application.Areas.PurchaseOrder.FinalLevelApproval.DTOs;

public class FinalApprovalGetQuery
{
    [Required] public string DbName  { get; set; } = string.Empty;
    [Required] public string DivCode { get; set; } = string.Empty;   // '0' = all divisions
    [Range(0, 1)] public int Bypass  { get; set; } = 1;
}
