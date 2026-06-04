using System.ComponentModel.DataAnnotations;

namespace Spinrise.Application.Areas.PurchaseOrder.FirstLevelApproval.DTOs;

public record SaveFirstApprovalLineRequest(
    [Required] decimal PrSno,
    [Required] string  ItemCode,
    [Required] string  DepCode,
    [Required] decimal QtyReqd,
    [Required] decimal FirstAppQty,
    [Required] decimal Rate,
    string? MacNo,
    string? SubCost,
    string? Uom
);
