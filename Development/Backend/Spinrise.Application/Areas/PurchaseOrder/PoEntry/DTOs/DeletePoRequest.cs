using System.ComponentModel.DataAnnotations;

namespace Spinrise.Application.Areas.PurchaseOrder.PoEntry.DTOs;

public class DeletePoRequest
{
    [Required] public decimal  PoNo          { get; init; }
    [Required] public DateOnly PoDate        { get; init; }
    [Required] public string   DeleteMode    { get; init; } = "FULL";
    [Required] public string   DefaultReason { get; init; } = "";

    public List<PoLineDeleteReasonRequest> LineReasons { get; init; } = [];
}

public class PoLineDeleteReasonRequest
{
    public decimal PrSno        { get; init; }
    public string  DeleteReason { get; init; } = "";
}
