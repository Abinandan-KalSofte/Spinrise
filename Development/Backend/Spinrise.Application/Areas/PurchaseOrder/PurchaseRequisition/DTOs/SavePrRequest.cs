using System.ComponentModel.DataAnnotations;

namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;

public class SavePrRequest
{
    [Required]
    public DateOnly PrDate { get; init; }

    [Required]
    [MaxLength(3)]
    public string DepCode { get; init; } = string.Empty;

    [MaxLength(10)]
    public string? ReqName { get; init; }

    [MaxLength(20)]
    public string? Section { get; init; }

    [MaxLength(1)]
    public string? IType { get; init; }

    [MaxLength(20)]
    public string? RefNo { get; init; }

    [MaxLength(5)]
    public string? PoGrp { get; init; }

    // Modify mode only
    public decimal? ExistingPrNo   { get; init; }
    public DateOnly? ExistingPrDate { get; init; }

    [Required]
    [MinLength(1, ErrorMessage = "Purchase Requisition Requires at least one Item.")]
    public List<SavePrLineRequest> Lines { get; init; } = [];
}
