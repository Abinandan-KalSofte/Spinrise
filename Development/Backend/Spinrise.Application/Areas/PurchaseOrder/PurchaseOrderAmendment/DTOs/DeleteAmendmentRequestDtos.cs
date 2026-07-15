using System.ComponentModel.DataAnnotations;

namespace Spinrise.Application.Areas.PurchaseOrder.PurchaseOrderAmendment.DTOs;

// Deletion payloads (FN §4 "Deletion" — ksp_PO_DeleteOrder / ksp_PO_DeleteLines).
// Both block if any receipt exists (server-side, IN_TRNTAIL count > 0) and reverse
// PO_PRL with the same floor guard + WARN clamp logging as the amend backflush.

// Whole-PO cascade delete — keyed on PO identity (FN §1 Modify/Delete cascade).
public record DeleteOrderRequestDto(
    [Required] decimal PoNo,
    [Required] string  PoDate,
    [Required][MaxLength(5)] string PoGroup
);

// Line-level delete — a list of line keys under one PO.
public record DeleteLinesRequestDto(
    [Required] decimal PoNo,
    [Required] string  PoDate,
    [Required][MaxLength(5)] string PoGroup,
    [Required][MinLength(1)] List<DeleteLineKeyDto> Lines
);

public record DeleteLineKeyDto(
    [Required] int    SNo,
    [Required] string ItemCode
);
