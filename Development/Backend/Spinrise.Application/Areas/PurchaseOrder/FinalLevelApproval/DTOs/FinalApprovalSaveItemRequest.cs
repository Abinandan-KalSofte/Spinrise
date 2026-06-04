using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace Spinrise.Application.Areas.PurchaseOrder.FinalLevelApproval.DTOs;

public class FinalApprovalSaveItemRequest
{
    [Required] public string  DivCode     { get; set; } = string.Empty;
    [Required] public decimal PrNo        { get; set; }
    [Required] public string  PrDate      { get; set; } = string.Empty;
    [Required] public decimal PrSno       { get; set; }
    [Range(0.001, double.MaxValue, ErrorMessage = "Qty Approved must be greater than zero.")]
    public decimal QtyApproved { get; set; }
    // AllowReadingFromString tolerates "2" (string) as well as 2 (number) from JSON
    [JsonNumberHandling(JsonNumberHandling.AllowReadingFromString)]
    public int Disposition { get; set; }
    [Required] public string  RowVersion  { get; set; } = string.Empty;
}
