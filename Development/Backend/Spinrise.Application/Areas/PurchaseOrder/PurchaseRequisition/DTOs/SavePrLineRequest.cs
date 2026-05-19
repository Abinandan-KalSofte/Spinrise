using System.ComponentModel.DataAnnotations;

namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;

public class SavePrLineRequest
{
    [Required]
    [MaxLength(10)]
    public string ItemCode { get; init; } = string.Empty;

    [MaxLength(5)]
    public string? MacNo { get; init; }

    [Range(0.001, double.MaxValue, ErrorMessage = "Quantity must be greater than zero.")]
    public decimal QtyInd { get; init; }

    public DateOnly? ReqdDate { get; init; }

    public decimal Rate { get; init; }

    public decimal LpoRate { get; init; }

    public DateOnly? LpoDate { get; init; }

    [MaxLength(40)]
    public string? LpoFrom { get; init; }

    [MaxLength(6)]
    public string RateSource { get; init; } = "LPO";

    [MaxLength(200)]
    public string? RateJustification { get; init; }

    public decimal CurStock { get; init; }

    public decimal? CcCode { get; init; }

    [MaxLength(1)]
    public string? CatCode { get; init; }

    [MaxLength(4)]
    public string? BgrpCode { get; init; }

    public decimal AppCost { get; init; }

    [MaxLength(100)]
    public string? Remarks { get; init; }

    [MaxLength(1)]
    public string Sample { get; init; } = "N";
}
