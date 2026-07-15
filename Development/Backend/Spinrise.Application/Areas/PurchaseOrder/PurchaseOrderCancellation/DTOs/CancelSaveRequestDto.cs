using System.ComponentModel.DataAnnotations;

namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderCancellation.DTOs;

// Save payload — wire contract CancelSaveRequest { poNo, poDate, lines[] }
// (poCancellationTypes.ts / usePoCancellation.ts onOk).
public record CancelSaveRequestDto(
    [Required] decimal PoNo,
    [Required] string  PoDate,
    [Required][MinLength(1)] List<CancelLineRequestDto> Lines
);

public record CancelLineRequestDto(
    [Required] int     SNo,
    [Required] string  ItemCode,
    [Required] string  ReasonCode,
    [Required] decimal CancelQty
);
