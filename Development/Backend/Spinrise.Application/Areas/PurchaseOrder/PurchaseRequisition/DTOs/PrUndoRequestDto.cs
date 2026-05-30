using System.ComponentModel.DataAnnotations;

namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseRequisition.DTOs;

public record PrUndoRequestDto(
    [Required] decimal PrNo,
    [Required] string  PRDate,
    [Required] string  DepCode,
    [Required] string  RowVersion   // base64-encoded row_version from list endpoint
);
