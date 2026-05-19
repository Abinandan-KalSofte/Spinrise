using System.ComponentModel.DataAnnotations;

namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;

public class DeletePrRequest
{
    [Required]
    public decimal PrNo { get; init; }

    [Required]
    public DateOnly PrDate { get; init; }

    [Required]
    [RegularExpression("^(FULL|LINE)$", ErrorMessage = "DeleteMode must be FULL or LINE.")]
    public string DeleteMode { get; init; } = "FULL";

    public decimal? PrSno { get; init; }

    [MaxLength(100)]
    public string? DeleteReason { get; init; }
}
