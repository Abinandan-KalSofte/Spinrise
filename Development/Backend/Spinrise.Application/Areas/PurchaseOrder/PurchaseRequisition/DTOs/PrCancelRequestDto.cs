using System.ComponentModel.DataAnnotations;

namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;

public record PrCancelRequestDto(
    [Required] decimal PrNo,
    [Required] string  PRDate,
    [Required] string  DepCode,
    [Required][MaxLength(200)] string CancelReason
);
